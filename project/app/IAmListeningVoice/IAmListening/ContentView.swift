import SwiftUI
import AVFoundation
import TFLiteWrapper

struct ContentView: View {
    @StateObject var yamnet = YAMNetService.shared
    @StateObject var audio = Audio.shared
    @StateObject var whisperState = WhisperState.shared
    @StateObject  var llm = LLMInferenceService.shard
    @State private var llmResult: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题区域
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("智能音频助手")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("实时音频识别与智能对话")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 状态指示器
                    HStack {
                        Circle()
                            .fill(audio.isRecording ? Color.red : Color.gray)
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.5), value: audio.isRecording)
                        Text(audio.isRecording ? "正在识别..." : "待机中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 音频分类结果卡片
                    ResultCard(
                        title: "音频分类",
                        content: yamnet.classify.isEmpty ? "等待音频输入..." : yamnet.classify,
                        icon: "music.note",
                        color: .orange
                    )
                    
                    // 实时语音识别结果卡片
                    VStack(spacing: 12) {
                        // 实时识别结果 - 始终显示
                        StreamingResultCard(
                            title: "实时识别",
                            content: audio.partialResult.isEmpty ? "等待语音输入..." : audio.partialResult,
                            icon: "waveform",
                            color: .blue,
                            isPartial: true
                        )
                        
                        // 最终确认结果
                        VStack(spacing: 8) {
                            StreamingResultCard(
                                title: "确认结果",
                                content: audio.finalResult.isEmpty ? "等待语音输入..." : audio.finalResult,
                                icon: "text.bubble.fill",
                                color: .green,
                                isPartial: false
                            )
                            
                            if !audio.finalResult.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("传给大模型")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("已发送")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                                }
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // AI回复结果卡片
                    ResultCard(
                        title: "AI助手回复",
                        content: llm.msg.isEmpty ? "等待语音确认后处理..." : llm.msg,
                        icon: "brain.head.profile",
                        color: .purple
                    )
                    
                    // 控制按钮
                    Button(action: {
                        audio.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: audio.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                            Text(audio.isRecording ? "停止识别" : "开始识别")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: audio.isRecording ? [.red, .pink] : [.blue, .cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: audio.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(audio.isRecording ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: audio.isRecording)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// 结果显示卡片组件
struct ResultCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// 流式识别结果卡片组件
struct StreamingResultCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    let isPartial: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .scaleEffect(isPartial && isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if isPartial {
                    Text("实时")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(8)
                        .opacity(isAnimating ? 1.0 : 0.6)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                Spacer()
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(isPartial ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isPartial ? 0.8 : 1.0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(isPartial ? 0.4 : 0.2), lineWidth: isPartial ? 2 : 1)
                .animation(.easeInOut(duration: 0.3), value: isPartial)
        )
        .onAppear {
            if isPartial {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .onChange(of: content) { _ in
            if isPartial {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ContentView()
}
