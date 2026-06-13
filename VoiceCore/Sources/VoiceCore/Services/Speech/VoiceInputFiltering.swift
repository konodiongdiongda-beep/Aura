import Foundation

public enum VoiceActivitySource: Equatable, Sendable {
    case unknown
    case environmentNoise
    case currentUser
    case otherSpeaker
    case aiPlaybackEcho
}

public enum SpeakerHint: Equatable, Sendable {
    case unknown
    case currentUser
    case otherSpeaker
}

public struct VoiceActivityEvent: Equatable, Sendable {
    public var inputLevel: Double
    public var duration: TimeInterval
    public var isAIPlaybackActive: Bool
    public var source: VoiceActivitySource
    public var audioEvidence: SpeechAudioEvidence?

    public init(
        inputLevel: Double,
        duration: TimeInterval,
        isAIPlaybackActive: Bool,
        source: VoiceActivitySource = .unknown,
        audioEvidence: SpeechAudioEvidence? = nil
    ) {
        self.inputLevel = inputLevel
        self.duration = duration
        self.isAIPlaybackActive = isAIPlaybackActive
        self.source = source
        self.audioEvidence = audioEvidence
    }
}

public enum VoiceActivityDecision: Equatable, Sendable {
    case accepted
    case rejectedNoise
    case rejectedEcho
}

public enum SpeakerVerificationDecision: Equatable, Sendable {
    case verifiedUser
    case rejectedOtherSpeaker
    case unavailableInsufficientAudio
    case disabled
}

public enum BargeInRejectionReason: Equatable, Sendable {
    case notAISpeaking
    case rejectedNoise
    case rejectedEcho
    case rejectedOtherSpeaker
    case verificationDisabled
}

public enum BargeInDecision: Equatable, Sendable {
    case allowBargeIn(SpeakerVerificationDecision)
    case reject(BargeInRejectionReason)
    case needsSpeakerVerification(SpeakerVerificationDecision)
}

public protocol VoiceInputFilter: Sendable {
    func evaluate(_ event: VoiceActivityEvent) async -> VoiceActivityDecision
}

public protocol SpeakerVerifying: Sendable {
    func verify(event: VoiceActivityEvent, speakerHint: SpeakerHint) async -> SpeakerVerificationDecision
}

public struct LocalVoiceActivityDetector: VoiceInputFilter {
    public var minimumSpeechLevel: Double
    public var minimumSpeechDuration: TimeInterval

    public init(
        minimumSpeechLevel: Double = 0.35,
        minimumSpeechDuration: TimeInterval = 0.35
    ) {
        self.minimumSpeechLevel = minimumSpeechLevel
        self.minimumSpeechDuration = minimumSpeechDuration
    }

    public func evaluate(_ event: VoiceActivityEvent) async -> VoiceActivityDecision {
        if event.isAIPlaybackActive && event.source == .aiPlaybackEcho {
            return .rejectedEcho
        }

        guard event.source != .environmentNoise,
              event.inputLevel >= minimumSpeechLevel,
              event.duration >= minimumSpeechDuration else {
            return .rejectedNoise
        }

        return .accepted
    }
}

public struct BargeInGate: Sendable {
    private let voiceActivityDetector: any VoiceInputFilter
    private let speakerVerifier: any SpeakerVerifying

    public init(
        voiceActivityDetector: any VoiceInputFilter = LocalVoiceActivityDetector(),
        speakerVerifier: any SpeakerVerifying = MockSpeakerVerifier()
    ) {
        self.voiceActivityDetector = voiceActivityDetector
        self.speakerVerifier = speakerVerifier
    }

    public func evaluate(_ event: VoiceActivityEvent, speakerHint: SpeakerHint = .unknown) async -> BargeInDecision {
        guard event.isAIPlaybackActive else {
            return .reject(.notAISpeaking)
        }

        let activityDecision = await voiceActivityDetector.evaluate(event)
        switch activityDecision {
        case .accepted:
            break
        case .rejectedNoise:
            return .reject(.rejectedNoise)
        case .rejectedEcho:
            return .reject(.rejectedEcho)
        }

        let speakerDecision = await speakerVerifier.verify(event: event, speakerHint: speakerHint)
        switch speakerDecision {
        case .verifiedUser:
            return .allowBargeIn(.verifiedUser)
        case .disabled:
            return .allowBargeIn(.disabled)
        case .rejectedOtherSpeaker:
            return .reject(.rejectedOtherSpeaker)
        case .unavailableInsufficientAudio:
            return .needsSpeakerVerification(.unavailableInsufficientAudio)
        }
    }
}

public struct MockSpeakerVerifier: SpeakerVerifying {
    public var result: SpeakerVerificationDecision

    public init(result: SpeakerVerificationDecision = .disabled) {
        self.result = result
    }

    public func verify(event: VoiceActivityEvent, speakerHint: SpeakerHint) async -> SpeakerVerificationDecision {
        if result != .disabled {
            return result
        }

        switch speakerHint {
        case .currentUser:
            return .verifiedUser
        case .otherSpeaker:
            return .rejectedOtherSpeaker
        case .unknown:
            return .disabled
        }
    }
}

public struct UserTurnSubmissionCandidate: Equatable, Sendable {
    public var text: String
    public var isAssistantPlaybackActive: Bool
    public var isInterruptedInput: Bool
    public var speakerEvidence: UserTurnSpeakerEvidence?

    public init(
        text: String,
        isAssistantPlaybackActive: Bool,
        isInterruptedInput: Bool,
        speakerEvidence: UserTurnSpeakerEvidence? = nil
    ) {
        self.text = text
        self.isAssistantPlaybackActive = isAssistantPlaybackActive
        self.isInterruptedInput = isInterruptedInput
        self.speakerEvidence = speakerEvidence
    }
}

public enum UserTurnSpeakerMatch: Equatable, Sendable {
    case verifiedCurrentUser
    case otherSpeaker
    case uncertain
    case unavailable
}

public struct UserTurnSpeakerEvidence: Equatable, Sendable {
    public var match: UserTurnSpeakerMatch
    public var score: Double?
    public var threshold: Double?
    public var margin: Double?
    public var profileID: String?

    public init(
        match: UserTurnSpeakerMatch,
        score: Double? = nil,
        threshold: Double? = nil,
        margin: Double? = nil,
        profileID: String? = nil
    ) {
        self.match = match
        self.score = score
        self.threshold = threshold
        self.margin = margin
        self.profileID = profileID
    }
}

public struct SpeechAudioEvidence: Equatable, Sendable {
    public var pcm16MonoData: Data
    public var sampleRate: Int
    public var duration: TimeInterval

    public init(pcm16MonoData: Data, sampleRate: Int, duration: TimeInterval) {
        self.pcm16MonoData = pcm16MonoData
        self.sampleRate = sampleRate
        self.duration = duration
    }
}

public struct UserTurnSpeakerEvidenceRequest: Equatable, Sendable {
    public var audio: SpeechAudioEvidence
    public var isAssistantPlaybackActive: Bool
    public var isInterruptedInput: Bool
    public var allowsEnrollment: Bool

    public init(
        audio: SpeechAudioEvidence,
        isAssistantPlaybackActive: Bool = false,
        isInterruptedInput: Bool = false,
        allowsEnrollment: Bool = true
    ) {
        self.audio = audio
        self.isAssistantPlaybackActive = isAssistantPlaybackActive
        self.isInterruptedInput = isInterruptedInput
        self.allowsEnrollment = allowsEnrollment
    }
}

public enum UserTurnSubmissionRejectionReason: Equatable, Sendable {
    case speakerUnverified
    case otherSpeaker
    case aiPlaybackEcho
    case uncertainSpeaker
}

public enum UserTurnSubmissionDecision: Equatable, Sendable {
    case accept
    case reject(UserTurnSubmissionRejectionReason)
}

public protocol UserTurnSubmissionGating: Sendable {
    func evaluate(_ candidate: UserTurnSubmissionCandidate) -> UserTurnSubmissionDecision
}

public protocol UserTurnSpeakerEvidenceProviding: Sendable {
    func evidence(for request: UserTurnSpeakerEvidenceRequest) async -> UserTurnSpeakerEvidence?
}

public extension UserTurnSpeakerEvidenceProviding {
    func evidence(for audio: SpeechAudioEvidence) async -> UserTurnSpeakerEvidence? {
        await evidence(for: UserTurnSpeakerEvidenceRequest(audio: audio))
    }
}

public struct NoopUserTurnSpeakerEvidenceProvider: UserTurnSpeakerEvidenceProviding {
    public init() {}

    public func evidence(for request: UserTurnSpeakerEvidenceRequest) async -> UserTurnSpeakerEvidence? {
        nil
    }
}

public struct AcceptingUserTurnSubmissionGate: UserTurnSubmissionGating {
    public init() {}

    public func evaluate(_ candidate: UserTurnSubmissionCandidate) -> UserTurnSubmissionDecision {
        .accept
    }
}

public struct PlaybackAwareUserTurnSubmissionGate: UserTurnSubmissionGating {
    public init() {}

    public func evaluate(_ candidate: UserTurnSubmissionCandidate) -> UserTurnSubmissionDecision {
        guard candidate.isAssistantPlaybackActive, !candidate.isInterruptedInput else {
            return .accept
        }
        return .reject(.aiPlaybackEcho)
    }
}

public struct SpeakerProfileUserTurnSubmissionGate: UserTurnSubmissionGating {
    private let requiresVerifiedSpeaker: Bool
    private let fallbackGate: any UserTurnSubmissionGating

    public init(
        requiresVerifiedSpeaker: Bool = true,
        fallbackGate: any UserTurnSubmissionGating = PlaybackAwareUserTurnSubmissionGate()
    ) {
        self.requiresVerifiedSpeaker = requiresVerifiedSpeaker
        self.fallbackGate = fallbackGate
    }

    public func evaluate(_ candidate: UserTurnSubmissionCandidate) -> UserTurnSubmissionDecision {
        if candidate.isAssistantPlaybackActive, !candidate.isInterruptedInput {
            return .reject(.aiPlaybackEcho)
        }

        if let evidence = candidate.speakerEvidence {
            switch evidence.match {
            case .verifiedCurrentUser:
                return .accept
            case .otherSpeaker:
                return .reject(.otherSpeaker)
            case .uncertain:
                if requiresVerifiedSpeaker {
                    return .reject(.uncertainSpeaker)
                }
                return fallbackGate.evaluate(candidate)
            case .unavailable:
                break
            }
        }

        guard requiresVerifiedSpeaker else {
            return fallbackGate.evaluate(candidate)
        }

        if candidate.isAssistantPlaybackActive {
            return .reject(.aiPlaybackEcho)
        }
        return .reject(.speakerUnverified)
    }
}
