import XCTest
@testable import VoiceCore

final class VoiceInputFilteringTests: XCTestCase {
    func testLowVolumeDoesNotInterrupt() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .verifiedUser)
        )
        let event = VoiceActivityEvent(inputLevel: 0.12, duration: 1.0, isAIPlaybackActive: true)

        let decision = await gate.evaluate(event, speakerHint: .currentUser)

        XCTAssertEqual(decision, .reject(.rejectedNoise))
    }

    func testShortSpeechDoesNotInterrupt() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .verifiedUser)
        )
        let event = VoiceActivityEvent(inputLevel: 0.72, duration: 0.12, isAIPlaybackActive: true)

        let decision = await gate.evaluate(event, speakerHint: .currentUser)

        XCTAssertEqual(decision, .reject(.rejectedNoise))
    }

    func testAIEchoDoesNotInterrupt() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .verifiedUser)
        )
        let event = VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 1.0,
            isAIPlaybackActive: true,
            source: .aiPlaybackEcho
        )

        let decision = await gate.evaluate(event, speakerHint: .currentUser)

        XCTAssertEqual(decision, .reject(.rejectedEcho))
    }

    func testVerifiedUserSpeechInterrupts() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .verifiedUser)
        )
        let event = VoiceActivityEvent(inputLevel: 0.78, duration: 0.8, isAIPlaybackActive: true)

        let decision = await gate.evaluate(event, speakerHint: .currentUser)

        XCTAssertEqual(decision, .allowBargeIn(.verifiedUser))
    }

    func testOtherSpeakerDoesNotInterrupt() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .rejectedOtherSpeaker)
        )
        let event = VoiceActivityEvent(inputLevel: 0.78, duration: 0.8, isAIPlaybackActive: true)

        let decision = await gate.evaluate(event, speakerHint: .otherSpeaker)

        XCTAssertEqual(decision, .reject(.rejectedOtherSpeaker))
    }

    func testInsufficientSpeakerAudioProducesUnavailableState() async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: MockSpeakerVerifier(result: .unavailableInsufficientAudio)
        )
        let event = VoiceActivityEvent(inputLevel: 0.78, duration: 0.8, isAIPlaybackActive: true)

        let decision = await gate.evaluate(event, speakerHint: .unknown)

        XCTAssertEqual(decision, .needsSpeakerVerification(.unavailableInsufficientAudio))
    }

    func testPlaybackAwareSubmissionGateRejectsNonInterruptedPlaybackFinal() {
        let gate = PlaybackAwareUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "assistant audio recognized by microphone",
            isAssistantPlaybackActive: true,
            isInterruptedInput: false
        )

        XCTAssertEqual(gate.evaluate(candidate), .reject(.aiPlaybackEcho))
    }

    func testPlaybackAwareSubmissionGateAcceptsNormalFinal() {
        let gate = PlaybackAwareUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "current user question",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false
        )

        XCTAssertEqual(gate.evaluate(candidate), .accept)
    }

    func testPlaybackAwareSubmissionGateAcceptsInterruptedFinal() {
        let gate = PlaybackAwareUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "wait let me interrupt",
            isAssistantPlaybackActive: true,
            isInterruptedInput: true
        )

        XCTAssertEqual(gate.evaluate(candidate), .accept)
    }

    func testSpeakerProfileGateAcceptsVerifiedCurrentUser() {
        let gate = SpeakerProfileUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "current user question",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            speakerEvidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.91, threshold: 0.84)
        )

        XCTAssertEqual(gate.evaluate(candidate), .accept)
    }

    func testSpeakerProfileGateRejectsVerifiedEvidenceDuringPlaybackWithoutInterruption() {
        let gate = SpeakerProfileUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "assistant playback misclassified as user",
            isAssistantPlaybackActive: true,
            isInterruptedInput: false,
            speakerEvidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.91, threshold: 0.86)
        )

        XCTAssertEqual(gate.evaluate(candidate), .reject(.aiPlaybackEcho))
    }

    func testSpeakerProfileGateRejectsOtherSpeakerDuringListening() {
        let gate = SpeakerProfileUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "bystander speech",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            speakerEvidence: UserTurnSpeakerEvidence(match: .otherSpeaker, score: 0.52, threshold: 0.84)
        )

        XCTAssertEqual(gate.evaluate(candidate), .reject(.otherSpeaker))
    }

    func testSpeakerProfileGateRejectsUncertainSpeakerDuringPlayback() {
        let gate = SpeakerProfileUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "mixed playback speech",
            isAssistantPlaybackActive: true,
            isInterruptedInput: true,
            speakerEvidence: UserTurnSpeakerEvidence(match: .uncertain, score: 0.83, threshold: 0.86)
        )

        XCTAssertEqual(gate.evaluate(candidate), .reject(.uncertainSpeaker))
    }

    func testSpeakerProfileGateRejectsMissingEvidenceWhenStrict() {
        let gate = SpeakerProfileUserTurnSubmissionGate()
        let candidate = UserTurnSubmissionCandidate(
            text: "unknown speaker",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false
        )

        XCTAssertEqual(gate.evaluate(candidate), .reject(.speakerUnverified))
    }

    func testSpeakerProfileGateUsesPlaybackFallbackWhenEvidenceIsMissingAndNotStrict() {
        let gate = SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false)
        let normalCandidate = UserTurnSubmissionCandidate(
            text: "normal user speech without profile yet",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false
        )
        let playbackCandidate = UserTurnSubmissionCandidate(
            text: "assistant playback without profile yet",
            isAssistantPlaybackActive: true,
            isInterruptedInput: false
        )

        XCTAssertEqual(gate.evaluate(normalCandidate), .accept)
        XCTAssertEqual(gate.evaluate(playbackCandidate), .reject(.aiPlaybackEcho))
    }

    func testSpeakerProfileGatePassesUncertainToFallbackWhenLenient() {
        let gate = SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false)
        let normalCandidate = UserTurnSubmissionCandidate(
            text: "uncertain but plausible user speech",
            isAssistantPlaybackActive: false,
            isInterruptedInput: false,
            speakerEvidence: UserTurnSpeakerEvidence(match: .uncertain, score: 0.83, threshold: 0.86)
        )
        let bargeInCandidate = UserTurnSubmissionCandidate(
            text: "uncertain barge-in during playback",
            isAssistantPlaybackActive: true,
            isInterruptedInput: true,
            speakerEvidence: UserTurnSpeakerEvidence(match: .uncertain, score: 0.83, threshold: 0.86)
        )

        XCTAssertEqual(gate.evaluate(normalCandidate), .accept)
        XCTAssertEqual(gate.evaluate(bargeInCandidate), .accept)
    }
}
