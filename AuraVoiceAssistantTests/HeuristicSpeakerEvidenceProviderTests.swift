import XCTest
import VoiceCore
@testable import AuraVoiceAssistant

final class HeuristicSpeakerEvidenceProviderTests: XCTestCase {
    func testEnrollsThenAcceptsSimilarCurrentUserSample() async {
        let provider = HeuristicSpeakerEvidenceProvider(requiredEnrollmentSamples: 2)

        _ = await provider.evidence(for: toneEvidence(frequencies: [180, 260]))
        _ = await provider.evidence(for: toneEvidence(frequencies: [182, 262]))
        let result = await provider.evidence(for: toneEvidence(frequencies: [181, 261]))

        XCTAssertEqual(result?.match, .verifiedCurrentUser)
    }

    func testRejectsDifferentSpeakerAfterEnrollment() async {
        let provider = HeuristicSpeakerEvidenceProvider(requiredEnrollmentSamples: 2)

        _ = await provider.evidence(for: toneEvidence(frequencies: [180, 260]))
        _ = await provider.evidence(for: toneEvidence(frequencies: [182, 262]))
        let result = await provider.evidence(for: toneEvidence(frequencies: [430, 710]))

        XCTAssertEqual(result?.match, .otherSpeaker)
    }

    func testMarksBorderlineMatchAsUncertain() async {
        let provider = HeuristicSpeakerEvidenceProvider(
            requiredEnrollmentSamples: 1,
            acceptThreshold: 1.01,
            uncertainMargin: 0.05
        )

        _ = await provider.evidence(for: toneEvidence(frequencies: [180, 260]))
        let result = await provider.evidence(for: toneEvidence(frequencies: [180, 260]))

        XCTAssertEqual(result?.match, .uncertain)
    }

    func testDoesNotEnrollPlaybackWindowAudioAsCurrentUser() async {
        let provider = HeuristicSpeakerEvidenceProvider(requiredEnrollmentSamples: 1)

        let playbackResult = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(
            audio: toneEvidence(frequencies: [430, 710]),
            isAssistantPlaybackActive: true,
            isInterruptedInput: false,
            allowsEnrollment: false
        ))
        let userResult = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(
            audio: toneEvidence(frequencies: [180, 260]),
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            allowsEnrollment: true
        ))
        let repeatedUserResult = await provider.evidence(for: UserTurnSpeakerEvidenceRequest(
            audio: toneEvidence(frequencies: [181, 261]),
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            allowsEnrollment: true
        ))

        XCTAssertNotEqual(playbackResult?.match, .verifiedCurrentUser)
        XCTAssertEqual(userResult?.match, .verifiedCurrentUser)
        XCTAssertEqual(repeatedUserResult?.match, .verifiedCurrentUser)
    }

    func testReturnsUnavailableForTooShortAudio() async {
        let provider = HeuristicSpeakerEvidenceProvider(requiredEnrollmentSamples: 1)
        let result = await provider.evidence(for: SpeechAudioEvidence(
            pcm16MonoData: Data([0, 0, 1, 0]),
            sampleRate: 16_000,
            duration: 0.0001
        ))

        XCTAssertEqual(result?.match, .unavailable)
    }

    private func toneEvidence(frequencies: [Double], seconds: Double = 1.0) -> SpeechAudioEvidence {
        let sampleRate = 16_000
        let sampleCount = Int(Double(sampleRate) * seconds)
        var data = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let sample = frequencies.reduce(0.0) { partial, frequency in
                partial + sin(2 * Double.pi * frequency * time)
            } / Double(max(frequencies.count, 1))
            let envelope = min(1.0, sin(Double.pi * Double(index) / Double(sampleCount)) * 1.2)
            let pcm = Int16(max(-1, min(1, sample * envelope)) * 24_000)
            data.append(UInt8(truncatingIfNeeded: pcm))
            data.append(UInt8(truncatingIfNeeded: pcm >> 8))
        }
        return SpeechAudioEvidence(
            pcm16MonoData: data,
            sampleRate: sampleRate,
            duration: seconds
        )
    }
}
