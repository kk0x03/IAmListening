import Foundation
import MediaPipeTasksGenAI
import AVFoundation

enum LLMMode {
    case local
    case api
    case fastgpt
}

class LLMInferenceService: NSObject, ObservableObject {
    private var llmInference: LlmInference?
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var currentMode: LLMMode = .local // 默认使用本地模式
    
    // 文字转语音相关属性
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var speechEnabled = true // 控制是否启用语音输出
    
    // API 配置
    private struct APIConfig {
        static let geminiAPIKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        static let geminiAPIURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
        
        static let fastgptAPIKey = ProcessInfo.processInfo.environment["FASTGPT_API_KEY"] ?? ""
        static let fastgptAPIURL = "https://api.fastgpt.in/api/v1/chat/completions"
    }
    
    override init() {
        super.init()
        loadModel()
        setupSpeechSynthesizer()
    }
    
    // 切换模式的方法
    func switchMode(to mode: LLMMode) {
        currentMode = mode
        if mode == .local {
            loadModel()
        } else {
            // API模式下，标记为已加载
            DispatchQueue.main.async {
                self.isModelLoaded = true
            }
        }
    }
    
    private func loadModel() {
        guard currentMode == .local else { return }
        
        guard let modelPath = Bundle.main.path(forResource: "gemma3-1b-it-int4", ofType: "task") else {
            print("Failed to find model file")
            return
        }
        
        let options = LlmInference.Options(modelPath: modelPath)
        
        do {
            llmInference = try LlmInference(options: options)
            DispatchQueue.main.async {
                self.isModelLoaded = true
            }
            print("Local model loaded successfully")
        } catch {
            print("Failed to load local model: \(error)")
        }
    }
    
    func generateResponse(for prompt: String, completion: @escaping (String?) -> Void) {
        switch currentMode {
        case .local:
            generateLocalResponse(for: prompt, completion: completion)
        case .api:
            generateAPIResponse(for: prompt, completion: completion)
        case .fastgpt:
            generateFastGPTResponse(for: prompt, completion: completion)
        }
    }
    
    func generateResponseAsync(for prompt: String) async -> String? {
        switch currentMode {
        case .local:
            return await generateLocalResponseAsync(for: prompt)
        case .api:
            return await generateAPIResponseAsync(for: prompt)
        case .fastgpt:
            return await generateFastGPTResponseAsync(for: prompt)
        }
    }
    
    // MARK: - 本地模型方法
    private func generateLocalResponse(for prompt: String, completion: @escaping (String?) -> Void) {
        guard let llmInference = llmInference, isModelLoaded else {
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isGenerating = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let response = try llmInference.generateResponse(inputText: prompt)
                DispatchQueue.main.async {
                    self.isGenerating = false
                    completion(response)
                }
            } catch {
                print("Local generation error: \(error)")
                DispatchQueue.main.async {
                    self.isGenerating = false
                    completion(nil)
                }
            }
        }
    }
    
    private func generateLocalResponseAsync(for prompt: String) async -> String? {
        guard let llmInference = llmInference, isModelLoaded else {
            return nil
        }
        
        await MainActor.run {
            self.isGenerating = true
        }
        
        do {
            let response = try llmInference.generateResponse(inputText: prompt)
            await MainActor.run {
                self.isGenerating = false
            }
            return response
        } catch {
            print("Local generation error: \(error)")
            await MainActor.run {
                self.isGenerating = false
            }
            return nil
        }
    }
    
    // MARK: - API模式方法
    private func generateAPIResponse(for prompt: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            self.isGenerating = true
        }
        
        Task {
            let response = await callGeminiAPI(with: prompt)
            DispatchQueue.main.async {
                self.isGenerating = false
                completion(response)
            }
        }
    }
    
    private func generateAPIResponseAsync(for prompt: String) async -> String? {
        await MainActor.run {
            self.isGenerating = true
        }
        
        let response = await callGeminiAPI(with: prompt)
        
        await MainActor.run {
            self.isGenerating = false
        }
        
        return response
    }
    
    private func callGeminiAPI(with prompt: String) async -> String? {
        guard !APIConfig.geminiAPIKey.isEmpty else {
            print("Gemini API key not found in environment variables")
            return nil
        }
        
        guard let url = URL(string: "\(APIConfig.geminiAPIURL)?key=\(APIConfig.geminiAPIKey)") else {
            print("Invalid API URL")
            return nil
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("API Response Status: \(httpResponse.statusCode)")
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = jsonResponse["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                return text
            } else {
                print("Failed to parse API response")
                return nil
            }
            
        } catch {
            print("API call error: \(error)")
            return nil
        }
    }
    
    // MARK: - FastGPT API 方法
    private func generateFastGPTResponse(for prompt: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            self.isGenerating = true
        }
        
        Task {
            let response = await callFastGPTAPI(with: prompt)
            DispatchQueue.main.async {
                self.isGenerating = false
                completion(response)
            }
        }
    }
    
    private func generateFastGPTResponseAsync(for prompt: String) async -> String? {
        await MainActor.run {
            self.isGenerating = true
        }
        
        let response = await callFastGPTAPI(with: prompt)
        
        await MainActor.run {
            self.isGenerating = false
        }
        
        return response
    }
    
    private func callFastGPTAPI(with prompt: String) async -> String? {
        guard !APIConfig.fastgptAPIKey.isEmpty else {
            print("FastGPT API key not found in environment variables")
            return nil
        }
        
        guard let url = URL(string: APIConfig.fastgptAPIURL) else {
            print("Invalid FastGPT API URL")
            return nil
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(APIConfig.fastgptAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("FastGPT API Response Status: \(httpResponse.statusCode)")
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = jsonResponse["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            } else {
                print("Failed to parse FastGPT API response")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                return nil
            }
            
        } catch {
            print("FastGPT API call error: \(error)")
            return nil
        }
    }
    
    // MARK: - 文字转语音功能
    
    /// 设置语音合成器
    private func setupSpeechSynthesizer() {
        speechSynthesizer.delegate = self
    }
    
    /// 朗读文本
    /// - Parameter text: 要朗读的文本
    func speakText(_ text: String) {
        guard speechEnabled && !text.isEmpty else { return }
        
        // 如果正在朗读，先停止
        if speechSynthesizer.isSpeaking {
            stopSpeaking()
        }
        
        // 创建语音话语
        let utterance = AVSpeechUtterance(string: text)
        
        // 设置语音参数
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN") // 中文语音
        utterance.rate = 0.5 // 语速 (0.0 - 1.0)
        utterance.pitchMultiplier = 1.0 // 音调 (0.5 - 2.0)
        utterance.volume = 0.8 // 音量 (0.0 - 1.0)
        
        // 开始朗读
        speechSynthesizer.speak(utterance)
        
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    /// 停止朗读
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    /// 暂停朗读
    func pauseSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    /// 继续朗读
    func continueSpeaking() {
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
        }
    }
    
    /// 切换语音输出开关
    func toggleSpeechEnabled() {
        speechEnabled.toggle()
        
        // 如果关闭语音输出且正在朗读，则停止朗读
        if !speechEnabled && speechSynthesizer.isSpeaking {
            stopSpeaking()
        }
    }
    
    /// 设置语音参数
    /// - Parameters:
    ///   - rate: 语速 (0.0 - 1.0)
    ///   - pitch: 音调 (0.5 - 2.0)
    ///   - volume: 音量 (0.0 - 1.0)
    func configureSpeechSettings(rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 0.8) {
        // 这些设置将在下次朗读时生效
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension LLMInferenceService: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        print("开始朗读")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
        print("朗读完成")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("朗读暂停")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("朗读继续")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
        print("朗读取消")
    }
}
