# recognizer/yamnet.py

import tensorflow as tf
import tensorflow_hub as hub
import numpy as np
import urllib.request

# 加载标签
def load_labels():
    url = 'https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv'
    labels = [line.decode('utf-8').strip().split(',')[2] for line in urllib.request.urlopen(url).readlines()[1:]]
    return labels

# 加载模型
model = hub.load('https://tfhub.dev/google/yamnet/1')
labels = load_labels()

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