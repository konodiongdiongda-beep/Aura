#if os(iOS)
import Foundation
import VoiceCore

final class MicrophoneAudioEvidenceBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let sampleRate: Int
    private let maxBytes: Int
    private var data = Data()

    init(sampleRate: Int, maxDuration: TimeInterval) {
        self.sampleRate = sampleRate
        self.maxBytes = max(1, Int(maxDuration * Double(sampleRate)) * 2)
    }

    func appendPCM16Mono(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        if data.count > maxBytes {
            data.removeFirst(data.count - maxBytes)
        }
        lock.unlock()
    }

    func snapshot(maxDuration: TimeInterval) -> SpeechAudioEvidence? {
        lock.lock()
        defer { lock.unlock() }

        guard !data.isEmpty else { return nil }
        let requestedBytes = max(1, Int(maxDuration * Double(sampleRate)) * 2)
        let byteCount = min(data.count, requestedBytes)
        guard byteCount > 0 else { return nil }

        let pcm = Data(data.suffix(byteCount))
        guard !pcm.isEmpty else { return nil }
        let duration = (Double(pcm.count) / 2.0) / Double(sampleRate)
        return SpeechAudioEvidence(
            pcm16MonoData: pcm,
            sampleRate: sampleRate,
            duration: duration
        )
    }
}
#endif
