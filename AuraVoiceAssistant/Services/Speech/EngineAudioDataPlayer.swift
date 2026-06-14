#if os(iOS)
import AVFoundation
import Foundation
import VoiceCore

/// Plays TTS audio through the shared engine's `AVAudioPlayerNode` instead of a
/// standalone `AVAudioPlayer`. Routing playback through the same engine that
/// captures the mic is what lets VPIO cancel the assistant's own voice and
/// keeps speaker output at normal loudness.
final class EngineAudioDataPlayer: AudioDataPlaying, @unchecked Sendable {
    private let sharedEngine: SharedVoiceAudioEngine
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var meteringTask: Task<Void, Never>?

    init(sharedEngine: SharedVoiceAudioEngine) {
        self.sharedEngine = sharedEngine
    }

    func play(_ data: Data) async throws {
        cancel()
        guard let buffer = Self.makeBuffer(from: data) else {
            throw VoiceCore.AppError.speechSynthesisFailed("Unable to decode TTS audio for engine playback.")
        }

        // Connect the player node at the buffer's exact format BEFORE starting or
        // scheduling. scheduleBuffer requires the connection format to match the
        // buffer, otherwise it raises an Objective-C exception → SIGABRT.
        sharedEngine.prepareForPlayback(format: buffer.format)
        try sharedEngine.start()
        let playerNode = sharedEngine.playerNode

        let peak = Self.peakAmplitude(of: buffer)
        NSLog("[EngineAudioDataPlayer] play frames=\(buffer.frameLength) rate=\(buffer.format.sampleRate) peak=\(String(format: "%.2f", peak))")

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                lock.lock()
                continuation = cont
                lock.unlock()

                playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                    self?.finishPlayback()
                }
                playerNode.play()
                startMeteringLoop(buffer: buffer)
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()

        sharedEngine.playerNode.stop()
        meteringTask?.cancel()
        meteringTask = nil
        AudioLevelMonitor.shared.currentLevel = 0.0
        pending?.resume(throwing: CancellationError())
    }

    private func finishPlayback() {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()

        meteringTask?.cancel()
        meteringTask = nil
        AudioLevelMonitor.shared.currentLevel = 0.0
        pending?.resume()
    }

    private func startMeteringLoop(buffer: AVAudioPCMBuffer) {
        meteringTask?.cancel()
        let node = sharedEngine.playerNode
        // Precompute a per-window RMS envelope so the on-screen wave tracks the
        // actual TTS audio instead of a constant placeholder.
        let envelope = Self.rmsEnvelope(of: buffer, windowsPerSecond: 30)
        meteringTask = Task { [weak self] in
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)
                guard self != nil, node.isPlaying else {
                    AudioLevelMonitor.shared.currentLevel = 0.0
                    break
                }
                let elapsed = Date().timeIntervalSince(start)
                let idx = Int(elapsed * 30)
                let level = (idx >= 0 && idx < envelope.count) ? envelope[idx] : 0.0
                AudioLevelMonitor.shared.currentLevel = level
            }
        }
    }

    /// Splits the buffer into ~`windowsPerSecond` windows and returns the RMS
    /// (0..1) of each, so playback metering reflects real amplitude over time.
    private static func rmsEnvelope(of buffer: AVAudioPCMBuffer, windowsPerSecond: Int) -> [Double] {
        let frames = Int(buffer.frameLength)
        guard frames > 0, windowsPerSecond > 0 else { return [] }
        let windowSize = max(1, Int(buffer.format.sampleRate) / windowsPerSecond)
        var envelope: [Double] = []
        envelope.reserveCapacity(frames / windowSize + 1)

        if let ch = buffer.floatChannelData {
            var i = 0
            while i < frames {
                let end = min(i + windowSize, frames)
                var sum: Double = 0
                for j in i..<end { let s = Double(ch[0][j]); sum += s * s }
                envelope.append(min(1, (sum / Double(end - i)).squareRoot()))
                i = end
            }
        } else if let ch = buffer.int16ChannelData {
            var i = 0
            while i < frames {
                let end = min(i + windowSize, frames)
                var sum: Double = 0
                for j in i..<end { let s = Double(ch[0][j]) / Double(Int16.max); sum += s * s }
                envelope.append(min(1, (sum / Double(end - i)).squareRoot()))
                i = end
            }
        }
        return envelope
    }

    private static func makeBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        do {
            try data.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            NSLog("[EngineAudioDataPlayer] decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func peakAmplitude(of buffer: AVAudioPCMBuffer) -> Double {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        if let ch = buffer.floatChannelData {
            var maxV: Float = 0
            for i in 0..<frames { maxV = max(maxV, abs(ch[0][i])) }
            return Double(min(1, maxV))
        }
        if let ch = buffer.int16ChannelData {
            var maxV: Int16 = 0
            for i in 0..<frames {
                let s = ch[0][i]
                let mag = s == Int16.min ? Int16.max : abs(s)
                if mag > maxV { maxV = mag }
            }
            return Double(maxV) / Double(Int16.max)
        }
        return 0
    }
}
#endif
