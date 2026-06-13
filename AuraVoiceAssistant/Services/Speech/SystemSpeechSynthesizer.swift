#if os(iOS)
import AVFoundation
import Foundation
import VoiceCore

actor SystemSpeechSynthesizer: SpeechSynthesizing {
    private let speaker = SystemSpeechSpeaker()

    func speak(_ text: String) async throws {
        try await speaker.speak(text)
    }

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        try await speak(text)
        return SpeechSynthesisOutput(audioData: Data(), text: text)
    }

    func cancel() async {
        speaker.cancel()
    }
}

private final class SystemSpeechSpeaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async throws {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        cancel()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let utterance = AVSpeechUtterance(string: cleanText)
                utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                utterance.rate = 0.48
                utterance.pitchMultiplier = 1.0
                utterance.volume = 1.0
                synthesizer.speak(utterance)
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        guard continuation != nil || synthesizer.isSpeaking else { return }
        let pendingContinuation = continuation
        continuation = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        pendingContinuation?.resume(throwing: CancellationError())
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let pendingContinuation = continuation
        continuation = nil
        pendingContinuation?.resume()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let pendingContinuation = continuation
        continuation = nil
        pendingContinuation?.resume(throwing: CancellationError())
    }
}
#endif
