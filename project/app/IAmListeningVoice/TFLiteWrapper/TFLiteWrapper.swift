//
//  Yamnet.swift
//  IAmListening-swift
//
//  Created by k k on 2025/6/7.
//
import Foundation
import TensorFlowLite
import AVFoundation
import Combine

@objc public class YAMNetModel: NSObject,ObservableObject {
    private let yamnetLabels: [String]

    // tensorflow
    private var interpreter: Interpreter!


    // 声音
    private var audioBuffer = [Float]()

    private let inputLength = 15600

    public override init() {
        
        yamnetLabels = YAMNetModel.loadLabels()
        super.init()
        self.setupModel()
    }

    private static func loadLabels() -> [String] {
        let frameworkBundle = Bundle(for: YAMNetModel.self)
        guard let filePath =  frameworkBundle.path(forResource: "yamnet_class_map", ofType: "csv") else {
            fatalError("标签文件未找到")
        }

        do {
            return try String(contentsOfFile: filePath, encoding: .utf8)
                .components(separatedBy: "\n")
                .dropFirst()
                .compactMap { $0.split(separator: ",").last.map(String.init) }
        } catch {
            fatalError("无法读取标签文件: \(error)")
        }
    }

    private func setupModel() {
        guard let modelPath = Bundle(for: Self.self).path(forResource: "yamnet", ofType: "tflite") else {
            fatalError("模型文件未找到")
        }

        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter.allocateTensors()
        } catch {
            fatalError("无法加载模型: \(error)")
        }
    }

    public func runModel(audioData: [Float]) -> String {
        guard let interpreter = interpreter else { return ""}

        do {
            let inputTesor = try interpreter.input(at: 0)
            let inputSize = inputTesor.shape.dimensions.reduce(1, *)

            guard audioData.count == inputSize else {
                print("输入数据维度不匹配")
                return ""
            }

            var data = Data()

            for value in audioData {
                data.append(contentsOf: withUnsafeBytes(of: value)  { Data($0) })
            }

            try interpreter.copy(data, toInputAt: 0)
            try interpreter.invoke()
            let outputTensor = try interpreter.output(at: 0)
            let scores = outputTensor.data.toArray(type: Float.self)

            if let maxScore = scores.max(), let maxIndex = scores.firstIndex(of: maxScore) {
                let label = yamnetLabels.indices.contains(maxIndex) ? yamnetLabels[maxIndex] : "未知"
                return label
            }
        } catch {
            print("模型运行失败: \(error)")
        }
        return ""
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
