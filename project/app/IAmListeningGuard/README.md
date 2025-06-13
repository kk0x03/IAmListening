
# IAmListeningGuard 智能音频助手（守护）

## 🧠 项目简介

本项目是一个智能监护系统，旨在为监护人提供对被监护人日常交流的关键信息监控。系统支持**三种 AI 推理模式**：本地 Gemma3-1B-IT 模型、Google Gemini 2.0 Flash API 和 FastGPT 云服务。

**核心功能：**

- 🎙️ 实时语音识别与分析
- 🤖 **三模式 AI 推理**：本地模型（调试用）+ Gemini 2.0 Flash（调试用）+ FastGPT（主要功能）
- 🔄 **动态模式切换**：根据需求灵活切换推理模式
- 👨‍⚕️ **关键信息提取**：医生交流、教师沟通、校园霸凌检测
- 🛡️ **隐私保护**：智能过滤，仅保存关键信息到知识库
- 📊 **监护报告**：为家长提供被监护人的重要信息摘要
- 🔊 **文字转语音**：AI 回复语音播报功能

**应用场景：**
- 监控被监护人与医生的交流内容
- 了解老师与孩子的沟通情况
- 及时发现校园霸凌等安全问题
- 保护儿童隐私的同时确保安全监护

## 🧰 环境依赖

- Xcode ≥ 15.0
- iOS 17+
- CocoaPods ≥ 1.16.2
- **API 密钥**：Google Gemini 2.0 Flash API Key + FastGPT API Key
- **本地模型**（调试用）：Gemma3-1B-IT-INT4 量化模型

## 🔧 配置与部署

### 1. API 密钥配置

本项目使用环境变量来管理API密钥，确保敏感信息不会被提交到版本控制系统中。

#### 1.1 复制环境变量模板

```bash
cp .env.example .env
```

#### 1.2 编辑 .env 文件

在 `.env` 文件中填入你的实际API密钥：

```bash
# Gemini API Key
GEMINI_API_KEY=你的_gemini_api_密钥

# FastGPT API Key
FASTGPT_API_KEY=你的_fastgpt_api_密钥
```

#### 1.3 在 Xcode 中配置环境变量

**方法一：通过 Scheme 配置（推荐）**

1. 在 Xcode 中打开项目
2. 选择 `Product` -> `Scheme` -> `Edit Scheme...`
3. 在左侧选择 `Run`
4. 切换到 `Arguments` 标签页
5. 在 `Environment Variables` 部分添加以下变量：
   - `GEMINI_API_KEY`: 你的 Gemini API 密钥
   - `FASTGPT_API_KEY`: 你的 FastGPT API 密钥

**方法二：通过系统环境变量**

在终端中设置环境变量，然后从终端启动 Xcode：

```bash
export GEMINI_API_KEY="你的_gemini_api_密钥"
export FASTGPT_API_KEY="你的_fastgpt_api_密钥"
open IAmListening.xcworkspace
```

#### 1.4 API 密钥获取

**Gemini API Key**
1. 访问 [Google AI Studio](https://makersuite.google.com/app/apikey)
2. 登录你的 Google 账户
3. 创建新的 API 密钥
4. 复制密钥到环境变量中

**FastGPT API Key**
1. 登录你的 FastGPT 控制台
2. 在 API 设置中生成新的密钥
3. 复制密钥到环境变量中

#### 1.5 安全注意事项

- ⚠️ **永远不要**将 `.env` 文件提交到版本控制系统
- ⚠️ **永远不要**在代码中硬编码 API 密钥
- ✅ 使用 `.env.example` 文件作为模板，但不包含实际密钥
- ✅ 确保 `.env` 文件已添加到 `.gitignore` 中

### 2. 本地模型部署（调试用）

**模型信息：**
- 模型名称：`gemma3-1b-it-int4.task`
- 模型类型：Gemma3-1B-IT INT4 量化版本
- 用途：本地调试和离线测试

**部署步骤：**
1. 获取 MediaPipe 格式的 Gemma3-1B-IT-INT4 模型文件
2. 将 `.task` 文件添加到 Xcode 项目
3. 确保文件名为：`gemma3-1b-it-int4.task`
4. 在 "Add to target" 中勾选 "IAmListening"

**注意：** 本地模型主要用于调试目的，生产环境建议使用 FastGPT 服务

### 3. 模式切换验证

应用支持三种模式动态切换：
- **本地模式**：离线推理，调试用途
- **Gemini 2.0 Flash API**：Google 官方 API，调试用途
- **FastGPT**：主要功能模式，监护信息处理与知识库管理

**FastGPT 核心功能：**
- 智能识别医生、老师与被监护人的关键对话
- 校园霸凌等安全事件的实时检测
- 隐私保护算法，过滤敏感个人信息
- 为监护人生成关键信息摘要报告

### 4. CocoaPods 依赖安装

```bash
pod init

# 编辑 Podfile，添加以下内容
pod 'MediaPipeTasksGenAI'  # MediaPipe LLM 推理
pod 'GoogleMLKit-SpeechRecognition'  # 语音识别

pod install
```

## 📁 项目结构

```plaintext
IAmListeningGuard/
├── .env.example                    # 环境变量配置模板
├── .gitignore                      # Git 忽略文件配置
├── IAmListening.xcodeproj/         # Xcode 项目文件
│   ├── project.pbxproj             # 项目配置文件
│   ├── project.xcworkspace/        # 项目工作空间
│   └── xcshareddata/               # 共享数据和方案
├── IAmListening.xcworkspace/       # CocoaPods 工作空间
│   ├── contents.xcworkspacedata    # 工作空间配置
│   └── xcshareddata/               # Swift Package Manager 配置
├── IAmListening/                   # 🔥 主要源代码目录
│   ├── IAmListeningApp.swift       # 📱 应用入口点和生命周期管理
│   ├── ContentView.swift           # 🎨 主界面视图（含模式切换 UI）
│   ├── LLMInferenceService.swift   # 🤖 多模式 AI 推理引擎核心
│   └── models/                     # 📦 AI 模型文件目录（需手动添加）
│       └── gemma3-1b-it-int4.task  # 本地 Gemma-3 模型文件
├── Podfile                         # 📋 CocoaPods 依赖配置
├── Podfile.lock                    # 🔒 依赖版本锁定文件
└── README.md                       # 📖 项目说明文档
```

### 📂 目录说明

- **IAmListening/**: 核心 Swift 源代码目录
  - `IAmListeningApp.swift`: SwiftUI 应用程序入口，负责应用生命周期管理
  - `ContentView.swift`: 主用户界面，包含模式切换和实时监听状态显示
  - `LLMInferenceService.swift`: AI 推理服务核心，支持本地和云端多模式推理
  - `models/`: AI 模型文件存放目录（需要手动创建并添加模型文件）

- **配置文件**:
  - `.env.example`: 环境变量配置模板，包含 API 密钥等敏感信息配置示例
  - `Podfile`: CocoaPods 依赖管理配置，定义第三方库依赖
  - `Podfile.lock`: 锁定具体的依赖版本，确保团队开发环境一致性

- **Xcode 项目文件**:
  - `IAmListening.xcodeproj/`: 原始 Xcode 项目配置
  - `IAmListening.xcworkspace/`: CocoaPods 生成的工作空间，**开发时请使用此文件打开项目**

## 🚀 核心能力模块

### 🤖 LLMInferenceService.swift - **多模式 AI 推理引擎**

**三种推理模式：**
- **本地模式**：使用 MediaPipe 加载 Gemma3-1B-IT INT4 模型，调试用途
- **Gemini 2.0 Flash API 模式**：调用 Google Gemini 2.0 Flash API，调试用途
- **FastGPT 模式**：主要功能模式，监护信息智能处理

**FastGPT 监护功能：**
- 医生交流内容的关键信息提取
- 教师沟通记录的智能分析
- 校园霸凌事件的实时识别
- 隐私保护机制，智能过滤敏感信息
- 监护报告生成与知识库管理

**语音合成功能：**
- 基于 AVSpeechSynthesizer 的中文 TTS
- 支持语速、音调、音量调节
- 实时朗读控制（播放/暂停/停止）

## 🎯 FastGPT 监护系统核心

### FastGPT 监护平台优势

- **监护知识库**：专门构建的儿童安全、医疗、教育相关知识库
- **隐私保护工作流**：智能识别并过滤个人隐私信息
- **关键信息提取**：精准识别医生建议、教师反馈、安全威胁
- **监护报告生成**：为家长提供结构化的关键信息摘要
- **成本控制**：相比 OpenAI 官方 API 更具性价比

### 未来隐私保护规划

- **智能过滤算法**：只保存与监护相关的关键信息
- **隐私计算技术**：敏感内容本地处理，不上传云端
- **分级权限管理**：不同类型信息设置不同的访问权限
- **数据最小化原则**：仅收集和存储必要的监护信息

## 🔐 权限说明

### Info.plist 添加：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风进行语音检测</string>
```

### 通知权限

在 `AppDelegate` 或首屏启动时调用：

```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
    print("通知授权结果: \(granted)")
}
```

## 🔧 故障排除

### 环境变量相关问题

如果遇到 "API key not found in environment variables" 错误：

1. **检查环境变量名称**：确保变量名称正确（区分大小写）
   - `GEMINI_API_KEY`
   - `FASTGPT_API_KEY`

2. **验证 Xcode Scheme 配置**：
   - 打开 `Product` -> `Scheme` -> `Edit Scheme...`
   - 确认在 `Arguments` -> `Environment Variables` 中正确添加了变量

3. **重启开发环境**：
   - 重启 Xcode
   - 重启模拟器
   - 清理项目缓存（`Product` -> `Clean Build Folder`）

4. **验证 API 密钥有效性**：
   - 确认 Gemini API 密钥在 Google AI Studio 中有效
   - 确认 FastGPT API 密钥在控制台中有效

### 模型加载问题

如果本地模型加载失败：

1. 确认模型文件名为 `gemma3-1b-it-int4.task`
2. 检查模型文件是否正确添加到 Xcode 项目
3. 验证模型文件是否包含在 app bundle 中

## 🧪 测试建议

### 功能测试
- ✅ **模式切换**：本地 ↔ Gemini API ↔ FastGPT 无缝切换
- ✅ **语音识别**：中英文混合识别准确性
- ✅ **AI 推理**：三种模式的响应质量对比
- ✅ **语音合成**：TTS 播报效果与控制功能
- ✅ **预警系统**：暴力关键词检测与通知推送

### 测试用例
```
暴力关键词测试集：
- "有人在欺负我"
- "他们要打我"
- "学校里有人威胁我"
- "被同学孤立了"
- "老师，救救我"
```

## 📈 性能优化建议

### 本地模式优化
- 使用 **INT4** 量化模型，减少内存占用
- 启用 Metal Performance Shaders (MPS) GPU 加速
- 对话历史本地缓存，避免重复推理

### API 模式优化
- **智能降级**：API 失败时自动切换到本地模式
- **请求缓存**：相似问题复用历史响应
- **并发控制**：限制同时请求数量，避免 API 限流

### FastGPT 专项优化
- **知识库预热**：预加载校园安全相关知识
- **Prompt 工程**：针对校园场景优化提示词
- **响应流式处理**：支持 Server-Sent Events 流式响应

## 🔄 可扩展方向

### 短期规划
- 🌐 **多语言支持**：英语、日语等多语言语音识别
- 📱 **Apple Watch 集成**：紧急求助一键触发
- 🔔 **家长通知**：预警信息同步推送给家长

### 中期规划
- 🧠 **上下文增强**：支持更长对话历史（Token > 4096）
- 🔊 **实时语音流**：WebRTC 实时语音传输
- 📊 **数据分析**：校园安全事件统计与趋势分析

### 长期愿景
- ☁️ **云端协同**：多设备数据同步与备份
- 🤖 **AI 助手进化**：从被动检测到主动关怀
- 🏫 **校园生态**：与学校管理系统深度集成

## 📚 参考资料

### AI 模型与框架
- [Gemma 模型文档](https://huggingface.co/google/gemma-2-2b-it)
- [MediaPipe LLM 推理](https://github.com/google-ai-edge/mediapipe-samples/tree/main/examples/llm_inference/ios)
- [Google Gemini API](https://ai.google.dev/docs)
- [FastGPT 官方文档](https://doc.fastgpt.in/)

### iOS 开发
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [AVSpeechSynthesizer 文档](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- [SwiftUI 官方指南](https://developer.apple.com/xcode/swiftui/)

### 校园安全
- [教育部校园安全指导意见](https://www.moe.gov.cn/)
- [青少年心理健康研究](https://www.who.int/zh)

## 📌 License

MIT © 2025 tool-verse
