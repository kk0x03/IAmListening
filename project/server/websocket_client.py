import asyncio
import sounddevice as sd
import numpy as np
import websockets

SAMPLE_RATE = 16000
DURATION = 0.1
CHUNK_SIZE = int(SAMPLE_RATE * DURATION)
WEBSOCKET_URI = "ws://127.0.0.1:8765"
async def send_audio():
    loop = asyncio.get_running_loop()  # 获取当前主线程事件循环
    async with websockets.connect(WEBSOCKET_URI) as websocket:
        print("🎙️ 连接成功，开始采集音频...")

        def callback(indata, frames, time, status):
            if status:
                print("⚠️", status)
            audio_bytes = (indata[:, 0] * 32767).astype(np.int16).tobytes()
            # 提交到主线程的事件循环执行 WebSocket 发送
            asyncio.run_coroutine_threadsafe(websocket.send(audio_bytes), loop)

        # 注意：采集音频在后台线程中进行
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, callback=callback, blocksize=CHUNK_SIZE):
            await asyncio.Future()  # 保持运行

if __name__ == "__main__":
    try:
        asyncio.run(send_audio())
    except KeyboardInterrupt:
        print("\n⛔ 已中断")