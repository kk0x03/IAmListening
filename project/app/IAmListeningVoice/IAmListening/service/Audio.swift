import Foundation
import AVFoundation
import Speech
class Audio: ObservableObject {
    static let shared = Audio()

    @Published var result: String = "未开始"
    @Published var isRecording: Bool = false
    @Published var partialResult: String = ""  // 新增：实时部分识别结果
    @Published var finalResult: String = ""    // 新增：最终确认结果

    private var yamnet = YAMNetService.shared
    private let llm = LLMInferenceService.shard
    private var audioEngine: AVAudioEngine!
    private var converter: AVAudioConverter?
    private var audioBuffer = [Float]()

    private let inputLength = 15600  // 0.975 秒，匹配 YAMNet 输入

    private var speechSegmentBuffer = [Float]()  // 说话段缓存
    private var isSpeaking = false
    private var lastSpeechTime: Date?
    private var collecting = false
    private var forceStopTimer: Timer?

    private let silenceTimeout: TimeInterval = 1.5  // 静音超时时间，避免正常说话中的短暂停顿
    private var lastASRUpdateTime: Date?  // 跟踪 ASR 结果最后更新时间
    private var lastASRContent: String = ""  // 跟踪上次 ASR 内容
    
    private let inferenceQueue = InferenceQueue()
    
    // 流式语音识别相关
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isStreamingASR = false

    // 启动流式ASR
    private func startStreamingASR() {
        guard !isStreamingASR else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true  // 关键：启用部分结果
        recognitionRequest?.requiresOnDeviceRecognition = false
        
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        // 最终结果
                        self?.finalResult = transcription
                        self?.partialResult = ""
                        
                        // 🔥 重置 ASR 跟踪状态
                        self?.lastASRUpdateTime = nil
                        self?.lastASRContent = ""
                        
                        print("🎯 最终识别结果: \(transcription)")
                        
                        // 触发LLM处理
                        Task {
                            await self?.llm.generateBlockingResponse(for: transcription)
                        }
                        
                        // 重启识别以继续监听
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self?.restartStreamingASR()
                        }
                    } else {
                        // 实时部分结果
                        self?.partialResult = transcription
                        
                        // 🔥 跟踪 ASR 内容变化
                        if transcription != self?.lastASRContent {
                            self?.lastASRUpdateTime = Date()
                            self?.lastASRContent = transcription
                        }
                        
                        print("⚡ 实时识别: \(transcription)")
                    }
                }
                
                if error != nil {
                    self?.stopStreamingASR()
                }
            }
        }
        
        isStreamingASR = true
    }
    
    // 停止流式ASR
    private func stopStreamingASR() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isStreamingASR = false
    }
    
    // 完成当前语音识别并重新开始新的识别会话
    private func finalizeSpeechRecognition() {
        guard isStreamingASR else { return }
        forceStopTimer?.invalidate()
        recognitionRequest?.endAudio()
        // 不要立即 cancel recognitionTask，等待 isFinal 回调
        // 由 recognitionTask 的回调中 isFinal 触发后再重启识别
    }
    
    // 重新启动流式ASR
    private func restartStreamingASR() {
        // 先停止当前的识别
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isStreamingASR = false
        
        // 🔥 重置 ASR 跟踪状态，准备接受新的语音输入
        lastASRUpdateTime = nil
        lastASRContent = ""
        partialResult = ""
        
        // 重新开始识别
        startStreamingASR()
        
        // 🔥 关键修复：重新启动兜底定时器
        forceStopTimer?.invalidate()
        forceStopTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            print("⏰ 8 秒兜底定时器触发，强制重启识别")
            // 🔥 关键修复：直接重启识别，不依赖 isFinal 回调
            self.restartStreamingASR()
        }
    }

    private func startAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try audioSession.setMode(.measurement)
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话配置失败: \(error)")
            return
        }

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16000,
                                         channels: 1,
                                         interleaved: false)!
        self.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        
        // 启动流式ASR
        startStreamingASR()
        
        var preSpeechBuffer: [Float] = []
        let preSpeechLength = 16000 * 2  // 2 秒预录

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                guard let converter = self.converter,
                      let newBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 4096) else { return }

                var error: NSError? = nil
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: newBuffer, error: &error, withInputFrom: inputBlock)

                if let err = error {
                    print("转换失败: \(err)")
                    return
                }

                guard let channelData = newBuffer.floatChannelData?[0] else { return }
                let frameCount = Int(newBuffer.frameLength)

                // 增益处理 + 降噪 + 限幅
                let gain: Float = 1.5
                let noiseThreshold: Float = 0.02  // 降噪阈值
                let segment = (0..<frameCount).map { i in
                    let sample = channelData[i] * gain
                    // 简单降噪：低于阈值的信号视为噪音，衰减处理
                    let denoisedSample = abs(sample) < noiseThreshold ? sample * 0.1 : sample
                    return max(-1.0, min(denoisedSample, 1.0))
                }
                
                // 计算当前音频段的音量（RMS）
                let rms = sqrt(segment.map { $0 * $0 }.reduce(0, +) / Float(segment.count))
                let volumeThreshold: Float = 0.03  // 音量阈值，低于此值认为是静音

                // 🔥 关键优化：同时发送音频到流式ASR
                if self.isStreamingASR, let recognitionRequest = self.recognitionRequest {
                    // 创建用于ASR的音频缓冲区（使用原始输入格式）
                    recognitionRequest.append(buffer)
                }

                // 1. 累积实时主 buffer
                self.audioBuffer.append(contentsOf: segment)

            if !self.collecting {
                // 2. 维护 2 秒预录缓存
                preSpeechBuffer.append(contentsOf: segment)
                if preSpeechBuffer.count > preSpeechLength {
                    preSpeechBuffer.removeFirst(preSpeechBuffer.count - preSpeechLength)
                }
            }
                

                // 3. 分类逻辑触发
                while self.audioBuffer.count >= self.inputLength {
                    let segment = Array(self.audioBuffer.prefix(self.inputLength))
                    self.audioBuffer.removeFirst(self.inputLength)

                    self.yamnet.runModel(audioData: segment)
                    let label = self.yamnet.classify.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔎 当前帧分类：[\(label)]")

                    // 🎯 改进的语音检测：优先使用实时识别结果，辅以分类和音量判断
                    let isSpeechClassified = label.lowercased().contains("speech") || 
                                           label.lowercased().contains("conversation") ||
                                           label.lowercased().contains("narration") ||
                                           label.lowercased().contains("monologue")
                    let hasValidVolume = rms > volumeThreshold
                    
                    // 🔥 关键改进：如果实时识别有输出且不为空，就认为是有效语音
                    let hasASROutput = !self.partialResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    
                    // 🔥 检查 ASR 内容是否超过2秒没有更新
                    let isASRStale: Bool
                    if let lastUpdateTime = self.lastASRUpdateTime {
                        isASRStale = Date().timeIntervalSince(lastUpdateTime) > 2.0
                    } else {
                        isASRStale = false
                    }
                    
                    // 🔥 关键修复：综合多个条件判断有效语音
                    let isSilenceClassified = label.lowercased().contains("silence")
                    let isVeryLowVolume = rms < 0.001  // 极低音量阈值
                    
                    let isValidSpeech: Bool
                    if isSilenceClassified && isVeryLowVolume {
                        // 明确的静音状态：分类为 Silence 且音量极低
                        isValidSpeech = false
                    } else if hasASROutput && isASRStale {
                        // ASR 有输出但超过2秒没有更新，认为是无效语音
                        isValidSpeech = false
                    } else {
                        // 其他情况：优先使用 ASR 输出，辅以分类和音量判断
                        isValidSpeech = hasASROutput || (isSpeechClassified && hasValidVolume)
                    }
                    
                    let asrStaleInfo = isASRStale ? "(超过2秒未更新)" : ""
                     print("🔎 分类: \(label), 音量: \(String(format: "%.4f", rms)), ASR输出: [\(self.partialResult)]\(asrStaleInfo), 有效语音: \(isValidSpeech)")
                    
                    if isValidSpeech {
                        if !self.collecting {
                            self.collecting = true
                            print("🎤 检测到有效语音开始 (分类: \(label), 音量: \(String(format: "%.4f", rms)))")
                        }
                        self.lastSpeechTime = Date()
                        
                        // 🔥 重置兜底定时器：检测到语音时重新计时
                        self.forceStopTimer?.invalidate()
                        self.forceStopTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                            print("⏰ 8 秒兜底定时器触发，强制重启识别")
                            // 🔥 关键修复：直接重启识别，不依赖 isFinal 回调
                            self.restartStreamingASR()
                        }
                    } else {
                        // 只有在确实检测到语音后才考虑静音超时
                        if self.collecting,
                           let lastTime = self.lastSpeechTime,
                           Date().timeIntervalSince(lastTime) >= self.silenceTimeout {
                            self.collecting = false
                            self.lastSpeechTime = nil
                            print("🔇 语音段结束，触发最终识别 (静音时长: \(String(format: "%.1f", Date().timeIntervalSince(lastTime)))秒)")
                            
                            // 🔥 关键修复：主动结束当前识别请求以获得最终结果
                            self.finalizeSpeechRecognition()
                        }
                    }
                }
            }
        do {
            try audioEngine.start()
            print("🎤 Audio engine started")
            
            // 启动流式ASR进行实时识别
            startStreamingASR()
            
            // 启动8秒兜底定时器
            forceStopTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                print("⏰ 8 秒兜底定时器触发，强制重启识别")
                // 🔥 关键修复：直接重启识别，不依赖 isFinal 回调
                self.restartStreamingASR()
            }
        } catch {
            print("音频引擎启动失败: \(error)")
        }
    }

    func toggle() {
        if isRecording {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            stopStreamingASR()  // 停止流式ASR
            isRecording = false
            
            // 只清空实时结果，保留最终结果供用户查看
            partialResult = ""
            // 不清空 finalResult，让用户能看到最后的识别结果
        } else {
            start()
        }
    }

    private func start() {
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("语音识别权限未授予")
                return
            }
            
            // 请求麦克风权限
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    print("麦克风权限未开启")
                    return
                }
                DispatchQueue.main.async {
                    self.startAudioEngine()
                    self.isRecording = true
                }
            }
        }
    }
}

actor InferenceQueue {
    func enqueue(buffer: [Float]) async {
        await WhisperState.shared.transcribeBuffer(buffer)
        await LLMInferenceService.shard.generateBlockingResponse(for: WhisperState.shared.messageLog)
    }
}
