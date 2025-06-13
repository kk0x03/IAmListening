# utils/whisper_asr.py

from whispercpp import Whisper
import numpy as np

# 加载 ggml 模型（推荐 base.en 或 zh 模型）
print("🤖 加载 whisper.cpp 模型...")
model = Whisper.from_file("path/models/ggml-base.en.bin")
print("✅ whisper.cpp 模型加载完成")

def transcribe_audio(audio: np.ndarray, sample_rate=16000) -> str:
    """
    用 whisper.cpp 模型识别 float32 的 waveform 音频数据
    要求: 1D float32 array, 采样率为 16000
    返回: 识别出的文本
    """
    if sample_rate != 16000:
        raise ValueError("whisper.cpp 只支持 16000Hz 采样率")

    try:
        model.audio_from_ndarray(audio, sample_rate=sample_rate)
        return model.transcribe().strip()
    except Exception as e:
        return f"[识别失败] {e}"