FROM python:3.11-slim

# 设置默认源（重新创建 source.list）
# RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian bookworm main contrib non-free non-free-firmware\n\
# deb https://mirrors.tuna.tsinghua.edu.cn/debian bookworm-updates main contrib non-free non-free-firmware\n\
# deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" \
# > /etc/apt/sources.list

# 安装系统依赖
RUN apt-get clean && apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        ffmpeg \
        libasound2-dev \
        libportaudio2 \
        libportaudiocpp0 \
        git \
        libglib2.0-0 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 拷贝代码
COPY . .

# 安装依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        websockets \
        numpy \
        sounddevice \
        gTTS \
        playsound \
        tensorflow \
        tensorflow-hub \
        git+https://github.com/openai/whisper.git

CMD ["python", "websockets_server.py"]