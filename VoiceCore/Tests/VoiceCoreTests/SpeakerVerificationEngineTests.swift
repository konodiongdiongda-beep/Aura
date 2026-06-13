import XCTest
@testable import VoiceCore

/// A deterministic stand-in for the CAM++ model. It derives an embedding from
/// the *dominant low-frequency content* of the samples, so different synthetic
/// "speakers" (different tone frequencies) produce well-separated embeddings.
/// This lets us test the VAD / sliding-window / threshold / enrollment pipeline
/// without the native ONNX model.
private struct ToneEmbedding: SpeakerEmbedding {
    let dimension = 8
    private let bands: [Float] = [110, 165, 220, 290, 380, 500, 660, 880]

    func embed(samples: [Float]) -> [Float]? {
        guard samples.count >= 256 else { return nil }
        // Goertzel-ish band energy -> embedding. Pure, deterministic.
        let sr: Float = 16_000
        var vec = [Float](repeating: 0, count: dimension)
        for (i, f) in bands.enumerated() {
            let w = 2 * Float.pi * f / sr
            let coeff = 2 * cos(w)
            var s0: Float = 0, s1: Float = 0, s2: Float = 0
            for x in samples { s0 = x + coeff * s1 - s2; s2 = s1; s1 = s0 }
            vec[i] = (s1 * s1 + s2 * s2 - coeff * s1 * s2).magnitude.squareRoot()
        }
        return vec
    }
}

final class SpeakerVerificationEngineTests: XCTestCase {
    private func tone(_ freqs: [Double], seconds: Double = 2.0, amplitude: Double = 0.6) -> Data {
        let sr = 16_000
        let n = Int(Double(sr) * seconds)
        var data = Data(capacity: n * 2)
        for i in 0..<n {
            let t = Double(i) / Double(sr)
            // Syllable-rate amplitude modulation + periodic silence gaps so the
            // signal has speech-like dynamic range (voiced vs. quiet frames),
            // which the energy VAD needs to find voiced speech.
            let syllable = pow(max(0, sin(2 * .pi * 3.0 * t)), 2) // 3 Hz, gated
            let raw = freqs.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(max(freqs.count, 1))
            let pcm = Int16(max(-1, min(1, raw * amplitude * syllable)) * 30_000)
            data.append(UInt8(truncatingIfNeeded: pcm))
            data.append(UInt8(truncatingIfNeeded: pcm >> 8))
        }
        return data
    }

    private func silence(seconds: Double = 2.0) -> Data {
        let n = Int(16_000 * seconds)
        return Data(count: n * 2)
    }

    func testEnrollThenVerifiesSameSpeaker() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        let e = engine.enroll(pcm16Mono: tone([180, 240]), sampleRate: 16_000)
        XCTAssertTrue(e.ok, "expected enrollment to succeed, got \(e)")
        XCTAssertTrue(engine.isEnrolled)

        let r = engine.verify(pcm16Mono: tone([180, 240]), sampleRate: 16_000)
        XCTAssertEqual(r.isPrimarySpeaker, true, "same speaker should pass, score=\(r.score)")
        XCTAssertGreaterThanOrEqual(r.score, r.threshold)
    }

    func testRejectsDifferentSpeaker() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        _ = engine.enroll(pcm16Mono: tone([180, 240]), sampleRate: 16_000)

        let r = engine.verify(pcm16Mono: tone([520, 760]), sampleRate: 16_000)
        XCTAssertEqual(r.isPrimarySpeaker, false, "different speaker should be rejected, score=\(r.score)")
        XCTAssertLessThan(r.score, r.threshold)
    }

    func testVerifyWithoutEnrollmentReportsNoEnrollment() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        let r = engine.verify(pcm16Mono: tone([180, 240]), sampleRate: 16_000)
        XCTAssertNil(r.isPrimarySpeaker)
        XCTAssertEqual(r.reason, "no enrollment")
    }

    func testEnrollRejectsSilenceAsNotEnoughSpeech() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        let e = engine.enroll(pcm16Mono: silence(), sampleRate: 16_000)
        XCTAssertFalse(e.ok)
        XCTAssertEqual(e.error, "not enough speech")
        XCTAssertFalse(engine.isEnrolled)
    }

    func testEnrollRejectsTooShortAudio() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        let e = engine.enroll(pcm16Mono: tone([180, 240], seconds: 0.1), sampleRate: 16_000)
        XCTAssertFalse(e.ok)
        XCTAssertEqual(e.error, "audio too short")
    }

    func testResetClearsProfile() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        _ = engine.enroll(pcm16Mono: tone([180, 240]), sampleRate: 16_000)
        XCTAssertTrue(engine.isEnrolled)
        engine.reset()
        XCTAssertFalse(engine.isEnrolled)
        XCTAssertEqual(engine.enrolledSampleCount, 0)
    }

    func testSlidingWindowRecoversPrimarySpeakerInPollutedClip() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        _ = engine.enroll(pcm16Mono: tone([180, 240], seconds: 3), sampleRate: 16_000)
        // Clip: 1.5s of an impostor, then 2s of the primary speaker. The best
        // window should still match the primary speaker.
        var clip = tone([520, 760], seconds: 1.5)
        clip.append(tone([180, 240], seconds: 2.0))
        let r = engine.verify(pcm16Mono: clip, sampleRate: 16_000)
        XCTAssertGreaterThan(r.windows, 1, "should have scored multiple windows")
        XCTAssertEqual(r.isPrimarySpeaker, true, "primary speaker window should win, score=\(r.score)")
    }

    func testRunningMeanEnrollmentCountsSamples() {
        let engine = SpeakerVerificationEngine(model: ToneEmbedding())
        _ = engine.enroll(pcm16Mono: tone([180, 240]), sampleRate: 16_000)
        _ = engine.enroll(pcm16Mono: tone([182, 242]), sampleRate: 16_000)
        XCTAssertEqual(engine.enrolledSampleCount, 2)
    }
}
