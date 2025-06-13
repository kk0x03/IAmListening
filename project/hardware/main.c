#include <WiFi.h>
#include <WebSocketsClient.h>
#include <driver/i2s.h>
#include <U8g2lib.h>
#include <Wire.h>
#include <math.h>

// OLED 屏幕初始化（使用硬件 I2C）默认使用 GPIO 21 (SDA), 22 (SCL)
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(
    U8G2_R0, /* reset=*/ U8X8_PIN_NONE
);

String msg = "";

// WiFi 配置
#define WIFI_SSID     "xxxx"
#define WIFI_PASS     "xxxx"
#define SERVER_HOST   "xxxxxxxxx"
#define SERVER_PORT   8765
#define SERVER_PATH   "/"

// 麦克风 I2S 配置
#define SAMPLE_RATE    16000
#define SAMPLE_BITS    I2S_BITS_PER_SAMPLE_16BIT
#define CHANNEL_FORMAT I2S_CHANNEL_FMT_ONLY_LEFT
#define BUFFER_LEN     512
#define I2S_PORT       I2S_NUM_0
#define I2S_SCK        26
#define I2S_WS         25
#define I2S_DATA       34

WebSocketsClient webSocket;

void connectWiFi() {
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
    }
}

void setupI2S() {
    const i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = SAMPLE_RATE,
        .bits_per_sample = SAMPLE_BITS,
        .channel_format = CHANNEL_FORMAT,
        .communication_format = I2S_COMM_FORMAT_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 4,
        .dma_buf_len = 256,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
};

    const i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_SCK,
        .ws_io_num = I2S_WS,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_DATA
    };

    i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_PORT, &pin_config);
    i2s_zero_dma_buffer(I2S_PORT);
}

void setupWebSocket() {
    webSocket.begin(SERVER_HOST, SERVER_PORT, SERVER_PATH);
    webSocket.setReconnectInterval(5000);

    webSocket.onEvent([](WStype_t type, uint8_t* payload, size_t length) {
        if (type == WStype_TEXT) {
            msg = String((char*)payload);  // 接收文本
        }
    });
}

float calculateRMS(int16_t* samples, size_t count) {
    uint64_t sumSquares = 0;
    for (size_t i = 0; i < count; ++i) {
        int32_t s = samples[i];
        sumSquares += s * s;
    }
    return sqrtf((float)sumSquares / count);
}

void updateOLED(float rms) {
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_unifont_t_chinese2); // 支持中文的字体

    u8g2.setCursor(0, 16);
    u8g2.print("音量强度: ");  // 显示中文
    u8g2.print((int)rms);

    // 音量条
    int barLength = map((int)rms, 0, 1000, 0, 128);
    barLength = constrain(barLength, 0, 128);
    u8g2.drawBox(0, 30, barLength, 10);

    u8g2.sendBuffer();
}

void writeOLED(String msg) {
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_unifont_t_chinese2); // 支持中文的字体

    u8g2.setCursor(0, 16);
    u8g2.print(msg); // 显示中文
    // u8g2.setCursor(0, 30);
    // u8g2.print(msg);

    // 音量条
    // int barLength = map((int)rms, 0, 1000, 0, 128);
    // barLength = constrain(barLength, 0, 128);
    // u8g2.drawBox(0, 30, barLength, 10);

    u8g2.sendBuffer();
}

void setup() {
    Serial.begin(115200);
    connectWiFi();

    u8g2.begin();
    u8g2.enableUTF8Print();  // 允许 UTF-8 打印
    u8g2.setFont(u8g2_font_unifont_t_chinese2);
    u8g2.clearBuffer();
    u8g2.drawStr(0, 20, "🎧 初始化中...");
    u8g2.sendBuffer();

    setupI2S();
    setupWebSocket();

    xTaskCreatePinnedToCore(
        task1,
        "Task1",
        10000,
        NULL,
        1,
        NULL,
        0
    );
    xTaskCreatePinnedToCore(
        task2,
        "Task2",
        10000,
        &msg,
        1,
        NULL,
        0
    );

}

void task1(void *pvParameters) {
    while(1) {
        static uint8_t buffer[BUFFER_LEN];
        size_t bytesRead;

        i2s_read(I2S_PORT, buffer, sizeof(buffer), &bytesRead, portMAX_DELAY);

        if (bytesRead > 0) {
            int16_t* samples = (int16_t*)buffer;
            size_t sampleCount = bytesRead / sizeof(int16_t);

            float rms = calculateRMS(samples, sampleCount);
            Serial.printf("🎚️ 当前音量 (RMS): %.2f\n", rms);
            webSocket.sendBIN(buffer, bytesRead);
        }

        webSocket.loop();
        // vTaskDelay
    }
}

void task2(void *pvParameters) {
    String* msg = (String*)pvParameters;
    while(1) {
        writeOLED(*msg);
        vTaskDelay(100);
    }
}

void loop() {}