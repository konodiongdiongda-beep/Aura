import Foundation

public actor MockSpeechRecognizer: SpeechRecognizing {
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    private var isRunning = false

    public init() {}

    public func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    public func start() async throws {
        isRunning = true
    }

    public func stop() async {
        isRunning = false
        continuation?.finish()
    }

    public func cancel() async {
        isRunning = false
        continuation?.finish()
    }

    public func emitPartial(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.partial(text))
    }

    public func emitFinal(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.final(text))
    }

    public func fail(_ error: Error) {
        continuation?.finish(throwing: error)
    }
}

public actor MockSpeechSynthesizer: SpeechSynthesizing {
    public private(set) var spokenTexts: [String] = []
    public private(set) var synthesizedTexts: [String] = []
    public private(set) var cancelCount = 0

    public init() {}

    public func speak(_ text: String) async throws {
        spokenTexts.append(text)
    }

    public func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        synthesizedTexts.append(text)
        return SpeechSynthesisOutput(audioData: Data(text.utf8), text: text)
    }

    public func cancel() async {
        cancelCount += 1
    }
}

public actor MockAudioSessionManager: AudioSessionManaging {
    public private(set) var isActive = false
    public private(set) var isSpeakerEnabled: Bool
    public private(set) var currentRoute: SpeakerRoute = .speaker
    public private(set) var availableRoutes: [SpeakerRoute] = [.speaker, .receiver]
    public var actualOutputDescription: String { currentRoute.displayName }

    public init(isSpeakerEnabled: Bool = true) {
        self.isSpeakerEnabled = isSpeakerEnabled
        self.currentRoute = isSpeakerEnabled ? .speaker : .receiver
    }

    public func startCall() async throws {
        isActive = true
    }

    public func endCall() async {
        isActive = false
    }

    public func setSpeakerEnabled(_ enabled: Bool) async throws {
        isSpeakerEnabled = enabled
        currentRoute = enabled ? .speaker : .receiver
    }

    public func setRoute(_ route: SpeakerRoute) async throws {
        currentRoute = route
        isSpeakerEnabled = (route == .speaker)
    }
}
