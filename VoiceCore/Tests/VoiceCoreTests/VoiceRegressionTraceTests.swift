import XCTest
@testable import VoiceCore

@MainActor
final class VoiceRegressionTraceTests: XCTestCase {
    func testAssistantTailEchoTraceRejectsEchoSubmission() async throws {
        try await runTraceFixture(named: "assistant_tail_echo")
    }

    func testShortAnswerTraceAcceptsRealUserSpeech() async throws {
        try await runTraceFixture(named: "short_answer_after_prompt")
    }

    private func runTraceFixture(named name: String) async throws {
        let trace = try loadTraceFixture(named: name)
        let clock = TraceClock()
        let chatClient = TraceChatClient()
        let harness = TraceCoordinatorHarness(
            chatClient: chatClient,
            dateProvider: { clock.now }
        )
        try await harness.coordinator.startCall()

        for step in trace.steps {
            try await run(step, harness: harness, chatClient: chatClient, clock: clock)
        }

        try await assertExpectations(trace.expect, harness: harness, chatClient: chatClient)
    }

    private func run(
        _ step: VoiceRegressionTrace.Step,
        harness: TraceCoordinatorHarness,
        chatClient: TraceChatClient,
        clock: TraceClock
    ) async throws {
        switch step.type {
        case "user_final":
            await harness.recognizer.emitFinal(try step.requiredText)
        case "user_partial":
            await harness.recognizer.emitPartial(try step.requiredText)
        case "assistant_final":
            let displayText = try step.requiredDisplayText
            chatClient.yield(.final(
                displayText: displayText,
                voiceText: step.voiceText ?? displayText,
                intent: "trace"
            ))
        case "assistant_token":
            chatClient.yield(.assistantToken(try step.requiredText))
        case "assistant_completed":
            chatClient.yield(.completed)
        case "wait_state":
            try await harness.coordinator.waitForTraceState(step.requiredState)
        case "advance_time":
            clock.advance(by: step.seconds ?? 0)
        case "settle":
            let nanoseconds = UInt64((step.milliseconds ?? 50) * 1_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
        default:
            XCTFail("Unsupported trace step type: \(step.type)")
        }
    }

    private func assertExpectations(
        _ expect: VoiceRegressionTrace.Expectation,
        harness: TraceCoordinatorHarness,
        chatClient: TraceChatClient
    ) async throws {
        if let submittedTexts = expect.submittedTexts {
            XCTAssertEqual(chatClient.sentMessages, submittedTexts)
        }
        if let userMessages = expect.userMessages {
            XCTAssertEqual(
                harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
                userMessages
            )
        }
        if let lastFilter = expect.lastFilter {
            XCTAssertEqual(harness.coordinator.lastFilterResultText, lastFilter)
        }
        if let finalState = expect.finalState {
            try await harness.coordinator.waitForTraceState(finalState)
        }
    }

    private func loadTraceFixture(named name: String) throws -> VoiceRegressionTrace {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "trace.json"
        ) else {
            XCTFail("Missing trace fixture \(name)")
            throw TraceError.missingFixture(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VoiceRegressionTrace.self, from: data)
    }
}

private struct VoiceRegressionTrace: Decodable {
    var schemaVersion: Int
    var id: String
    var description: String
    var runtime: Runtime
    var steps: [Step]
    var expect: Expectation

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case description
        case runtime
        case steps
        case expect
    }

    struct Runtime: Decodable {
        var target: String
        var route: String
        var aec: String
        var simulatorNote: String?

        enum CodingKeys: String, CodingKey {
            case target
            case route
            case aec
            case simulatorNote = "simulator_note"
        }
    }

    struct Step: Decodable {
        var type: String
        var text: String?
        var displayText: String?
        var voiceText: String?
        var state: String?
        var seconds: TimeInterval?
        var milliseconds: UInt64?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case displayText = "display_text"
            case voiceText = "voice_text"
            case state
            case seconds
            case milliseconds
        }

        var requiredText: String {
            get throws {
                guard let text else { throw TraceError.missingField("text", type) }
                return text
            }
        }

        var requiredDisplayText: String {
            get throws {
                guard let displayText else { throw TraceError.missingField("display_text", type) }
                return displayText
            }
        }

        var requiredState: VoiceCallState {
            get throws {
                guard let state else { throw TraceError.missingField("state", type) }
                return try VoiceCallState.traceState(named: state)
            }
        }
    }

    struct Expectation: Decodable {
        var submittedTexts: [String]?
        var userMessages: [String]?
        var lastFilter: String?
        var finalState: VoiceCallState?

        enum CodingKeys: String, CodingKey {
            case submittedTexts = "submitted_texts"
            case userMessages = "user_messages"
            case lastFilter = "last_filter"
            case finalState = "final_state"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            submittedTexts = try container.decodeIfPresent([String].self, forKey: .submittedTexts)
            userMessages = try container.decodeIfPresent([String].self, forKey: .userMessages)
            lastFilter = try container.decodeIfPresent(String.self, forKey: .lastFilter)
            if let finalStateName = try container.decodeIfPresent(String.self, forKey: .finalState) {
                finalState = try VoiceCallState.traceState(named: finalStateName)
            } else {
                finalState = nil
            }
        }
    }
}

private enum TraceError: Error, CustomStringConvertible {
    case missingFixture(String)
    case missingField(String, String)
    case unsupportedState(String)

    var description: String {
        switch self {
        case .missingFixture(let name):
            return "Missing trace fixture \(name)"
        case .missingField(let field, let step):
            return "Missing \(field) for trace step \(step)"
        case .unsupportedState(let state):
            return "Unsupported trace state \(state)"
        }
    }
}

private final class TraceClock {
    private(set) var now: Date = Date(timeIntervalSince1970: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

@MainActor
private final class TraceCoordinatorHarness {
    let recognizer: TraceSpeechRecognizer
    let playback: TracePlaybackController
    let audio: TraceAudioSessionManager
    let chatClient: TraceChatClient
    let coordinator: VoiceCallCoordinator

    init(
        chatClient: TraceChatClient = TraceChatClient(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.recognizer = TraceSpeechRecognizer()
        self.playback = TracePlaybackController()
        self.audio = TraceAudioSessionManager()
        self.chatClient = chatClient
        self.coordinator = VoiceCallCoordinator(
            chatClient: chatClient,
            recognizer: recognizer,
            synthesizer: TraceSpeechSynthesizer(),
            playback: playback,
            audioSession: audio,
            conversationIDFactory: TraceConversationIDFactory(),
            dateProvider: dateProvider,
            fastPartialSubmitDelayNanoseconds: 40_000_000,
            interruptedPartialSubmitDelayNanoseconds: 40_000_000,
            assistantResponseStartTimeoutNanoseconds: 500_000_000,
            assistantResponseHardTimeoutNanoseconds: 1_500_000_000
        )
    }
}

private final class TraceChatClient: ChatClient {
    private(set) var sentMessages: [String] = []
    private var streams: [TraceChatStream] = []

    func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        sentMessages.append(text)
        let stream = TraceChatStream()
        streams.append(stream)
        return stream.stream
    }

    func yield(_ update: ChatStreamUpdate) {
        streams.last?.yield(update)
    }
}

private final class TraceChatStream {
    let stream: AsyncThrowingStream<ChatStreamUpdate, Error>
    private let continuation: AsyncThrowingStream<ChatStreamUpdate, Error>.Continuation

    init() {
        var capturedContinuation: AsyncThrowingStream<ChatStreamUpdate, Error>.Continuation?
        self.stream = AsyncThrowingStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation!
    }

    func yield(_ update: ChatStreamUpdate) {
        continuation.yield(update)
    }
}

private actor TraceSpeechRecognizer: SpeechRecognizing {
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    private var isRunning = false

    func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func start() async throws {
        isRunning = true
    }

    func stop() async {
        isRunning = false
    }

    func cancel() async {
        isRunning = false
    }

    func emitPartial(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.partial(text))
    }

    func emitFinal(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.final(text))
    }
}

private actor TraceSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String) async throws {}
    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        SpeechSynthesisOutput(audioData: Data(), text: text)
    }
    func cancel() async {}
}

private actor TracePlaybackController: SpeechPlaybackControlling {
    private var playbackContinuations: [AsyncStream<SpeechPlaybackEvent>.Continuation] = []

    func playbackEvents() async -> AsyncStream<SpeechPlaybackEvent> {
        AsyncStream { continuation in
            self.playbackContinuations.append(continuation)
        }
    }

    func enqueue(_ text: String, isFinal: Bool) async {
        if !text.isEmpty {
            emit(.started(text))
            emit(.finished(text))
        }
        if isFinal {
            emit(.drained)
        }
    }

    func clear() async {}

    func cancel() async {
        emit(.cancelled)
    }

    private func emit(_ event: SpeechPlaybackEvent) {
        playbackContinuations.forEach { $0.yield(event) }
    }
}

private actor TraceAudioSessionManager: AudioSessionManaging {
    var isSpeakerEnabled = true
    var currentRoute: SpeakerRoute = .speaker
    var availableRoutes: [SpeakerRoute] = [.speaker, .receiver]
    var actualOutputDescription: String { currentRoute.displayName }

    func startCall() async throws {}
    func endCall() async {}
    func setSpeakerEnabled(_ enabled: Bool) async throws {
        isSpeakerEnabled = enabled
        currentRoute = enabled ? .speaker : .receiver
    }
    func setRoute(_ route: SpeakerRoute) async throws {
        currentRoute = route
        isSpeakerEnabled = (route == .speaker)
    }
}

private struct TraceConversationIDFactory: ConversationIDProviding {
    func makeConversationContext() -> ConversationContext {
        ConversationContext(cid: "trace-conversation", cidMD5: "trace-md5", userName: "trace-user", userID: 1)
    }
}

private extension VoiceCallState {
    static func traceState(named name: String) throws -> VoiceCallState {
        switch name {
        case "idle": return .idle
        case "requestingPermission": return .requestingPermission
        case "listening": return .listening
        case "thinking": return .thinking
        case "speaking": return .speaking
        case "interrupted": return .interrupted
        case "ended": return .ended
        default: throw TraceError.unsupportedState(name)
        }
    }
}

private extension VoiceCallCoordinator {
    func waitForTraceState(_ expectedState: VoiceCallState, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while state != expectedState {
            if Date() > deadline {
                XCTFail("Timed out waiting for \(expectedState); got \(state)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
