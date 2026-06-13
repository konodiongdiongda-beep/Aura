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
        speaker: any AudioDataPlaying = AudioDataSpeaker()
    ) {
        self.upstream = upstream
        self.referenceCapture = referenceCapture
        self.speaker = speaker
    }

    func speak(_ text: String) async throws {
        let output = try await upstream.synthesize(text)
        guard !output.audioData.isEmpty else {
            try await upstream.speak(text)
            return
        }

        referenceCapture?.appendPlaybackAudioData(output.audioData)
        do {
            try await speaker.play(output.audioData)
        } catch {
            try await upstream.speak(text)
        }
    }

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        try await upstream.synthesize(text)
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

private final class AudioDataSpeaker: NSObject, AudioDataPlaying, AVAudioPlayerDelegate, @unchecked Sendable {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?

    func play(_ data: Data) async throws {
        cancel()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    let player = try AVAudioPlayer(data: data)
                    self.player = player
                    self.continuation = continuation
                    player.delegate = self
                    player.prepareToPlay()
                    guard player.play() else {
                        cleanup()
                        continuation.resume(throwing: VoiceCore.AppError.speechSynthesisFailed("Unable to start controlled audio playback."))
                        return
                    }
                } catch {
                    cleanup()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        guard player != nil || continuation != nil else { return }
        let pendingContinuation = continuation
        player?.stop()
        cleanup()
        pendingContinuation?.resume(throwing: CancellationError())
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let pendingContinuation = continuation
        cleanup()
        if flag {
            pendingContinuation?.resume()
        } else {
            pendingContinuation?.resume(throwing: VoiceCore.AppError.speechSynthesisFailed("Controlled audio playback failed."))
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let pendingContinuation = continuation
        cleanup()
        pendingContinuation?.resume(throwing: error ?? VoiceCore.AppError.speechSynthesisFailed("Controlled audio playback decode failed."))
    }

    private func cleanup() {
        player?.delegate = nil
        player = nil
        continuation = nil
    }
}
#endif
