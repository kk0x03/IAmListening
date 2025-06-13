//
//  FastGPTService.swift
//  IAmListening
//
//  Created by AI Assistant on 2025/6/7.
//

import Foundation

class FastGPTService {
    static let shared = FastGPTService()
    
    private let apiToken: String
    private let knowledgeBaseName = "IAmListening"
    private let baseURL = "https://api.fastgpt.in/api/core/dataset"
    
    private init() {
        // 从环境变量或Info.plist获取API Token
        if let token = ProcessInfo.processInfo.environment["FASTGPT_API_TOKEN"] ?? Bundle.main.infoDictionary?["FASTGPT_API_TOKEN"] as? String {
            self.apiToken = token
        } else {
            // 提供一个默认值或错误处理
            self.apiToken = ""
            print("警告: 未找到FastGPT API Token环境变量或Info.plist配置")
        }
    }
    
    // 同步预警信息到FastGPT知识库
    func syncAlertToKnowledgeBase(scenario: String, information: String, suggestedAction: String, originalText: String) async {
        // 构建要同步的数据
        let alertData = AlertData(
            scenario: scenario,
            information: information,
            suggestedAction: suggestedAction,
            originalText: originalText,
            timestamp: Date()
        )
        
        // 先获取知识库ID
        guard let datasetId = await getDatasetId() else {
            print("无法获取知识库ID")
            return
        }
        
        // 创建collection并获取collectionId
        guard let collectionId = await createCollection(datasetId: datasetId, alertData: alertData) else {
            print("无法创建collection")
            return
        }
        
        // 使用collectionId上传数据到知识库
        await uploadDataToKnowledgeBase(collectionId: collectionId, alertData: alertData)
    }
    
    // 获取知识库ID
    private func getDatasetId() async -> String? {
        guard let url = URL(string: "\(baseURL)/list") else {
            print("无效的URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("获取知识库列表状态码: \(httpResponse.statusCode)")
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let datasets = jsonResponse["data"] as? [[String: Any]] {
                
                // 查找指定名称的知识库
                for dataset in datasets {
                    if let name = dataset["name"] as? String,
                        name == knowledgeBaseName,
                        let id = dataset["_id"] as? String {
                        print("找到知识库: \(name), ID: \(id)")
                        return id
                    }
                }
                
                print("未找到名为'\(knowledgeBaseName)'的知识库")
                return nil
            }
            
        } catch {
            print("获取知识库列表失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // 创建collection
    private func createCollection(datasetId: String, alertData: AlertData) async -> String? {
        guard let url = URL(string: "\(baseURL)/collection/create/text") else {
            print("无效的创建collection URL")
            return nil
        }
        
        let content = buildContentForUpload(alertData: alertData)
        let collectionName = "预警事件-\(alertData.scenario)-\(formatDate(alertData.timestamp))"
        
        let requestBody: [String: Any] = [
            "text": content,
            "datasetId": datasetId,
            "name": collectionName,
            "trainingType": "qa"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("创建collection状态码: \(httpResponse.statusCode)")
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responseData = jsonResponse["data"] as? [String: Any],
                let collectionId = responseData["collectionId"] as? String {
                print("成功创建collection，ID: \(collectionId)")
                return collectionId
            } else {
                print("创建collection失败，响应: \(String(data: data, encoding: .utf8) ?? "无法解析")")
                return nil
            }
            
        } catch {
            print("创建collection时出错: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 上传数据到知识库
    private func uploadDataToKnowledgeBase(collectionId: String, alertData: AlertData) async {
        guard let url = URL(string: "\(baseURL)/data/pushData") else {
            print("无效的上传URL")
            return
        }
        
        // 构建上传的内容
        let content = buildContentForUpload(alertData: alertData)
        
        let requestBody: [String: Any] = [
            "collectionId": collectionId,
            "trainingType": "qa",
            "data": [
                [
                    "q": "预警事件-\(alertData.scenario)-\(formatDate(alertData.timestamp))",
                    "a": content
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ 预警信息已成功同步到FastGPT知识库")
                } else {
                    print("❌ 同步到FastGPT失败，状态码: \(httpResponse.statusCode)")
                }
            }
            
            // 打印响应内容（用于调试）
            if let responseString = String(data: data, encoding: .utf8) {
                print("FastGPT API响应: \(responseString)")
            }
            
        } catch {
            print("同步到FastGPT时出错: \(error.localizedDescription)")
        }
    }
    
    // 构建上传内容
    private func buildContentForUpload(alertData: AlertData) -> String {
        let dateString = formatDate(alertData.timestamp)
        
        return """
        【预警事件记录】
        
        时间：\(dateString)
        场景类型：\(alertData.scenario)
        事件描述：\(alertData.information)
        建议行动：\(alertData.suggestedAction)
        
        原始语音内容：\(alertData.originalText)
        
        ---
        此记录由IAmListening智能音频助手自动生成
        """
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 预警数据结构
struct AlertData {
    let scenario: String
    let information: String
    let suggestedAction: String
    let originalText: String
    let timestamp: Date
}