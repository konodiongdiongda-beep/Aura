import XCTest
@testable import VoiceCore

/// Verifies the adapter that maps `SpeakerVerificationEngine` results onto the
/// coordinator's `UserTurnSpeakerEvidence` contract, including the
/// enroll-during-call policy.
private struct ToneEmbedding: SpeakerEmbedding {
    let dimension = 8
    private let bands: [Float] = [110, 165, 220, 290, 380, 500, 660, 880]
    func embed(samples: [Float]) -> [Float]? {
        guard samples.count >= 256 else { return nil }
        let sr: Float = 16_000
        var vec = [Float](repeating: 0, count: dimension)
        for (i, f) in bands.enumerated() {
            let w = 2 * Float.pi * f / sr
            let coeff = 2 * cos(w)
            var s1: Float = 0, s2: Float = 0
            for x in samples { let s0 = x + coeff * s1 - s2; s2 = s1; s1 = s0 }
            vec[i] = (s1 * s1 + s2 * s2 - coeff * s1 * s2).magnitude.squareRoot()
        }
        return vec
    }
}

final class SpeakerVerificationEvidenceProviderTests: XCTestCase {
    private func tone(_ freqs: [Double], seconds: Double = 2.0) -> SpeechAudioEvidence {
        let sr = 16_000
        let n = Int(Double(sr) * seconds)
        var data = Data(capacity: n * 2)
        for i in 0..<n {
            let t = Double(i) / Double(sr)
            let syllable = pow(max(0, sin(2 * .pi * 3.0 * t)), 2)
            let raw = freqs.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(max(freqs.count, 1))
            let pcm = Int16(max(-1, min(1, raw * 0.6 * syllable)) * 30_000)
            data.append(UInt8(truncatingIfNeeded: pcm))
            data.append(UInt8(truncatingIfNeeded: pcm >> 8))
        }
        return SpeechAudioEvidence(pcm16MonoData: data, sampleRate: sr, duration: seconds)
    }

    private func makeProvider(samples: Int = 1) -> SpeakerVerificationEvidenceProvider {
        SpeakerVerificationEvidenceProvider(
            engine: SpeakerVerificationEngine(model: ToneEmbedding()),
            requiredEnrollmentSamples: samples
        )
    }

    func testFirstCleanTurnEnrollsAndIsAcceptedAsCurrentUser() async {
        let provider = makeProvider()
        let r = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(
            audio: tone([180, 240]),
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            allowsEnrollment: true
        ))
        XCTAssertEqual(r?.match, .verifiedCurrentUser)
    }

    func testAfterEnrollmentDifferentSpeakerIsRejected() async {
        let provider = makeProvider()
        _ = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([180, 240])))
        let other = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([520, 760])))
        XCTAssertEqual(other?.match, .otherSpeaker)
    }

    func testAfterEnrollmentSameSpeakerIsVerified() async {
        let provider = makeProvider()
        _ = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([180, 240])))
        let same = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([180, 240])))
        XCTAssertEqual(same?.match, .verifiedCurrentUser)
    }

    func testPlaybackWindowAudioIsNotEnrolledAsCurrentUser() async {
        let provider = makeProvider()
        // An assistant-playback turn must not become the enrolled profile.
        let playback = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(
            audio: tone([520, 760]),
            isAssistantPlaybackActive: true,
            isInterruptedInput: false,
            allowsEnrollment: false
        ))
        XCTAssertNotEqual(playback?.match, .verifiedCurrentUser)

        // Then the genuine user enrolls and is accepted.
        let user = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([180, 240])))
        XCTAssertEqual(user?.match, .verifiedCurrentUser)
        // And the earlier playback speaker is now rejected as "other".
        let other = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(audio: tone([520, 760])))
        XCTAssertEqual(other?.match, .otherSpeaker)
    }
}
