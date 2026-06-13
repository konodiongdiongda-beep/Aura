import Foundation

/// Stateful CAM++ speaker-verification engine. Holds the enrolled profile
/// (running mean of L2-normalized embeddings) and answers verify/enroll using an
/// injected `SpeakerEmbedding`. Ported 1:1 from `voiceprint/server.py`.
public final class SpeakerVerificationEngine: @unchecked Sendable {
    private let model: any SpeakerEmbedding
    private let config: SpeakerVerificationConfiguration
    private let lock = NSLock()
    private var profile: [Float]?
    private var sampleCount = 0

    public init(
        model: any SpeakerEmbedding,
        configuration: SpeakerVerificationConfiguration = SpeakerVerificationConfiguration()
    ) {
        self.model = model
        self.config = configuration
    }

    public var threshold: Double { config.threshold }

    public var isEnrolled: Bool {
        lock.lock(); defer { lock.unlock() }
        return profile != nil
    }

    public var enrolledSampleCount: Int {
        lock.lock(); defer { lock.unlock() }
        return sampleCount
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        profile = nil
        sampleCount = 0
    }

    // MARK: - enrollment

    public func enroll(pcm16Mono data: Data, sampleRate: Int) -> SpeakerEnrollmentResult {
        let pcm = resample(decodePCM16(data), from: sampleRate)
        guard pcm.count >= config.targetSampleRate / 4 else {
            return SpeakerEnrollmentResult(
                ok: false, samples: enrolledSampleCount, voicedSeconds: 0,
                neededSeconds: config.minimumEnrollVoicedSeconds, error: "audio too short"
            )
        }
        let voiced = vadTrim(pcm)
        let voicedSeconds = voicedSeconds(pcm)
        guard voicedSeconds >= config.minimumEnrollVoicedSeconds else {
            return SpeakerEnrollmentResult(
                ok: false, samples: enrolledSampleCount, voicedSeconds: voicedSeconds,
                neededSeconds: config.minimumEnrollVoicedSeconds, error: "not enough speech"
            )
        }
        guard let embedding = embedNormalized(voiced) else {
            return SpeakerEnrollmentResult(
                ok: false, samples: enrolledSampleCount, voicedSeconds: voicedSeconds,
                neededSeconds: config.minimumEnrollVoicedSeconds, error: "embedding failed"
            )
        }
        let count = addEnrollment(embedding)
        return SpeakerEnrollmentResult(
            ok: true, samples: count, voicedSeconds: voicedSeconds,
            neededSeconds: config.minimumEnrollVoicedSeconds
        )
    }

    private func addEnrollment(_ embedding: [Float]) -> Int {
        lock.lock(); defer { lock.unlock() }
        if let existing = profile {
            let n = Float(sampleCount)
            var mean = [Float](repeating: 0, count: existing.count)
            for i in existing.indices { mean[i] = (existing[i] * n + embedding[i]) / (n + 1) }
            profile = l2Normalized(mean)
            sampleCount += 1
        } else {
            profile = embedding
            sampleCount = 1
        }
        return sampleCount
    }

    // MARK: - verification

    public func verify(pcm16Mono data: Data, sampleRate: Int) -> SpeakerVerificationResult {
        lock.lock()
        let ref = profile
        lock.unlock()
        guard let ref else {
            return SpeakerVerificationResult(
                isPrimarySpeaker: nil, score: 0, threshold: config.threshold,
                windows: 0, reason: "no enrollment"
            )
        }
        let pcm = resample(decodePCM16(data), from: sampleRate)
        guard pcm.count >= config.targetSampleRate / 4 else {
            return SpeakerVerificationResult(
                isPrimarySpeaker: nil, score: 0, threshold: config.threshold,
                windows: 0, reason: "audio too short"
            )
        }
        let (score, windows) = bestWindowScore(pcm, ref: ref)
        return SpeakerVerificationResult(
            isPrimarySpeaker: score >= config.threshold, score: score,
            threshold: config.threshold, windows: windows
        )
    }

    /// Slide a window over voiced audio; return (bestScore, windowCount). Mirrors
    /// `best_window_score` in the reference backend.
    private func bestWindowScore(_ pcm: [Float], ref: [Float]) -> (Double, Int) {
        let voiced = vadTrim(pcm)
        let win = Int(Double(config.targetSampleRate) * config.windowSeconds)
        let step = max(1, Int(Double(config.targetSampleRate) * config.windowStepSeconds))
        if voiced.count <= win {
            let s = embedNormalized(voiced).map { dot($0, ref) } ?? -2.0
            return (s, 1)
        }
        var best = -2.0
        var n = 0
        var start = 0
        while start + win <= voiced.count {
            let seg = Array(voiced[start..<start + win])
            if let e = embedNormalized(seg) { best = max(best, dot(e, ref)) }
            n += 1
            start += step
        }
        if let whole = embedNormalized(voiced) {
            best = max(best, dot(whole, ref))
            n += 1
        }
        return (best, n)
    }

    private func embedNormalized(_ samples: [Float]) -> [Float]? {
        guard let raw = model.embed(samples: samples) else { return nil }
        return l2Normalized(raw)
    }

    // MARK: - DSP helpers (ported from server.py)

    private func decodePCM16(_ data: Data) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(data.count / 2)
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            let count = buffer.count / 2
            for i in 0..<count {
                let lo = UInt16(buffer[i * 2])
                let hi = UInt16(buffer[i * 2 + 1]) << 8
                let value = Int16(bitPattern: hi | lo)
                out.append(Float(value) / 32_768.0)
            }
        }
        return out
    }

    private func resample(_ x: [Float], from sr: Int) -> [Float] {
        guard sr != config.targetSampleRate, !x.isEmpty else { return x }
        let nOut = Int((Double(x.count) * Double(config.targetSampleRate) / Double(sr)).rounded())
        guard nOut > 1 else { return x }
        var out = [Float](repeating: 0, count: nOut)
        for i in 0..<nOut {
            let pos = Double(i) * Double(x.count) / Double(nOut)
            let a = Int(pos)
            let frac = Float(pos - Double(a))
            let b = min(a + 1, x.count - 1)
            out[i] = x[a] * (1 - frac) + x[b] * frac
        }
        return out
    }

    private func frameRMS(_ pcm: [Float], frame: Int, hop: Int) -> [Float] {
        guard pcm.count >= frame else {
            if pcm.isEmpty { return [0] }
            var sum: Float = 0
            for v in pcm { sum += v * v }
            return [(sum / Float(pcm.count)).squareRoot()]
        }
        let n = 1 + (pcm.count - frame) / hop
        var rms = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var sum: Float = 0
            let base = i * hop
            for j in 0..<frame { let s = pcm[base + j]; sum += s * s }
            rms[i] = (sum / Float(frame) + 1e-12).squareRoot()
        }
        return rms
    }

    private func vadTrim(_ pcm: [Float]) -> [Float] {
        let frame = Int(Double(config.targetSampleRate) * 0.025)
        let hop = Int(Double(config.targetSampleRate) * 0.010)
        let rms = frameRMS(pcm, frame: frame, hop: hop)
        guard rms.count >= 4 else { return pcm }
        let floor = percentile(rms, 20)
        let peak = percentile(rms, 95)
        let thr = max(floor * 2.0, floor + 0.3 * (peak - floor))
        let voiced = rms.map { $0 >= thr }
        guard voiced.filter({ $0 }).count >= 3 else { return pcm }
        var mask = [Bool](repeating: false, count: pcm.count)
        let hang = Int(Double(config.targetSampleRate) * 0.10)
        for (i, v) in voiced.enumerated() where v {
            let a = max(0, i * hop - hang)
            let b = min(pcm.count, i * hop + frame + hang)
            if a < b { for k in a..<b { mask[k] = true } }
        }
        var kept = [Float]()
        kept.reserveCapacity(pcm.count)
        for (i, m) in mask.enumerated() where m { kept.append(pcm[i]) }
        return Double(kept.count) >= Double(config.targetSampleRate) * 0.3 ? kept : pcm
    }

    private func voicedSeconds(_ pcm: [Float]) -> Double {
        let frame = Int(Double(config.targetSampleRate) * 0.025)
        let hop = Int(Double(config.targetSampleRate) * 0.010)
        let rms = frameRMS(pcm, frame: frame, hop: hop)
        guard rms.count >= 4 else { return 0 }
        let floor = percentile(rms, 20)
        let thr = max(1e-4, floor * 1.8)
        let voicedFrames = rms.filter { $0 >= thr }.count
        return Double(voicedFrames) * Double(hop) / Double(config.targetSampleRate)
    }

    private func percentile(_ values: [Float], _ p: Double) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let rank = p / 100.0 * Double(sorted.count - 1)
        let lo = Int(rank)
        let hi = min(lo + 1, sorted.count - 1)
        let frac = Float(rank - Double(lo))
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }

    private func l2Normalized(_ v: [Float]) -> [Float] {
        var norm: Float = 0
        for x in v { norm += x * x }
        norm = norm.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    private func dot(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return -2.0 }
        var sum: Float = 0
        for i in a.indices { sum += a[i] * b[i] }
        return Double(sum)
    }
}
