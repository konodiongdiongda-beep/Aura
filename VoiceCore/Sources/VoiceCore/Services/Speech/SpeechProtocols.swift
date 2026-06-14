import Foundation

public enum SpeakerRoute: Equatable, Hashable, CaseIterable, Sendable {
    case speaker
    case receiver
    case bluetoothHFP
    case bluetoothA2DP

    public var displayName: String {
        switch self {
        case .speaker: "扬声器"
        case .receiver: "通话器"
        case .bluetoothHFP: "蓝牙免提"
        case .bluetoothA2DP: "蓝牙音频"
        }
    }
}

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
    /// Plays already-synthesized audio. Splitting this from `synthesize` lets the
    /// playback queue prefetch the next segment's audio while the current one is
    /// still playing, so segment boundaries don't insert a synthesis round-trip
    /// of silence. The default speaks the text so existing conformers still work.
    func play(_ output: SpeechSynthesisOutput) async throws
    func cancel() async
}

public extension SpeechSynthesizing {
    func play(_ output: SpeechSynthesisOutput) async throws {
        try await speak(output.text)
    }
}

public protocol AudioSessionManaging: Sendable {
    var isSpeakerEnabled: Bool { get async }
    var currentRoute: SpeakerRoute { get async }
    var availableRoutes: [SpeakerRoute] { get async }
    var actualOutputDescription: String { get async }

    func startCall() async throws
    func endCall() async
    func setSpeakerEnabled(_ enabled: Bool) async throws
    func setRoute(_ route: SpeakerRoute) async throws
}

public protocol SpeechPlaybackControlling: Sendable {
    func playbackEvents() async -> AsyncStream<SpeechPlaybackEvent>
    func enqueue(_ text: String, isFinal: Bool) async
    func clear() async
    func cancel() async
}
