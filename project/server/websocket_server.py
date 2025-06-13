import asyncio
import websockets
import numpy as np
import sounddevice as sd
from collections import deque
import time
import tempfile
import os
from gtts import gTTS
from utils.yamnet_local import classify_audio
from utils.whisper import transcribe_audio
from utils.gemini import add_message, build_conversation_context, call_gemini_api
from utils.warning import send_bark_notification
from utils.markdown import get_urgency_level,parse_markdown_json

# 参数
SAMPLE_RATE = 16000
FRAME_DURATION = 0.5  # 每帧持续时间（秒）
FRAME_SIZE = int(SAMPLE_RATE * FRAME_DURATION)  # 每帧采样点数
SILENCE_TIMEOUT = 2.0  # 静音判定时间（秒）
VOLUME_GAIN = 2.0

# 前缓存参数（回补）
PRE_SPEECH_DURATION = 1.0  # 前置缓存 1 秒
PRE_SPEECH_FRAMES = int(PRE_SPEECH_DURATION / FRAME_DURATION)

# 状态
frame_buffer = bytearray()
speech_buffer = deque()
pre_speech_buffer = deque(maxlen=PRE_SPEECH_FRAMES)
last_speech_time = None
collecting = False

active_connections = set()

def apply_gain(audio: np.ndarray, gain: float = 2.0) -> np.ndarray:
    return np.clip(audio * gain, -1.0, 1.0)

def is_human_speech(label: str) -> bool:
    return label.lower() in ["speech", "conversation", "narration", "speech synthesizer"]

async def speak(text: str):
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as tmp:
            gTTS(text=text, lang='zh').save(tmp.name)
        proc = await asyncio.create_subprocess_exec('afplay', tmp.name)
        await proc.wait()
        os.unlink(tmp.name)
    except Exception as e:
        print("❌ TTS 播放失败：", e)

async def broadcast_alert(message: str, org: str):
    """Send alert to all connected clients"""
    if active_connections:
        print(f"🚨 Broadcasting alert: {message}")
        await asyncio.wait([ws.send(f"{message}") for ws in active_connections])
        send_bark_notification(org)  # 发送 Bark 通知
        

async def process_frame(frame: np.ndarray):
    global last_speech_time, collecting, speech_buffer, pre_speech_buffer

    # 🔁 始终保存最近帧
    pre_speech_buffer.append(frame)

    label, confidence = classify_audio(frame)
    print(f"🔎 当前帧分类：{label}（置信度 {confidence:.2f}）")

    if is_human_speech(label):
        if not collecting:
            print("🎙️ 检测到人声，回补前3秒音频")
            # 复制 pre_speech_buffer（不含当前帧）
            speech_buffer.extend(list(pre_speech_buffer)[:-1])
        speech_buffer.append(frame)
        last_speech_time = time.time()
        collecting = True

    else:
        if collecting and last_speech_time and (time.time() - last_speech_time >= SILENCE_TIMEOUT):
            chunk = np.concatenate(speech_buffer).astype(np.float32)
            chunk = apply_gain(chunk, VOLUME_GAIN)

            label_full, conf_full = classify_audio(chunk)
            print(f"🎧 整段音频分类：{label_full}（{conf_full:.2f}）")

            text = transcribe_audio(chunk)
            print(f"📝 Whisper识别结果：{text}")

            add_message(text, is_user=True)
            prompt = build_conversation_context()

            response = await call_gemini_api(prompt)
            if response:
                print("🤖 Gemini分析结果：", response)
                # 发送信息给客户端
                add_message(response, is_user=False)
                if get_urgency_level(parse_markdown_json(response)) == "high":
                    await broadcast_alert("Send warning", response)
            else:
                print("❌ Gemini API 调用失败")

            speech_buffer.clear()
            collecting = False
            last_speech_time = None    

async def echo(websocket):
    global frame_buffer
    print("🔗 客户端已连接")
    active_connections.add(websocket)
    try:
        async for message in websocket:
            frame_buffer.extend(message)

            while len(frame_buffer) >= FRAME_SIZE * 2:
                raw = frame_buffer[:FRAME_SIZE * 2]
                frame_buffer = frame_buffer[FRAME_SIZE * 2:]

                frame_np = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
                await process_frame(frame_np)

    except websockets.exceptions.ConnectionClosed:
        print("🔌 客户端断开连接")
    except Exception as e:
        print(f"❌ 接收处理错误: {e}")

async def main():
    async with websockets.serve(echo, "0.0.0.0", 8765):
        print("🚀 WebSocket 实时助听服务启动")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())