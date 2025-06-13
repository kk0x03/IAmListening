//
//  Yamnet.swift
//  IAmListening-swift
//
//  Created by k k on 2025/6/7.
//
import Foundation
import AVFoundation
import TFLiteWrapper
class YAMNetService: ObservableObject {
    static let shared = YAMNetService()
    var yAMNetModel = YAMNetModel()
    @Published var result: String = "未开始"
    @Published var classify: String = ""
    @Published var isRecording: Bool = false
    
    
    // 声音
    private var audioEngine: AVAudioEngine!
    private var converter: AVAudioConverter?
    private var audioBuffer = [Float]()
    
    private let inputLength = 15600
    
    var onSpeechDetected: (() -> Void)?
    // 检查到类别是speech回调
    init() {
//        start()
    }
    
    public func runModel(audioData: [Float]) {
        let res = yAMNetModel.runModel(audioData: audioData)
        DispatchQueue.main.async {
            self.result = res
            self.classify = res
        }
    }
}
    
extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        let count = self.count / MemoryLayout<T>.stride
        return withUnsafeBytes { rawBufferPointer in
            let pointer = rawBufferPointer.baseAddress!.assumingMemoryBound(to: T.self)
            return Array(UnsafeBufferPointer(start: pointer, count: count))
        }
    }
}
