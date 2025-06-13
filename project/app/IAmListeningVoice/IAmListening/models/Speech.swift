import Speech
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
    private let recognizerQueue = DispatchQueue(label: "speech.recognizer.queue")

    @Published var transcript = "等待识别..."

    func transcribePCMBuffer(_ floatBuffer: [Float], sampleRate: Double = 16000.0, completion: @escaping (String) -> Void) {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let frameCount = AVAudioFrameCount(floatBuffer.count)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            completion("语音缓冲创建失败")
            return
        }
        pcmBuffer.frameLength = frameCount
        let dest = pcmBuffer.floatChannelData![0]
        for i in 0..<floatBuffer.count {
            dest[i] = floatBuffer[i]
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false

        let recognizer = self.recognizer
        let audioEngine = AVAudioEngine()

        recognizerQueue.async {
            request.append(pcmBuffer)
            request.endAudio()

            recognizer.recognitionTask(with: request) { result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        completion(result.bestTranscription.formattedString)
                    } else {
                        completion("语音识别失败")
                    }
                }
            }
        }
    }
}

//import Speech
//import AVFoundation
//
//class SpeechRecognizer: NSObject, ObservableObject {
//    private let audioEngine = AVAudioEngine()
//    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
//    private var recognitionTask: SFSpeechRecognitionTask?
//    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
//
//    @Published var transcript = "等待识别..."
//    var isTranscribing = false
//
//    override init() {
//        super.init()
//        requestPermission()
//    }
//
//    func requestPermission() {
//        SFSpeechRecognizer.requestAuthorization { authStatus in
//            DispatchQueue.main.async {
//                if authStatus != .authorized {
//                    self.transcript = "权限未授予"
//                }
//            }
//        }
//    }
//
//    func startTranscribing() {
//        guard !isTranscribing else { return }
//        isTranscribing = true
//
//        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
//        let inputNode = audioEngine.inputNode
//
//        let recordingFormat = inputNode.outputFormat(forBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
//            (buffer, _) in
//            self.recognitionRequest?.append(buffer)
//        }
//
//        audioEngine.prepare()
//        try? audioEngine.start()
//
//        guard let recognitionRequest = recognitionRequest else { return }
//
//        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { result, error in
//            if let result = result {
//                DispatchQueue.main.async {
//                    self.transcript = result.bestTranscription.formattedString
//                }
//            }
//            if error != nil {
//                self.stopTranscribing()
//            }
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//            self.stopTranscribing()
//        }
//    }
//
//    func stopTranscribing() {
//        audioEngine.stop()
//        recognitionRequest?.endAudio()
//        recognitionTask?.cancel()
//        audioEngine.inputNode.removeTap(onBus: 0)
//        isTranscribing = false
//    }
//}