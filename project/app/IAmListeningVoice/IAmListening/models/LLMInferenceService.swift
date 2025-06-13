import Foundation
import MediaPipeTasksGenAI

enum LLMMode {
    case local
    case api
}

// 消息结构体
struct ChatMessage {
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(text: String, isUser: Bool) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }
}

class LLMInferenceService: ObservableObject {
    static let shard = LLMInferenceService()
    
    private var llmInference: LlmInference?
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var currentMode: LLMMode = .api // 默认使用本地模式
    @Published var msg: String = "" // AI回复消息
    
    // 消息历史管理
    @Published var messages: [ChatMessage] = []
    private let maxMessages = 10 // 最大保存消息数量
    
    // Gemini API 配置
    private let geminiAPIKey: String
    private let geminiAPIURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    
    private init() {
        // 从环境变量或Info.plist获取API Key
        if let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String {
            self.geminiAPIKey = apiKey
        } else {
            // 提供一个默认值或错误处理
            self.geminiAPIKey = ""
            print("警告: 未找到Gemini API Key环境变量或Info.plist配置")
        }
        
        loadModel()
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
    
    // 添加消息到历史记录
    private func addMessage(_ text: String, isUser: Bool) {
        let message = ChatMessage(text: text, isUser: isUser)
        DispatchQueue.main.async {
            self.messages.append(message)
            // 保持消息数量在限制内
            if self.messages.count > self.maxMessages {
                self.messages.removeFirst(self.messages.count - self.maxMessages)
            }
        }
    }
    
    // 构建对话上下文和场景识别提示词
    private func buildConversationContext() -> String {
        let systemPrompt = """
        你是一个专业的场景识别AI助手。请根据用户输入的语音识别内容，从以下3个预定义场景中选择最匹配的场景，并返回结构化信息。
        
        
        预定义场景列表：
        1. 校园暴力 - 涉及学校环境中的欺凌、威胁、身体伤害、恐吓、强迫等暴力行为或相关求助信号
        2. 医嘱信息 - 医生在医院环境中给出的治疗建议、用药指导、注意事项、复诊安排等医疗相关指示
        3. 日常交流 - 普通对话、闲聊、一般性咨询、学习工作等非紧急情况
        
        
        场景识别关键词参考：
        - 校园暴力：打、踢、威胁、欺负、不敢说、害怕、同学、老师、学校、霸凌、恐吓、强迫、伤害
        - 医嘱信息：医生说、要吃药、按时服用、注意、禁止、复查、检查、治疗、剂量、副作用、医院
        - 日常交流：其他所有不涉及上述两种紧急情况的内容
        
        
        请严格按照以下JSON格式返回结果：
        {
            "场景": "[校园暴力/医嘱信息/日常交流]",
            "信息": "[核心内容摘要，不超过40字]",
            "紧急程度": "[低/中/高]",
            "建议行动": "[针对性的具体建议]"
        }
        
        
        特殊处理规则：
        - 校园暴力：紧急程度标记为"高"，建议行动包含"立即寻求帮助"、"告知可信任的成年人"等
        - 医嘱信息：按医嘱重要性标记紧急程度，提取关键用药信息、注意事项，建议行动包含"严格遵医嘱"等
        - 日常交流：紧急程度标记为"低"，给出常规性建议或回应
        
        
        注意：
        - 必须严格按照JSON格式返回，不要有多余文字
        - 优先保障人身安全，校园暴力场景务必触发预警
        - 医嘱信息要准确提取重要医疗指导内容
        - 信息字段要简洁准确，突出核心要点
        
        
        用户输入的语音识别内容：
        """
        
        let recentMessages = messages.suffix(3) // 减少到最近3条消息，专注于当前问题
        let context = recentMessages.map { message in
            let role = message.isUser ? "用户" : "助手"
            return "\(role): \(message.text)"
        }.joined(separator: "\n")
        
        return "\(systemPrompt)\n\n对话历史：\n\(context)\n\n请分析最新的用户输入并返回JSON格式的场景识别结果："
    }
    
    // 阻塞式生成回复（用于Audio.swift调用）
    func generateBlockingResponse(for userInput: String) async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 添加用户消息到历史
        addMessage(userInput, isUser: true)
        
        // 构建包含场景识别提示词的完整上下文
        let fullPrompt = buildConversationContext() + userInput
        
        // 生成AI回复
        if let response = await generateResponseAsync(for: fullPrompt) {
            // 添加AI回复到历史
            addMessage(response, isUser: false)
            
            // 更新UI显示的消息
            DispatchQueue.main.async {
                self.msg = response
            }
            
            // 新增：解析响应并处理紧急情况
            await parseResponseAndHandleEmergency(response: response)
        } else {
            DispatchQueue.main.async {
                self.msg = "抱歉，无法生成回复，请稍后重试。"
            }
        }
    }
    
    func generateResponse(for prompt: String, completion: @escaping (String?) -> Void) {
        switch currentMode {
        case .local:
            generateLocalResponse(for: prompt, completion: completion)
        case .api:
            generateAPIResponse(for: prompt, completion: completion)
        }
    }
    
    func generateResponseAsync(for prompt: String) async -> String? {
        switch currentMode {
        case .local:
            return await generateLocalResponseAsync(for: prompt)
        case .api:
            return await generateAPIResponseAsync(for: prompt)
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
        guard let url = URL(string: "\(geminiAPIURL)?key=\(geminiAPIKey)") else {
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
    
    // MARK: - 辅助方法
    
    // 清空对话历史
    func clearMessages() {
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.msg = ""
        }
    }
    
    // 获取最新的用户输入
    func getLatestUserInput() -> String? {
        return messages.last(where: { $0.isUser })?.text
    }
    
    // 新增：解析响应并处理紧急情况
    private func parseResponseAndHandleEmergency(response: String) async {
        do {
            // 尝试从响应中提取JSON部分
            let jsonString = extractJSONFromResponse(response)
            
            // 添加提取的JSON内容日志
            print("提取的JSON字符串: \(jsonString)")
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("无法将响应转换为Data，原始响应: \(response)")
                return
            }
            
            // 解析JSON
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            guard let jsonDict = jsonObject as? [String: Any] else {
                print("JSON格式不正确，原始响应: \(response)，提取的JSON: \(jsonString)")
                return
            }
            
            // 添加解析成功的JSON内容日志
            print("成功解析的JSON内容: \(jsonDict)")
            
            let scenario = jsonDict["场景"] as? String ?? "未知场景"
            let information = jsonDict["信息"] as? String ?? "无详细信息"
            let suggestedAction = jsonDict["建议行动"] as? String ?? "无建议行动"
            
            // 检查紧急程度或特殊场景
            if let urgencyLevel = jsonDict["紧急程度"] as? String,
               urgencyLevel == "高" {
            
                print("检测到高紧急程度事件，准备发送通知")
                await sendEmergencyNotification(scenario: scenario, information: information, suggestedAction: suggestedAction)
            }
            // 特殊处理：医嘱信息场景也需要预警推送
            else if scenario == "医嘱信息" {
                print("检测到医嘱信息，准备发送预警通知")
                await sendEmergencyNotification(scenario: scenario, information: information, suggestedAction: suggestedAction)
            }
            
        } catch {
            print("JSON解析失败: \(error.localizedDescription)，原始响应: \(response)")
            // JSON解析失败时不发送通知，只打印日志
        }
    }
    
    // 新增：从响应中提取JSON字符串
    private func extractJSONFromResponse(_ response: String) -> String {
        // 查找JSON开始和结束的位置
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(response[jsonRange])
        }
        
        // 如果没有找到完整的JSON，返回原始响应
        return response
    }
    
    // 新增：发送紧急通知
    private func sendEmergencyNotification(scenario: String, information: String, suggestedAction: String) async {
        // 根据场景类型设置不同的通知标题
        let notificationTitle: String
        if scenario == "医嘱信息" {
            notificationTitle = "医疗提醒 - 重要医嘱"
        } else {
            notificationTitle = "紧急情况警报 - \(scenario)"
        }
        
        let notificationBody = "情况描述：\(information)\n\n建议行动：\(suggestedAction)\n\n时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))"
        
        let notificationURL = ProcessInfo.processInfo.environment["NOTIFICATION_URL"]
        
        guard let url = URL(string: notificationURL) else {
            print("通知URL无效: \(notificationURL)")
            return
        }
    
        let requestBody: [String: Any] = [
            "title": notificationTitle,
            "body": notificationBody,
            "sound": "alarm",
            "badge": 1
        ]
        
        // 添加发送的通知内容日志
        print("准备发送通知内容: \(requestBody)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("紧急通知发送成功")
                } else {
                    print("紧急通知发送失败，状态码: \(httpResponse.statusCode)")
                }
            }
            
            // 打印响应内容（用于调试）
            if let responseString = String(data: data, encoding: .utf8) {
                print("通知API响应: \(responseString)")
            }
            
        } catch {
            print("发送通知时出错: \(error.localizedDescription)")
        }
        
        // 🆕 同步预警信息到FastGPT知识库
        await syncToFastGPT(scenario: scenario, information: information, suggestedAction: suggestedAction)
    }
    
    // 新增：同步到FastGPT知识库
    private func syncToFastGPT(scenario: String, information: String, suggestedAction: String) async {
        // 获取原始用户输入文本
        let originalText = getLatestUserInput() ?? "无原始文本"
        
        // 调用FastGPT服务进行同步
        await FastGPTService.shared.syncAlertToKnowledgeBase(
            scenario: scenario,
            information: information,
            suggestedAction: suggestedAction,
            originalText: originalText
        )
    }
}
