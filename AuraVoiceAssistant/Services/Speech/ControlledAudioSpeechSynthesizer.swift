#if os(iOS)
import AVFoundation
import Foundation
import VoiceCore

actor ControlledAudioSpeechSynthesizer: SpeechSynthesizing {
    private let upstream: any SpeechSynthesizing
    private let speaker: any AudioDataPlaying
    private let referenceCapture: (any AssistantAudioReferenceCapturing)?

    init(
        upstream: any SpeechSynthesizing,
        referenceCapture: (any AssistantAudioReferenceCapturing)? = nil,
        speaker: any AudioDataPlaying
    ) {
        self.upstream = upstream
        self.referenceCapture = referenceCapture
        self.speaker = speaker
    }

    func speak(_ text: String) async throws {
        let output = try await upstream.synthesize(text)
        try await play(output)
    }

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        try await upstream.synthesize(text)
    }

    func play(_ output: SpeechSynthesisOutput) async throws {
        guard !output.audioData.isEmpty else {
            // No fallback to Azure's native speaker output: that path is
            // uncontrolled (quiet, invisible to VPIO echo cancellation) and was
            // the root cause of the quiet-volume + self-echo bugs. Surface the
            // failure instead so it's diagnosable rather than silently degraded.
            throw VoiceCore.AppError.speechSynthesisFailed("Azure synthesis returned empty audio data.")
        }

        referenceCapture?.appendPlaybackAudioData(output.audioData)
        try await speaker.play(output.audioData)
    }

    func cancel() async {
        speaker.cancel()
        referenceCapture?.resetPlaybackReference()
        await upstream.cancel()
    }
}

protocol AudioDataPlaying: Sendable {
    func play(_ data: Data) async throws
    func cancel()
}
#endif
