# utils/whisper_asr.py

import whisper
import numpy as np

# 加载模型
print("🤖 加载 Whisper 模型...")
model = whisper.load_model("base", device="cpu")  # 或 "cuda" 如果有 GPU
print("✅ Whisper 模型加载完成")

def transcribe_audio(audio: np.ndarray, sample_rate=16000) -> str:
    """
    用 openai/whisper 模型识别 float32 的 waveform 音频数据
    要求: 1D float32 array, 采样率为 16000
    返回: 识别出的文本
    """
    if sample_rate != 16000:
        raise ValueError("Whisper 只支持 16000Hz 采样率")

    # pad/trim 到 30s（whisper 要求）
    audio = whisper.pad_or_trim(audio)

    # 生成梅尔频谱图
    mel = whisper.log_mel_spectrogram(audio).to(model.device)

    # 推理
    options = whisper.DecodingOptions(language='zh', fp16=False)
    result = model.decode(mel, options)

    return result.text.strip()