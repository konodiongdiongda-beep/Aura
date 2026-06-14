import Combine
import Foundation
import VoiceCore
import UIKit

@MainActor
final class VoiceCallViewModel: ObservableObject {
    static let defaultLocalResponsePreludes: [String] = []

    @Published private(set) var state: VoiceCallState
    @Published private(set) var elapsedSeconds: Int
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var activeUserPartialText: String
    @Published private(set) var activeAssistantText: String
    @Published private(set) var lastFilterResultText: String
    @Published private(set) var lastLatencyDebugText: String
    @Published private(set) var lastSpeechRecognitionEvent: SpeechRecognitionEvent?
    @Published var isMuted: Bool
    @Published var isSpeakerEnabled: Bool
    @Published private(set) var currentSpeakerRoute: SpeakerRoute = .speaker
    @Published private(set) var availableSpeakerRoutes: [SpeakerRoute] = [.speaker, .receiver]
    @Published private(set) var actualOutputDescription: String = "—"
    private(set) var audioLevel: Double = 0.0

    private let coordinator: VoiceCallCoordinator?
    private let historyStore: (any ConversationStoring)?
    private var cancellables: Set<AnyCancellable> = []
    private var lastPersistedSignature: String?
    private var levelUpdateTimer: Timer?

    convenience init() {
        self.init(coordinator: Self.makeDefaultCoordinator(), historyStore: LocalConversationStore())
    }

    convenience init(historyStore: any ConversationStoring) {
        self.init(coordinator: Self.makeDefaultCoordinator(), historyStore: historyStore)
    }

    init(coordinator: VoiceCallCoordinator, historyStore: (any ConversationStoring)? = nil) {
        self.coordinator = coordinator
        self.historyStore = historyStore
        self.state = coordinator.state
        self.elapsedSeconds = coordinator.elapsedSeconds
        self.messages = coordinator.messages
        self.activeUserPartialText = coordinator.activeUserPartialText
        self.activeAssistantText = coordinator.activeAssistantText
        self.lastFilterResultText = coordinator.lastFilterResultText
        self.lastLatencyDebugText = coordinator.lastLatencyDebugText
        self.lastSpeechRecognitionEvent = nil
        self.isMuted = false
        self.isSpeakerEnabled = coordinator.isSpeakerEnabled
        self.currentSpeakerRoute = coordinator.currentSpeakerRoute
        self.availableSpeakerRoutes = coordinator.availableSpeakerRoutes
        bindCoordinator(coordinator)
        setupLifecycleObservers()
        startLevelMonitoring()
    }

    init(
        state: VoiceCallState,
        elapsedSeconds: Int = 0,
        messages: [ChatMessage] = [],
        activeUserPartialText: String = "",
        activeAssistantText: String = "",
        lastFilterResultText: String = "verification unavailable",
        lastLatencyDebugText: String = "latency unavailable",
        isMuted: Bool = false,
        isSpeakerEnabled: Bool = true,
        historyStore: (any ConversationStoring)? = nil
    ) {
        self.coordinator = nil
        self.historyStore = historyStore
        self.state = state
        self.elapsedSeconds = elapsedSeconds
        self.messages = messages
        self.activeUserPartialText = activeUserPartialText
        self.activeAssistantText = activeAssistantText
        self.lastFilterResultText = lastFilterResultText
        self.lastLatencyDebugText = lastLatencyDebugText
        self.lastSpeechRecognitionEvent = nil
        self.isMuted = isMuted
        self.isSpeakerEnabled = isSpeakerEnabled
        startLevelMonitoring()
    }

    var statusTitle: String {
        localizedStatusTitle(.localized(.english))
    }

    var statusDetail: String {
        localizedStatusDetail(.localized(.english))
    }

    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var shouldShowCallScreen: Bool {
        if state.isActiveCall {
            return true
        }

        if case .error = state {
            return elapsedSeconds > 0 || !messages.isEmpty || !activeUserPartialText.isEmpty || !activeAssistantText.isEmpty
        }

        return false
    }

    func localizedStatusTitle(_ text: AppText) -> String {
        switch state {
        case .idle:
            return text.voiceIdleTitle
        case .requestingPermission:
            return text.checkingMicrophone
        case .listening:
            return isMuted ? text.microphoneMuted : text.auraListening
        case .recognizing:
            return text.capturingThought
        case .thinking:
            return text.auraThinking
        case .speaking:
            return text.auraSpeaking
        case .interrupted:
            return text.interruptionCaptured
        case .muted:
            return text.microphoneMuted
        case .ended:
            return text.callEnded
        case .error:
            return text.needsAttention
        }
    }

    func localizedStatusDetail(_ text: AppText) -> String {
        switch state {
        case .idle:
            return text.voiceIdleDetail
        case .requestingPermission:
            return text.microphoneAccessNotice
        case .listening:
            return text.speakNaturally
        case .recognizing(let partialText):
            return partialText
        case .thinking:
            if lastLatencyDebugText == "assistant response delayed" {
                return text.slowResponsePlaceholder
            }
            return text.streamingPlaceholder
        case .speaking:
            return text.interruptNotice
        case .interrupted:
            return text.staleAudioNotice
        case .muted:
            return text.unmuteNotice
        case .ended:
            return text.endedNotice
        case .error(let error):
            return error.localizedDescription
        }
    }

    static func preview(_ state: VoiceCallState) -> VoiceCallViewModel {
        switch state {
        case .idle:
            return VoiceCallViewModel(state: .idle)
        case .listening:
            return VoiceCallViewModel(
                state: .listening,
                elapsedSeconds: 42,
                messages: MockData.activeMessages
            )
        case .recognizing(let partialText):
            return VoiceCallViewModel(
                state: .recognizing(partialText: partialText),
                elapsedSeconds: 58,
                messages: MockData.activeMessages,
                activeUserPartialText: partialText
            )
        case .thinking:
            return VoiceCallViewModel(
                state: .thinking,
                elapsedSeconds: 73,
                messages: MockData.activeMessages,
                activeUserPartialText: "Can you summarize that as three steps?"
            )
        case .speaking:
            return VoiceCallViewModel(
                state: .speaking,
                elapsedSeconds: 92,
                messages: MockData.activeMessages,
                activeUserPartialText: "What is my next meeting?",
                activeAssistantText: "Your next meeting is at 2:00 PM with the design team."
            )
        case .interrupted:
            var messages = MockData.activeMessages
            messages.append(ChatMessage(
                id: "mock-interrupt",
                conversationID: MockData.conversationID,
                role: .user,
                displayText: "Actually, make that shorter.",
                voiceText: nil,
                createdAt: MockData.now,
                deliveryState: .draft
            ))
            return VoiceCallViewModel(
                state: .interrupted,
                elapsedSeconds: 108,
                messages: messages,
                activeUserPartialText: "Actually, make that shorter.",
                activeAssistantText: "Your next meeting is at 2:00 PM..."
            )
        case .error(let error):
            return VoiceCallViewModel(state: .error(error), messages: [])
        default:
            return VoiceCallViewModel(state: state, messages: MockData.activeMessages)
        }
    }

    func startCall() {
        guard let coordinator else {
            state = .listening
            elapsedSeconds = max(elapsedSeconds, 1)
            if messages.isEmpty {
                messages = [MockData.idleSystemMessage]
            }
            activeUserPartialText = ""
            activeAssistantText = ""
            lastFilterResultText = "verification unavailable"
            lastLatencyDebugText = "latency unavailable"
            persistCurrentConversation()
            return
        }

        Task {
            do {
                try await coordinator.startCall()
                sync(from: coordinator)
                persistCurrentConversation()
            } catch {
                sync(from: coordinator)
                persistCurrentConversation()
            }
        }
    }

    func endCall() {
        guard let coordinator else {
            state = .ended
            activeUserPartialText = ""
            activeAssistantText = ""
            lastFilterResultText = "verification unavailable"
            lastLatencyDebugText = "latency unavailable"
            persistCurrentConversation()
            return
        }

        Task {
            await coordinator.endCall()
            sync(from: coordinator)
            persistCurrentConversation()
        }
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            state = .muted(previous: VoiceCallStateSnapshot(stateName: statusTitle))
        } else {
            state = coordinator?.state ?? .listening
        }
    }

    func toggleSpeaker() {
        guard let coordinator else {
            isSpeakerEnabled.toggle()
            return
        }

        Task {
            await coordinator.toggleSpeaker()
            sync(from: coordinator)
        }
    }

    func setSpeakerRoute(_ route: SpeakerRoute) {
        guard let coordinator else { return }

        Task {
            await coordinator.setSpeakerRoute(route)
            sync(from: coordinator)
        }
    }

    func sendTextForDebug(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        guard let coordinator else {
            appendPreviewDebugTurn(cleanText)
            return
        }

        persistTypedUserText(cleanText, conversationID: coordinator.conversationContext?.cid)
        Task {
            await coordinator.simulateUserSpeech(cleanText)
            sync(from: coordinator)
        }
    }

    func simulateSpeechFinal(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        lastSpeechRecognitionEvent = .final(cleanText)
        activeUserPartialText = cleanText
        state = .recognizing(partialText: cleanText)
        sendTextForDebug(cleanText)
    }

    func simulateUserSpeechForDebug() async {
        await submitDebugSpeech("Can you summarize my day?")
    }

    func simulateAssistantSpeakingForDebug() async {
        guard let coordinator else {
            activeAssistantText = "I am speaking a simulated answer now."
            messages.append(ChatMessage(
                id: "mock-speaking-\(messages.count + 1)",
                conversationID: MockData.conversationID,
                role: .assistant,
                displayText: activeAssistantText,
                voiceText: activeAssistantText,
                createdAt: Date(),
                deliveryState: .streaming
            ))
            state = .speaking
            persistCurrentConversation()
            return
        }

        await coordinator.simulateAssistantSpeaking("I am speaking a simulated answer now. Tap interrupt to stop this response.")
        sync(from: coordinator)
        persistCurrentConversation()
    }

    func simulateUserInterruptionForDebug() async {
        guard let coordinator else {
            state = .interrupted
            appendPreviewDebugTurn("Actually, answer that more briefly.")
            return
        }

        await coordinator.simulateUserInterruption("Actually")
        sync(from: coordinator)
        try? await Task.sleep(nanoseconds: 250_000_000)
        await coordinator.simulateUserSpeech("Actually, answer that more briefly.")
        sync(from: coordinator)
    }

    func simulateEnvironmentNoiseForDebug() async {
        await evaluateDebugBargeIn(
            event: VoiceActivityEvent(
                inputLevel: 0.12,
                duration: 0.9,
                isAIPlaybackActive: state == .speaking,
                source: .environmentNoise
            ),
            speakerHint: .unknown,
            acceptedText: "Background noise near the phone"
        )
    }

    func simulateUserBargeInForDebug() async {
        await evaluateDebugBargeIn(
            event: VoiceActivityEvent(
                inputLevel: 0.78,
                duration: 0.75,
                isAIPlaybackActive: state == .speaking,
                source: .currentUser
            ),
            speakerHint: .currentUser,
            acceptedText: "Actually, let me interrupt."
        )
    }

    func simulateOtherSpeakerForDebug() async {
        await evaluateDebugBargeIn(
            event: VoiceActivityEvent(
                inputLevel: 0.76,
                duration: 0.85,
                isAIPlaybackActive: state == .speaking,
                source: .otherSpeaker
            ),
            speakerHint: .otherSpeaker,
            acceptedText: "Someone else is talking."
        )
    }

    func simulateAIEchoForDebug() async {
        await evaluateDebugBargeIn(
            event: VoiceActivityEvent(
                inputLevel: 0.84,
                duration: 1.0,
                isAIPlaybackActive: state == .speaking,
                source: .aiPlaybackEcho
            ),
            speakerHint: .unknown,
            acceptedText: activeAssistantText.isEmpty ? "AI playback echo" : activeAssistantText
        )
    }

    func simulateInsufficientVerificationForDebug() async {
        await evaluateDebugBargeIn(
            event: VoiceActivityEvent(
                inputLevel: 0.72,
                duration: 0.55,
                isAIPlaybackActive: state == .speaking,
                source: .currentUser
            ),
            speakerHint: .unknown,
            acceptedText: "Short interruption attempt.",
            verifier: MockSpeakerVerifier(result: .unavailableInsufficientAudio)
        )
    }

    @MainActor
    private static func makeDefaultCoordinator() -> VoiceCallCoordinator {
        let config = AppConfig.load()
        let services = config.makeVoiceCoreServices(useMocks: false)
        let speechServices = SpeechServiceFactory.make(appConfig: config)
        return VoiceCallCoordinator(
            chatClient: services.chatClient,
            recognizer: speechServices.recognizer,
            synthesizer: speechServices.synthesizer,
            // Whole-turn playback: this backend flushes all tokens at once, so we
            // synthesize the entire reply as ONE segment for natural prosody. A
            // very large maxSegmentLength keeps SentenceSegmenter from splitting
            // mid-reply; isFinal flush emits the full buffer.
            playback: TTSPlaybackQueue(synthesizer: speechServices.synthesizer, maxSegmentLength: 100_000, firstSegmentMinLength: 0),
            audioSession: speechServices.audioSession,
            conversationIDFactory: services.idFactory,
            submissionGate: speechServices.submissionGate,
            speakerEvidenceProvider: speechServices.speakerEvidenceProvider,
            localResponsePreludes: defaultLocalResponsePreludes
        )
    }

    private func bindCoordinator(_ coordinator: VoiceCallCoordinator) {
        coordinator.objectWillChange
            .sink { [weak self, weak coordinator] _ in
                DispatchQueue.main.async {
                    guard let self, let coordinator else { return }
                    self.sync(from: coordinator)
                }
            }
            .store(in: &cancellables)
    }

    private func sync(from coordinator: VoiceCallCoordinator) {
        state = coordinator.state
        elapsedSeconds = coordinator.elapsedSeconds
        messages = coordinator.messages
        activeUserPartialText = coordinator.activeUserPartialText
        activeAssistantText = coordinator.activeAssistantText
        lastFilterResultText = coordinator.lastFilterResultText
        lastLatencyDebugText = coordinator.lastLatencyDebugText
        isSpeakerEnabled = coordinator.isSpeakerEnabled
        currentSpeakerRoute = coordinator.currentSpeakerRoute
        availableSpeakerRoutes = coordinator.availableSpeakerRoutes
        actualOutputDescription = coordinator.actualOutputDescription
        persistCurrentConversation()
    }

    private func submitDebugSpeech(_ text: String) async {
        guard let coordinator else {
            appendPreviewDebugTurn(text)
            return
        }

        await coordinator.simulateUserSpeech(text)
        sync(from: coordinator)
    }

    private func appendPreviewDebugTurn(_ cleanText: String) {
        let userMessage = ChatMessage(
            id: "mock-user-\(messages.count + 1)",
            conversationID: MockData.conversationID,
            role: .user,
            displayText: cleanText,
            voiceText: nil,
            createdAt: Date(),
            deliveryState: .complete
        )
        let assistantText = "I heard: \(cleanText). This is a mocked simulator response for the native call UI."
        let assistantMessage = ChatMessage(
            id: "mock-assistant-\(messages.count + 2)",
            conversationID: MockData.conversationID,
            role: .assistant,
            displayText: assistantText,
            voiceText: assistantText,
            createdAt: Date(),
            deliveryState: .streaming
        )

        activeUserPartialText = cleanText
        activeAssistantText = assistantText
        messages.append(userMessage)
        messages.append(assistantMessage)
        state = .speaking
        persistCurrentConversation()
    }

    private func evaluateDebugBargeIn(
        event: VoiceActivityEvent,
        speakerHint: SpeakerHint,
        acceptedText: String,
        verifier: MockSpeakerVerifier = MockSpeakerVerifier()
    ) async {
        let gate = BargeInGate(
            voiceActivityDetector: LocalVoiceActivityDetector(),
            speakerVerifier: verifier
        )
        let decision = await gate.evaluate(event, speakerHint: speakerHint)

        switch decision {
        case .allowBargeIn:
            lastFilterResultText = "accepted"
            await simulateUserInterruptionForDebug()
        case .reject(let reason):
            lastFilterResultText = filterText(for: reason)
        case .needsSpeakerVerification:
            lastFilterResultText = "verification unavailable"
        }
    }

    private func filterText(for reason: BargeInRejectionReason) -> String {
        switch reason {
        case .notAISpeaking, .rejectedNoise:
            return "rejected noise"
        case .rejectedEcho:
            return "rejected echo"
        case .rejectedOtherSpeaker:
            return "rejected other speaker"
        case .verificationDisabled:
            return "verification unavailable"
        }
    }

    private func persistCurrentConversation() {
        guard let historyStore else { return }
        let persistableMessages = messages.filter { message in
            message.role != .system && !message.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !persistableMessages.isEmpty else { return }

        let conversationID = coordinator?.conversationContext?.cid ?? persistableMessages.first?.conversationID ?? MockData.conversationID
        let cidMD5 = coordinator?.conversationContext?.cidMD5 ?? MockData.cidMD5
        let signature = persistableMessages.map { "\($0.id):\($0.displayText):\($0.deliveryState)" }.joined(separator: "|")
        guard signature != lastPersistedSignature else { return }

        do {
            try historyStore.upsertConversation(
                id: conversationID,
                cidMD5: cidMD5,
                messages: persistableMessages,
                elapsedSeconds: elapsedSeconds
            )
            lastPersistedSignature = signature
        } catch {
            #if DEBUG
            print("Unable to persist local conversation: \(error.localizedDescription)")
            #endif
        }
    }

    private func persistTypedUserText(_ text: String, conversationID: String?) {
        guard let historyStore else { return }
        let id = conversationID ?? "typed-\(Int(Date().timeIntervalSince1970))"
        let message = ChatMessage(
            id: "typed-user-\(Int(Date().timeIntervalSince1970 * 1000))",
            conversationID: id,
            role: .user,
            displayText: text,
            voiceText: nil,
            createdAt: Date(),
            deliveryState: .complete
        )

        do {
            let existingMessages = try historyStore.loadMessages(conversationID: id)
            try historyStore.upsertConversation(
                id: id,
                cidMD5: coordinator?.conversationContext?.cidMD5 ?? id,
                messages: existingMessages + [message],
                elapsedSeconds: elapsedSeconds
            )
        } catch {
            #if DEBUG
            print("Unable to persist typed text: \(error.localizedDescription)")
            #endif
        }
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleEnterBackground() }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleWillEnterForeground() }
        }
    }

    private func handleEnterBackground() async {
        guard let coordinator else { return }
        guard state.isActiveCall else { return }
        await coordinator.pauseRecognition()
    }

    private func handleWillEnterForeground() async {
        guard let coordinator else { return }
        guard state.isActiveCall else { return }
        do {
            try await coordinator.resumeRecognition()
        } catch {
            print("[VoiceCallViewModel] Failed to resume recognition: \(error.localizedDescription)")
        }
    }

    deinit {
        levelUpdateTimer?.invalidate()
    }

    private func startLevelMonitoring() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let target = self.targetAudioLevel()
            // Exponential smoothing: rise quickly, fall a touch slower so the
            // bars track real audio without flickering, and settle to 0 when silent.
            let smoothing = target > self.audioLevel ? 0.55 : 0.25
            var next = self.audioLevel + (target - self.audioLevel) * smoothing
            if next < 0.015 { next = 0.0 }
            self.audioLevel = next
        }
    }

    private func targetAudioLevel() -> Double {
        guard state.isActiveCall else { return 0.0 }

        let liveLevel = AudioLevelMonitor.shared.currentLevel
        if liveLevel > 0.0 {
            // Apply a gentle gain so normal-volume speech reaches a visible range.
            return min(1.0, liveLevel * 1.8)
        }

        // No live level available (e.g. during TTS playback): keep the bars flat
        // unless we are actively speaking, where a soft idle motion reads better.
        if state == .speaking {
            return 0.28 + 0.18 * (0.5 + 0.5 * sin(Date().timeIntervalSince1970 * 6.0))
        }

        return 0.0
    }

    private func stopLevelMonitoring() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        audioLevel = 0.0
    }
}
