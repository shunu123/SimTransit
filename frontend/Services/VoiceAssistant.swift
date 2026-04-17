import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class VoiceAssistant: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0

    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // TTS Synthesizer
    private let synthesizer = AVSpeechSynthesizer()
    
    // Silence detection
    private var silenceTimer: Timer?
    var onSilenceRecognized: (() -> Void)?

    init() {
        setupInterruptionHandling()
    }

    private func setupInterruptionHandling() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
        #endif
    }

    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        // Stop currently speaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    func start() async {
        guard !isListening else { return }
        
        // Stop speaking if starting
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        isListening = true
        transcript = ""
        audioLevel = 0.0

        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in 
                cont.resume(returning: status) 
            }
        }
        
        guard auth == .authorized else { 
            isListening = false
            return 
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        guard session.recordPermission == .granted else {
            print("VoiceAssistant: Microphone permission not granted.")
            isListening = false
            return
        }
        
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { 
            print("VoiceAssistant: Audio session error: \(error)")
            isListening = false
            return 
        }
        #endif

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        // SAFE ACCESS TO Audio Engine
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 else {
            print("VoiceAssistant: Invalid audio format (rate is 0). Audio hardware might be busy.")
            stop()
            return
        }
        
        // Ensure clean state before starting
        input.removeTap(onBus: 0)
        
        var lastUpdate = Date().timeIntervalSince1970
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, self.isListening, let currentRequest = self.request else { return }
            currentRequest.append(buffer)
            
            // Calculate audio level (RMS)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frames {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frames))
            let level = min(max(rms * 10, 0), 1) // Normalized 0 to 1
            
            // Throttle MainActor updates to ~20fps to prevent massive SwiftUI lag
            let now = Date().timeIntervalSince1970
            if now - lastUpdate > 0.05 {
                lastUpdate = now
                Task { @MainActor in
                    self.audioLevel = level
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch { 
            print("VoiceAssistant: Audio engine start error: \(error)")
            stop()
            return 
        }

        print("VoiceAssistant: Listening started...")
        restartSilenceTimer()

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let r = result {
                    self.transcript = r.bestTranscription.formattedString
                    self.restartSilenceTimer()
                }
                
                if error != nil || result?.isFinal == true {
                    self.stop()
                    if error != nil {
                        print("VoiceAssistant: Task error: \(error!)")
                    }
                }
            }
        }
    }

    private func restartSilenceTimer() {
        silenceTimer?.invalidate()
        // Wait 3.5 seconds of silence before assuming the user is done speaking
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isListening else { return }
                self.stop()
                self.onSilenceRecognized?()
            }
        }
    }

    func stop() {
        guard isListening else { return }
        isListening = false
        silenceTimer?.invalidate()

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()

        request?.endAudio()
        request = nil

        task?.cancel()
        task = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        
        print("VoiceAssistant: Listening stopped.")
    }
}
