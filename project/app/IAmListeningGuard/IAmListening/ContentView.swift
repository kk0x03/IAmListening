import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct ContentView: View {
    @StateObject private var llmService = LLMInferenceService()
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 状态栏
                statusBar
                
                // 消息列表
                messagesList
                
                // 输入区域
                inputArea
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 避免 iPad 上的分屏问题
    }
    
    // MARK: - 状态栏
    private var statusBar: some View {
        HStack {
            Text("I Am Listening")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            
            // 模式切换开关
            HStack(spacing: 8) {
                Text("模式:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("LLM Mode", selection: $llmService.currentMode) {
                    Text("本地").tag(LLMMode.local)
                    Text("API").tag(LLMMode.api)
                    Text("FastGPT").tag(LLMMode.fastgpt)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
                .onChange(of: llmService.currentMode) { _, newMode in
                    llmService.switchMode(to: newMode)
                }
            }
            
            HStack(spacing: 8) {
                // 语音控制按钮
                Button(action: {
                    llmService.toggleSpeechEnabled()
                }) {
                    Image(systemName: llmService.speechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundColor(llmService.speechEnabled ? .blue : .gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                
                // 朗读状态指示器
                if llmService.isSpeaking {
                    Button(action: {
                        llmService.stopSpeaking()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Circle()
                    .fill(llmService.isModelLoaded ? .green : .red)
                    .frame(width: 8, height: 8)
                Text({
                    switch llmService.currentMode {
                    case .local:
                        return llmService.isModelLoaded ? "本地模型已加载" : "加载中..."
                    case .api:
                        return llmService.isModelLoaded ? "Gemini API已连接" : "API未连接"
                    case .fastgpt:
                        return llmService.isModelLoaded ? "FastGPT已连接" : "API未连接"
                    }
                }())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if llmService.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 消息列表
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyStateView
                    }
                    
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .environmentObject(llmService)
                            .id(message.id)
                    }
                    
                    if llmService.isGenerating {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: llmService.isGenerating) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text({
                switch llmService.currentMode {
                case .local:
                    return "本地 AI 助手已准备就绪"
                case .api:
                    return "Gemini API 助手已准备就绪"
                case .fastgpt:
                    return "FastGPT 助手已准备就绪"
                }
            }())
                .font(.headline)
                .foregroundColor(.secondary)
            Text({
                switch llmService.currentMode {
                case .local:
                    return "使用 Gemma 3 模型为您提供智能对话"
                case .api:
                    return "使用 Google Gemini API 为您提供智能对话"
                case .fastgpt:
                    return "使用 FastGPT 平台为您提供智能对话"
                }
            }())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    // MARK: - 输入区域
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("输入消息...", text: $newMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(!llmService.isModelLoaded)
                    .onSubmit {
                        if canSendMessage {
                            sendMessage()
                        }
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            canSendMessage ? Color.blue : Color.gray
                        )
                        .clipShape(Circle())
                }
                .disabled(!canSendMessage)
                .animation(.easeInOut(duration: 0.2), value: canSendMessage)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - 计算属性
    private var canSendMessage: Bool {
        !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        llmService.isModelLoaded &&
        !llmService.isGenerating
    }
    
    // MARK: - 方法
    private func sendMessage() {
        let trimmedMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // 添加用户消息
        let userMessage = Message(text: trimmedMessage, isUser: true, timestamp: Date())
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.append(userMessage)
        }
        
        // 清空输入框
        newMessage = ""
        
        // 生成 AI 回复
        generateAIResponse(for: trimmedMessage)
    }
    
    private func generateAIResponse(for userMessage: String) {
        // 根据模式决定是否使用系统提示词
        let finalPrompt: String
        
        switch llmService.currentMode {
        case .fastgpt:
            // FastGPT 不需要系统提示词，直接使用用户消息
            finalPrompt = userMessage
        case .local, .api:
            // 本地模式和 API 模式需要系统提示词
            let conversationContext = buildConversationContext()
            finalPrompt = "\(conversationContext)\nUser: \(userMessage)\nAssistant:"
        }
        
        Task {
            // 使用 async 方法
            if let response = await llmService.generateResponseAsync(for: finalPrompt) {
                let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanResponse.isEmpty {
                    // 尝试解析JSON并检查紧急程度
                    await parseResponseAndHandleEmergency(response: cleanResponse)
                    
                    let aiMessage = Message(
                        text: cleanResponse,
                        isUser: false,
                        timestamp: Date()
                    )
                    
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.messages.append(aiMessage)
                        }
                        
                        // 自动朗读AI回复
                        if self.llmService.speechEnabled {
                            self.llmService.speakText(cleanResponse)
                        }
                    }
                    return
                }
            }
            
            // 错误处理
            let errorMessage = Message(
                text: "抱歉，我现在无法回复。请稍后再试。",
                isUser: false,
                timestamp: Date()
            )
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.messages.append(errorMessage)
                }
            }
        }
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
        
        let notificationURL = "https://api.day.app/6xFDMpuyo48upDhYc8upqa/\(notificationBody)?isArchive=1"
        
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
    }
    
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
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let lastMessage = messages.last {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else if llmService.isGenerating {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - MessageBubble
struct MessageBubble: View {
    let message: Message
    @EnvironmentObject var llmService: LLMInferenceService
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if !message.isUser {
                        // AI消息的朗读按钮
                        Button(action: {
                            llmService.speakText(message.text)
                        }) {
                            Image(systemName: "speaker.wave.1")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(llmService.speechEnabled ? 1.0 : 0.3)
                        .disabled(!llmService.speechEnabled)
                    }
                    
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(message.isUser ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(message.isUser ? .white : .primary)
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - TypingIndicator
struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray5))
        )
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    ContentView()
}
