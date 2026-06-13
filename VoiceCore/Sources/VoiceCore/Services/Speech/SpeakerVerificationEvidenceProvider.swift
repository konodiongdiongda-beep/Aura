import Foundation

/// Bridges `SpeakerVerificationEngine` to the coordinator's
/// `UserTurnSpeakerEvidenceProviding` protocol.
///
/// Enrollment policy mirrors the previous heuristic provider so call flow is
/// unchanged: the first voiced user turns (while the assistant is NOT playing and
/// the input is not an interruption) are auto-enrolled as the primary speaker;
/// once enrolled, every turn is verified against the CAM++ profile. This keeps
/// "first speaker owns the session" behavior while swapping the fake spectral
/// features for the real 192-dim speaker embedding.
public actor SpeakerVerificationEvidenceProvider: UserTurnSpeakerEvidenceProviding {
    private let engine: SpeakerVerificationEngine
    private let requiredEnrollmentSamples: Int
    private let profileID: String

    public init(
        engine: SpeakerVerificationEngine,
        requiredEnrollmentSamples: Int = 2,
        profileID: String = "campplus-primary-v1"
    ) {
        self.engine = engine
        self.requiredEnrollmentSamples = requiredEnrollmentSamples
        self.profileID = profileID
    }

    public func evidence(for request: UserTurnSpeakerEvidenceRequest) async -> UserTurnSpeakerEvidence? {
        let audio = request.audio
        let threshold = engine.threshold

        // Already enrolled -> verify every turn.
        if engine.isEnrolled {
            let result = engine.verify(pcm16Mono: audio.pcm16MonoData, sampleRate: audio.sampleRate)
            guard let isPrimary = result.isPrimarySpeaker else {
                // Not enough usable audio to decide.
                return UserTurnSpeakerEvidence(
                    match: .unavailable, threshold: threshold, profileID: profileID
                )
            }
            return UserTurnSpeakerEvidence(
                match: isPrimary ? .verifiedCurrentUser : .otherSpeaker,
                score: result.score,
                threshold: result.threshold,
                profileID: profileID
            )
        }

        // Not enrolled yet. Only enroll on clean, non-interrupted, playback-free
        // turns; otherwise we cannot yet make a speaker decision.
        guard request.allowsEnrollment,
              !request.isAssistantPlaybackActive,
              !request.isInterruptedInput else {
            return UserTurnSpeakerEvidence(
                match: .uncertain, threshold: threshold,
                profileID: profileID + "-unenrolled"
            )
        }

        let enrollment = engine.enroll(pcm16Mono: audio.pcm16MonoData, sampleRate: audio.sampleRate)
        guard enrollment.ok else {
            // Couldn't enroll this sample (too short / not enough speech).
            return UserTurnSpeakerEvidence(
                match: .uncertain, threshold: threshold,
                profileID: profileID + "-enrolling"
            )
        }
        // Accept the enrolling speaker as the current user so their turn submits.
        return UserTurnSpeakerEvidence(
            match: .verifiedCurrentUser,
            score: 1.0,
            threshold: threshold,
            profileID: profileID + "-enrolling"
        )
    }
}
