import tensorflow as tf
import tensorflow_hub as hub
import numpy as np
import csv
import os

# 本地路径
YAMNET_MODEL_PATH = "path/models/"
YAMNET_LABELS_PATH = "path/models/yamnet_class_map.csv"

# 加载标签
def load_labels():
    if not os.path.exists(YAMNET_LABELS_PATH):
        raise FileNotFoundError(f"标签文件未找到: {YAMNET_LABELS_PATH}")
    with open(YAMNET_LABELS_PATH, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # 跳过表头
        return [row[2] for row in reader]

# 加载模型
print("🤖 加载本地 YAMNet 模型...")
model = hub.load(YAMNET_MODEL_PATH)
labels = load_labels()
print("✅ YAMNet 模型加载完成")

# 识别函数
def classify_audio(audio: np.ndarray) -> tuple[str, float]:
    """
    输入 audio: 1D float32 PCM waveform (16kHz)
    返回: (标签名, 置信度)
    """
    scores, embeddings, spectrogram = model(audio)
    mean_scores = tf.reduce_mean(scores, axis=0)
    top_class = tf.argmax(mean_scores).numpy()
    confidence = mean_scores[top_class].numpy()
    label = labels[top_class]
    return label, confidence