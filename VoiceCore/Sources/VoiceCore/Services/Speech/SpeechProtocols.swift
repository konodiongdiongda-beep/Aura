import Foundation

public struct AzureSpeechConfiguration: Equatable, Sendable {
    public var subscriptionKey: String
    public var region: String
    public var recognitionLanguage: String
    public var preferredVoiceName: String

    public init(
        subscriptionKey: String,
        region: String,
        recognitionLanguage: String = "zh-CN",
        preferredVoiceName: String
    ) {
        self.subscriptionKey = subscriptionKey
        self.region = region
        self.recognitionLanguage = recognitionLanguage
        self.preferredVoiceName = preferredVoiceName
    }

    public func validated() throws -> AzureSpeechConfiguration {
        let trimmedKey = subscriptionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedRegion.isEmpty else {
            throw AppError.missingAzureSpeechConfig
        }

        return AzureSpeechConfiguration(
            subscriptionKey: trimmedKey,
            region: trimmedRegion,
            recognitionLanguage: recognitionLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "zh-CN" : recognitionLanguage.trimmingCharacters(in: .whitespacesAndNewlines),
            preferredVoiceName: preferredVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public enum SpeechRecognitionEvent: Equatable, Sendable {
    case voiceActivity(VoiceActivityEvent)
    case partial(String)
    case final(String)
    case finalWithEvidence(String, UserTurnSpeakerEvidence)
    case finalWithAudioEvidence(String, SpeechAudioEvidence)
}

public struct SpeechSynthesisOutput: Equatable, Sendable {
    public var audioData: Data
    public var text: String

    public init(audioData: Data, text: String) {
        self.audioData = audioData
        self.text = text
    }
}

public enum SpeechPlaybackEvent: Equatable, Sendable {
    case started(String)
    case finished(String)
    case cancelled
    case drained
}

public protocol SpeechRecognizing: Sendable {
    func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error>
    func start() async throws
    func stop() async
    func cancel() async
    /// Called by the coordinator whenever AI playback starts or stops.
    /// Implementations can use this to tag outgoing VAD events accurately.
    /// Default implementation is a no-op so existing conformances need no changes.
    func notifyPlaybackStateChanged(_ isActive: Bool) async
}

public extension SpeechRecognizing {
    func notifyPlaybackStateChanged(_ isActive: Bool) async {}
}

public protocol SpeechSynthesizing: Sendable {
    func speak(_ text: String) async throws
    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput
    func cancel() async
}

public protocol AudioSessionManaging: Sendable {
    var isSpeakerEnabled: Bool { get async }

    func startCall() async throws
    func endCall() async
    func setSpeakerEnabled(_ enabled: Bool) async throws
}

public protocol SpeechPlaybackControlling: Sendable {
    func playbackEvents() async -> AsyncStream<SpeechPlaybackEvent>
    func enqueue(_ text: String, isFinal: Bool) async
    func clear() async
    func cancel() async
}
