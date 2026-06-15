import Combine
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.aura.voicecore", category: "VoiceCallCoordinator")

@MainActor
public final class VoiceCallCoordinator: ObservableObject {
    @Published public private(set) var state: VoiceCallState
    @Published public private(set) var elapsedSeconds: Int
    @Published public private(set) var messages: [ChatMessage]
    @Published public private(set) var activeUserPartialText: String
    @Published public private(set) var activeAssistantText: String
    @Published public private(set) var isSpeakerEnabled: Bool
    @Published public private(set) var currentSpeakerRoute: SpeakerRoute = .speaker
    @Published public private(set) var availableSpeakerRoutes: [SpeakerRoute] = []
    @Published public private(set) var actualOutputDescription: String = "—"
    @Published public private(set) var lastFilterResultText: String
    @Published public private(set) var lastLatencyDebugText: String

    public private(set) var conversationContext: ConversationContext?

    private let chatClient: any ChatClient
    private let recognizer: any SpeechRecognizing
    private let synthesizer: any SpeechSynthesizing
    private let playback: any SpeechPlaybackControlling
    private let audioSession: any AudioSessionManaging
    private let conversationIDFactory: any ConversationIDProviding
    private let bargeInGate: BargeInGate
    private let submissionGate: any UserTurnSubmissionGating
    private let speakerEvidenceProvider: any UserTurnSpeakerEvidenceProviding
    private let echoDetector: SpeechEchoDetector
    private let playbackEchoDetector = SpeechEchoDetector(similarityThreshold: 0.70, minimumEchoCharacterCount: 4)
    private let dateProvider: () -> Date
    private let fastPartialSubmitDelayNanoseconds: UInt64
    private let interruptedPartialSubmitDelayNanoseconds: UInt64
    private let audioOnlyInterruptionTimeoutNanoseconds: UInt64
    private let leadInHoldNanoseconds: UInt64
    private let assistantResponseStartTimeoutNanoseconds: UInt64
    private let assistantResponseHardTimeoutNanoseconds: UInt64
    private let localResponsePreludes: [String]
    private let assistantEchoMemoryWindow: TimeInterval = 12
    private let assistantTailEchoMemoryWindow: TimeInterval = 120
    private let currentUserBargeInInputLevel = 0.08
    private let currentUserBargeInDuration: TimeInterval = 0.10
    private let playbackSpeakerCheckDuration: TimeInterval = 0.12
    private let minimumStablePartialCharacterCount = 4
    private let backgroundRejectionMemoryWindow: TimeInterval = 1.2
    // Barge-in during playback triggers on sustained microphone ENERGY rather
    // than voiceprint. On-device measurement showed residual AI echo (the AEC
    // can't fully cancel it) drags the user's live voiceprint score into the same
    // range as pure echo (~0.13–0.33), so voiceprint cannot reliably decide "is
    // this the user" mid-playback. Instead we stop the assistant on sustained
    // energy above this raised threshold — the user's louder, closer voice trips
    // it while low-level residual echo doesn't — and leave the "keep the
    // sentence?" decision to the voiceprint-backed submission gate, which runs on
    // the clean (post-interrupt, non-playback) audio. Tune from the on-device
    // [VCC-BARGE] level logs.
    private let playbackBargeInInputLevel: Double = 0.10
    // Second barge-in dimension (LiveKit-style onset detection, local heuristic).
    // A sharp energy jump at speech onset signals a near-field user speaking up,
    // even at moderate volume — so we allow barge-in at a LOWER energy floor when
    // the onset is steep. Diffuse far-field chatter ramps in slowly and won't
    // clear onsetRate, so this loosens responsiveness WITHOUT loosening the bar
    // for background voices. Tune from the on-device [VCC-BARGE] onset= logs.
    private let playbackBargeInOnsetFloorLevel: Double = 0.07
    private let playbackBargeInOnsetRate: Double = 0.05
    // Near-field submit gate (listening state). Set LOW to ensure user's real speech
    // is never dropped. Lowered from 0.04 to 0.015 to fix "Capturing stuck" issue
    // where quiet speech wasn't reaching the threshold. Can be tuned higher later
    // once [VCC-SUBMIT] rms= logs show the actual range of user speech.
    private let nearFieldSubmissionLevel: Double = 0.015

    private var recognitionTask: Task<Void, Never>?
    private var recognizerResetTask: Task<Void, Never>?
    private var playbackEventsTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var partialAutoSubmitTask: Task<Void, Never>?
    private var audioOnlyInterruptionRecoveryTask: Task<Void, Never>?
    private var leadInClearTask: Task<Void, Never>?
    private var assistantResponseStartWatchdogTask: Task<Void, Never>?
    private var assistantResponseHardTimeoutTask: Task<Void, Never>?
    private var currentTurnID: UUID?
    private var activeUserChatID: String?
    private var activeBotChatID: String?
    private var currentUserMessageID: String?
    private var currentUserText = ""
    private var pendingLeadInText = ""
    private var pendingUserContinuationMessageID: String?
    private var currentAssistantMessageID: String?
    private var currentAssistantVoiceText = ""
    private var recentAssistantSpeechTexts: [String] = []
    private var recentAssistantSpeechUpdatedAt: Date?
    private var recentAssistantTailEchoCandidates: [TimedAssistantEchoCandidate] = []
    private var interruptedAssistantEchoText = ""
    private var currentTurnSubmittedAt: Date?
    private var didRecordAssistantResponseStart = false
    private var didObserveBargeIn = false
    private var isCapturingInterruptedInput = false
    private var isAssistantPlaybackActive = false
    private var isAssistantStreamComplete = false
    private var recentBackgroundRejection: RecentBackgroundRejection?
    private var messageSequence = 0
    private var callStartDate: Date?
    private var timerTask: Task<Void, Never>?

    private struct RecentBackgroundRejection {
        var reason: UserTurnSubmissionRejectionReason
        var filterText: String
        var updatedAt: Date
    }

    private struct TimedAssistantEchoCandidate {
        var text: String
        var updatedAt: Date
    }

    public init(
        chatClient: any ChatClient,
        recognizer: any SpeechRecognizing,
        synthesizer: any SpeechSynthesizing,
        playback: any SpeechPlaybackControlling,
        audioSession: any AudioSessionManaging,
        conversationIDFactory: any ConversationIDProviding,
        bargeInGate: BargeInGate = BargeInGate(),
        submissionGate: any UserTurnSubmissionGating = AcceptingUserTurnSubmissionGate(),
        speakerEvidenceProvider: any UserTurnSpeakerEvidenceProviding = NoopUserTurnSpeakerEvidenceProvider(),
        echoDetector: SpeechEchoDetector = SpeechEchoDetector(similarityThreshold: 0.85, minimumEchoCharacterCount: 6),
        dateProvider: @escaping () -> Date = Date.init,
        fastPartialSubmitDelayNanoseconds: UInt64 = 120_000_000,
        interruptedPartialSubmitDelayNanoseconds: UInt64 = 700_000_000,
        audioOnlyInterruptionTimeoutNanoseconds: UInt64 = 900_000_000,
        leadInHoldNanoseconds: UInt64 = 1_500_000_000,
        assistantResponseStartTimeoutNanoseconds: UInt64 = 3_000_000_000,
        // Backend first-token latency measured at ~28-30s (LLM buffers the full
        // turn then flushes all tokens in <1s). The hard timeout must clear that
        // with margin or live turns get killed before the answer ever arrives.
        assistantResponseHardTimeoutNanoseconds: UInt64 = 60_000_000_000,
        localResponsePreludes: [String] = [],
        state: VoiceCallState = .idle,
        elapsedSeconds: Int = 0,
        messages: [ChatMessage] = [],
        activeUserPartialText: String = "",
        activeAssistantText: String = "",
        isSpeakerEnabled: Bool = true,
        lastFilterResultText: String = "verification unavailable",
        lastLatencyDebugText: String = "latency unavailable"
    ) {
        self.chatClient = chatClient
        self.recognizer = recognizer
        self.synthesizer = synthesizer
        self.playback = playback
        self.audioSession = audioSession
        self.conversationIDFactory = conversationIDFactory
        self.bargeInGate = bargeInGate
        self.submissionGate = submissionGate
        self.speakerEvidenceProvider = speakerEvidenceProvider
        self.echoDetector = echoDetector
        self.dateProvider = dateProvider
        self.fastPartialSubmitDelayNanoseconds = fastPartialSubmitDelayNanoseconds
        self.interruptedPartialSubmitDelayNanoseconds = interruptedPartialSubmitDelayNanoseconds
        self.audioOnlyInterruptionTimeoutNanoseconds = audioOnlyInterruptionTimeoutNanoseconds
        self.leadInHoldNanoseconds = leadInHoldNanoseconds
        self.assistantResponseStartTimeoutNanoseconds = assistantResponseStartTimeoutNanoseconds
        self.assistantResponseHardTimeoutNanoseconds = assistantResponseHardTimeoutNanoseconds
        self.localResponsePreludes = localResponsePreludes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.state = state
        self.elapsedSeconds = elapsedSeconds
        self.messages = messages
        self.activeUserPartialText = activeUserPartialText
        self.activeAssistantText = activeAssistantText
        self.isSpeakerEnabled = isSpeakerEnabled
        self.lastFilterResultText = lastFilterResultText
        self.lastLatencyDebugText = lastLatencyDebugText
    }

    deinit {
        recognitionTask?.cancel()
        recognizerResetTask?.cancel()
        playbackEventsTask?.cancel()
        chatTask?.cancel()
        partialAutoSubmitTask?.cancel()
        audioOnlyInterruptionRecoveryTask?.cancel()
        leadInClearTask?.cancel()
        assistantResponseStartWatchdogTask?.cancel()
        assistantResponseHardTimeoutTask?.cancel()
        timerTask?.cancel()
    }

    public func startCall() async throws {
        state = .requestingPermission
        do {
            try await audioSession.startCall()
            isSpeakerEnabled = await audioSession.isSpeakerEnabled
            currentSpeakerRoute = await audioSession.currentRoute
            availableSpeakerRoutes = await audioSession.availableRoutes
            print("[VoiceCallCoordinator] startCall routes: \(availableSpeakerRoutes.map { $0.displayName })")
            conversationContext = conversationIDFactory.makeConversationContext()
            activeUserPartialText = ""
            activeAssistantText = ""
            currentAssistantVoiceText = ""
            recentAssistantSpeechTexts = []
            recentAssistantSpeechUpdatedAt = nil
            recentAssistantTailEchoCandidates = []
            interruptedAssistantEchoText = ""
            currentTurnSubmittedAt = nil
            didRecordAssistantResponseStart = false
            pendingLeadInText = ""
            lastFilterResultText = "verification unavailable"
            lastLatencyDebugText = "latency unavailable"
            didObserveBargeIn = false
            isCapturingInterruptedInput = false
            audioOnlyInterruptionRecoveryTask?.cancel()
            audioOnlyInterruptionRecoveryTask = nil
            leadInClearTask?.cancel()
            leadInClearTask = nil
            let recognitionEvents = await recognizer.events()
            startRecognitionEvents(recognitionEvents)
            let playbackEvents = await playback.playbackEvents()
            startPlaybackEvents(playbackEvents)
            try await recognizer.start()
            // The recognizer starts AVAudioEngine with voice processing (VPIO),
            // which resets the output route to the receiver. Re-apply the desired
            // route AFTER the engine is running so playback uses the speaker
            // (or the user's chosen route) instead of the quiet earpiece.
            try? await audioSession.setRoute(currentSpeakerRoute)
            isSpeakerEnabled = await audioSession.isSpeakerEnabled
            currentSpeakerRoute = await audioSession.currentRoute
            actualOutputDescription = await audioSession.actualOutputDescription
            startTimer()
            state = .listening
        } catch let appError as AppError {
            state = .error(appError)
            throw appError
        } catch {
            let wrapped = AppError.unknown(error.localizedDescription)
            state = .error(wrapped)
            throw wrapped
        }
    }

    public func endCall() async {
        invalidateActiveTurn()
        partialAutoSubmitTask?.cancel()
        partialAutoSubmitTask = nil
        audioOnlyInterruptionRecoveryTask?.cancel()
        audioOnlyInterruptionRecoveryTask = nil
        leadInClearTask?.cancel()
        leadInClearTask = nil
        assistantResponseStartWatchdogTask?.cancel()
        assistantResponseStartWatchdogTask = nil
        assistantResponseHardTimeoutTask?.cancel()
        assistantResponseHardTimeoutTask = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognizerResetTask?.cancel()
        recognizerResetTask = nil
        playbackEventsTask?.cancel()
        playbackEventsTask = nil
        timerTask?.cancel()
        timerTask = nil
        await recognizer.stop()
        await playback.cancel()
        await playback.clear()
        await audioSession.endCall()
        activeUserPartialText = ""
        activeAssistantText = ""
        currentAssistantVoiceText = ""
        recentAssistantSpeechTexts = []
        recentAssistantSpeechUpdatedAt = nil
        recentAssistantTailEchoCandidates = []
        interruptedAssistantEchoText = ""
        currentTurnSubmittedAt = nil
        didRecordAssistantResponseStart = false
        pendingLeadInText = ""
        isCapturingInterruptedInput = false
        isAssistantPlaybackActive = false
        isAssistantStreamComplete = false
        lastFilterResultText = "verification unavailable"
        lastLatencyDebugText = "latency unavailable"
        state = .ended
    }

    public func setSpeakerEnabled(_ enabled: Bool) async {
        do {
            try await audioSession.setSpeakerEnabled(enabled)
            isSpeakerEnabled = enabled
            currentSpeakerRoute = await audioSession.currentRoute
            actualOutputDescription = await audioSession.actualOutputDescription
        } catch {
            state = .error(.unknown(error.localizedDescription))
        }
    }

    public func toggleSpeaker() async {
        await setSpeakerEnabled(!isSpeakerEnabled)
    }

    public func setSpeakerRoute(_ route: SpeakerRoute) async {
        do {
            try await audioSession.setRoute(route)
            isSpeakerEnabled = await audioSession.isSpeakerEnabled
            currentSpeakerRoute = await audioSession.currentRoute
            actualOutputDescription = await audioSession.actualOutputDescription
        } catch {
            state = .error(.unknown(error.localizedDescription))
        }
    }

    public func simulateUserSpeech(_ text: String) async {
        await handleRecognitionEvent(.final(text))
    }

    public func simulateAssistantSpeaking(_ text: String = "Aura is speaking now.") async {
        guard let conversation = ensureConversationContext() else { return }
        invalidateActiveTurn()
        let turnID = UUID()
        currentTurnID = turnID
        activeBotChatID = "simulated-bot-\(messageSequence + 1)"
        currentAssistantMessageID = activeBotChatID
        activeAssistantText = text
        currentAssistantVoiceText = text
        rememberAssistantSpeech(text)
        appendOrUpdateAssistantMessage(
            id: activeBotChatID ?? "simulated-bot",
            conversationID: conversation.cid,
            displayText: text,
            voiceText: text,
            deliveryState: .streaming
        )
        state = .speaking
        await playback.enqueue(text, isFinal: false)
    }

    public func simulateUserInterruption(_ partialText: String = "等等") async {
        await handleRecognitionEvent(.partial(partialText))
    }

    /// Manually interrupt the assistant in response to a user tap. Stops audible
    /// playback and any pending/streaming response, then reopens the floor for
    /// the user to speak. Unlike voice barge-in this needs no ASR partial or
    /// speaker verification, so it always works even when the microphone path is
    /// unreliable (e.g. the simulator).
    public func interruptAssistant() async {
        guard state == .speaking || state == .thinking || isAssistantPlaybackActive else { return }
        captureInterruptedAssistantEchoText()
        markCurrentAssistantInterrupted()
        invalidateActiveTurn()
        didObserveBargeIn = true
        isCapturingInterruptedInput = true
        isAssistantStreamComplete = false
        isAssistantPlaybackActive = false
        activeUserPartialText = ""
        activeAssistantText = ""
        currentAssistantVoiceText = ""
        currentTurnSubmittedAt = nil
        didRecordAssistantResponseStart = false
        activeUserChatID = nil
        activeBotChatID = nil
        currentAssistantMessageID = nil
        pendingUserContinuationMessageID = nil
        lastFilterResultText = "accepted"
        // Mirror voice barge-in: land on .interrupted rather than .listening so a
        // stale playback `.started` event cannot re-promote us to .speaking. The
        // recovery task drops back to .listening if the user stays silent.
        state = .interrupted
        scheduleAudioOnlyInterruptionRecovery()
        await recognizer.notifyPlaybackStateChanged(false)
        await playback.cancel()
        await playback.clear()
    }

    public func simulateVoiceActivity(
        _ event: VoiceActivityEvent,
        speakerHint: SpeakerHint = .unknown,
        text: String
    ) async {
        await evaluateBargeIn(event: event, speakerHint: speakerHint, text: text, submitOnAllow: true)
    }

    public func pauseRecognition() async {
        await recognizer.pauseRecognition()
    }

    public func resumeRecognition() async throws {
        try await recognizer.resumeRecognition()
    }

    private func startRecognitionEvents(_ stream: AsyncThrowingStream<SpeechRecognitionEvent, Error>) {
        recognitionTask?.cancel()
        recognitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in stream {
                    await self.handleRecognitionEvent(event)
                }
            } catch is CancellationError {
                return
            } catch let appError as AppError {
                await MainActor.run {
                    self.state = .error(appError)
                }
            } catch {
                await MainActor.run {
                    self.state = .error(.speechRecognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    private func startPlaybackEvents(_ stream: AsyncStream<SpeechPlaybackEvent>) {
        playbackEventsTask?.cancel()
        playbackEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in stream {
                await MainActor.run {
                    self.handlePlaybackEvent(event)
                }
            }
        }
    }

    private func handlePlaybackEvent(_ event: SpeechPlaybackEvent) {
        switch event {
        case .started(let text):
            isAssistantPlaybackActive = true
            Task { [recognizer] in await recognizer.notifyPlaybackStateChanged(true) }
            if shouldPromotePlaybackStartedToSpeaking(text) {
                state = .speaking
            }
        case .finished:
            break
        case .cancelled:
            isAssistantPlaybackActive = false
            Task { [recognizer] in await recognizer.notifyPlaybackStateChanged(false) }
        case .drained:
            isAssistantPlaybackActive = false
            Task { [recognizer] in await recognizer.notifyPlaybackStateChanged(false) }
            completeAssistantPlaybackIfReady()
        }
    }

    private func handleRecognitionEvent(_ event: SpeechRecognitionEvent) async {
        switch event {
        case .voiceActivity(let activity):
            await handleVoiceActivity(activity)
        case .partial(let text):
            guard let cleanText = userSpeechTextForCurrentInput(text) else {
                return
            }
            guard !rejectAsRecentBackgroundActivityIfNeeded() else {
                return
            }
            if state == .speaking {
                // Voiceprint-gated barge-in (方案四): a raw recognized partial
                // NEVER interrupts the assistant on its own, because a partial
                // carries no audio evidence and therefore cannot be verified as
                // the primary speaker. Interruption is decided solely by the
                // VAD + voiceprint path (evaluatePlaybackBargeInActivity) or by a
                // verified final. This stops a bystander / TV / our own echo from
                // cutting off the AI. We also do not display the partial yet:
                // until the speaker is confirmed we don't know it's the user.
                lastFilterResultText = "waiting voiceprint"
                return
            }
            guard shouldAcceptPartialForDisplay(cleanText, state: state) else {
                lastFilterResultText = "waiting final"
                return
            }
            cancelAudioOnlyInterruptionRecovery()
            if state == .thinking {
                // A partial during thinking is either ASR still settling the
                // utterance we just fast-submitted (a refinement of the same
                // turn) or genuinely new speech. Only new speech should
                // interrupt the pending response; a refinement just corrects
                // the existing user bubble, mirroring the .thinking final path.
                if !applyCurrentTurnCorrectionIfNeeded(for: cleanText, allowsInterruptedInput: false) {
                    startPendingResponseInterruption(partialText: cleanText)
                }
            } else if state == .listening || state == .interrupted || state == .recognizing(partialText: activeUserPartialText) {
                // Mirror the web coordinator's onPartial: a partial only refreshes
                // the live display for the open turn. We do NOT auto-submit it.
                // Submission happens once, on the ASR final, so a single utterance
                // becomes ONE user bubble instead of being chopped into
                // ABC -> ABCDEF -> ABCDEFG fragments by fast partial submits.
                let partialText = partialTextForCurrentRecognition(cleanText)
                activeUserPartialText = partialText
                if let pendingUserContinuationMessageID {
                    updateUserMessage(id: pendingUserContinuationMessageID, displayText: partialText)
                }
                state = .recognizing(partialText: partialText)
            }
        case .final(let text):
            guard !rejectAsRecentBackgroundActivityIfNeeded() else { return }
            handleFinalRecognition(text, speakerEvidence: nil)
        case .finalWithEvidence(let text, let speakerEvidence):
            handleFinalRecognition(text, speakerEvidence: speakerEvidence)
        case .finalWithAudioEvidence(let text, let audioEvidence):
            guard passesNearFieldSubmissionGate(audioEvidence) else { return }
            let request = speakerEvidenceRequest(for: audioEvidence)
            let speakerEvidence = await speakerEvidenceProvider.evidence(for: request)
            handleFinalRecognition(text, speakerEvidence: speakerEvidence)
        }
    }

    /// Near-field energy gate for the SUBMIT path (not barge-in). The recognizer
    /// transcribes everything it hears — including background chatter / TV — and
    /// with voiceprint removed the only thing standing between "recognized words"
    /// and "sent to the AI" is this. The user speaking into the phone is loud
    /// (near-field); far-field background is quiet, so a low RMS turn is dropped
    /// even though it produced text. Skipped while the assistant is speaking /
    /// during an interruption, where the barge-in path already governs capture.
    /// Tune from the on-device [VCC-SUBMIT] rms= logs.
    private func passesNearFieldSubmissionGate(_ audioEvidence: SpeechAudioEvidence) -> Bool {
        let playbackActive = state == .speaking || isAssistantPlaybackActive
        let interruptedInput = isCapturingInterruptedInput || didObserveBargeIn
        guard !playbackActive, !interruptedInput else { return true }
        let rms = audioEvidence.rmsLevel
        if rms < nearFieldSubmissionLevel {
            print("[VCC-SUBMIT] dropped far-field rms=\(rms) (need>=\(nearFieldSubmissionLevel))")
            lastFilterResultText = "rejected far-field"
            return false
        }
        print("[VCC-SUBMIT] accepted rms=\(rms)")
        return true
    }

    private func speakerEvidenceRequest(for audioEvidence: SpeechAudioEvidence) -> UserTurnSpeakerEvidenceRequest {
        let playbackActive = state == .speaking || isAssistantPlaybackActive
        let interruptedInput = isCapturingInterruptedInput || didObserveBargeIn
        return UserTurnSpeakerEvidenceRequest(
            audio: audioEvidence,
            isAssistantPlaybackActive: playbackActive,
            isInterruptedInput: interruptedInput,
            allowsEnrollment: canEnrollSpeakerEvidence(
                playbackActive: playbackActive,
                interruptedInput: interruptedInput
            )
        )
    }

    private func canEnrollSpeakerEvidence(playbackActive: Bool, interruptedInput: Bool) -> Bool {
        guard !playbackActive, !interruptedInput else { return false }
        switch state {
        case .listening, .recognizing:
            return true
        case .requestingPermission, .thinking, .speaking, .interrupted, .muted, .idle, .ended, .error:
            return false
        }
    }

    private func handleFinalRecognition(_ text: String, speakerEvidence: UserTurnSpeakerEvidence?) {
        partialAutoSubmitTask?.cancel()
        partialAutoSubmitTask = nil
        guard let cleanText = userSpeechTextForCurrentInput(text) else {
            return
        }
        cancelAudioOnlyInterruptionRecovery()
        if shouldHoldAsLeadIn(cleanText, state: state) {
            holdLeadIn(cleanText)
            return
        }
        let turnText = consumePendingLeadIn(appending: cleanText)
        switch state {
        case .speaking:
            // Energy/text barge-in, final path. A recognized final arriving during
            // playback means the user spoke over the assistant, so stop the AI now.
            // Voiceprint is NOT used to gate the interruption (echo makes the live
            // score unreliable mid-playback); it gates only whether the sentence is
            // kept, via the submission gate inside submitUserTurn — which runs after
            // we've left .speaking so it sees clean, non-playback evidence.
            startBargeIn(partialText: turnText)
            submitUserTurn(turnText, speakerEvidence: speakerEvidence)
            return
        case .listening, .recognizing:
            if applyCurrentTurnCorrectionIfNeeded(for: turnText, allowsInterruptedInput: false) {
                return
            }
            if pendingUserContinuationMessageID != nil {
                submitUserTurn(
                    mergedUserText(appending: turnText),
                    mergeWithCurrentUserMessage: true,
                    speakerEvidence: speakerEvidence
                )
            } else {
                submitUserTurn(turnText, speakerEvidence: speakerEvidence)
            }
        case .interrupted:
            if pendingUserContinuationMessageID != nil {
                submitUserTurn(
                    mergedUserText(appending: turnText),
                    mergeWithCurrentUserMessage: true,
                    speakerEvidence: speakerEvidence
                )
            } else {
                submitUserTurn(turnText, speakerEvidence: speakerEvidence)
            }
        case .thinking:
            if !applyCurrentTurnCorrectionIfNeeded(for: turnText, allowsInterruptedInput: false) {
                guard !isDuplicateOfCurrentUserTurn(turnText) else { return }
                submitUserTurn(turnText, speakerEvidence: speakerEvidence)
            }
        case .requestingPermission, .muted, .idle, .ended, .error:
            return
        }
    }

    private func handleVoiceActivity(_ activity: VoiceActivityEvent) async {
        if activity.source == .environmentNoise || activity.source == .otherSpeaker {
            rememberBackgroundRejection(for: activity)
            lastFilterResultText = recentBackgroundRejection?.filterText ?? "rejected noise"
            return
        }

        guard canTreatVoiceActivityAsBargeIn(activity) else { return }
        guard activity.source != .aiPlaybackEcho,
              activity.source != .environmentNoise,
              canAudioActivityInterruptCurrentState(activity) else {
            rememberBackgroundRejection(for: activity)
            lastFilterResultText = "rejected noise"
            return
        }

        if state == .speaking || activity.isAIPlaybackActive {
            await evaluatePlaybackBargeInActivity(activity)
            return
        }

        guard isImmediateBargeInActivity(activity) else {
            rememberBackgroundRejection(for: activity)
            lastFilterResultText = "rejected noise"
            return
        }
        startAudioBargeIn()
    }

    private func evaluatePlaybackBargeInActivity(_ activity: VoiceActivityEvent) async {
        // Energy-triggered barge-in. Voiceprint is NOT consulted here: residual AI
        // echo makes any live speaker score unreliable during playback. Two ways
        // to trip, whichever fires first (both leave the "keep the sentence?"
        // decision to the submission gate on clean post-interrupt audio):
        //   1. Loud, sustained energy (far above residual echo).
        //   2. A sharp onset jump at moderate energy — a near-field user speaking
        //      up. Far-field chatter ramps in diffusely and won't clear the onset
        //      bar, so this adds responsiveness without inviting background voices.
        guard activity.duration >= playbackSpeakerCheckDuration else {
            lastFilterResultText = "below barge threshold"
            print("[VCC-BARGE] below dur level=\(activity.inputLevel) dur=\(activity.duration) onset=\(activity.onsetRate)")
            return
        }

        let loudEnough = activity.inputLevel >= playbackBargeInInputLevel
        let sharpOnset = activity.inputLevel >= playbackBargeInOnsetFloorLevel &&
            activity.onsetRate >= playbackBargeInOnsetRate

        guard loudEnough || sharpOnset else {
            lastFilterResultText = "below barge threshold"
            print("[VCC-BARGE] below threshold level=\(activity.inputLevel) dur=\(activity.duration) onset=\(activity.onsetRate) (need level>=\(playbackBargeInInputLevel) OR onset>=\(playbackBargeInOnsetRate)@level>=\(playbackBargeInOnsetFloorLevel))")
            return
        }

        let trigger = loudEnough ? "loud" : "onset"
        print("[VCC-BARGE] energy barge-in FIRED via=\(trigger) level=\(activity.inputLevel) dur=\(activity.duration) onset=\(activity.onsetRate)")
        startAudioBargeIn()
    }

    private func canTreatVoiceActivityAsBargeIn(_ activity: VoiceActivityEvent) -> Bool {
        if state == .speaking || state == .thinking {
            return true
        }

        guard state == .listening,
              activity.isAIPlaybackActive else {
            return false
        }
        return true
    }

    private func isImmediateBargeInActivity(_ activity: VoiceActivityEvent) -> Bool {
        switch activity.source {
        case .currentUser:
            return activity.inputLevel >= currentUserBargeInInputLevel &&
                activity.duration >= currentUserBargeInDuration
        case .unknown:
            return false
        case .environmentNoise, .otherSpeaker, .aiPlaybackEcho:
            return false
        }
    }

    private func canAudioActivityInterruptCurrentState(_ activity: VoiceActivityEvent) -> Bool {
        guard state == .thinking else { return true }
        return activity.source == .currentUser
    }

    private func evaluateBargeIn(
        event: VoiceActivityEvent,
        speakerHint: SpeakerHint,
        text: String,
        submitOnAllow: Bool
    ) async {
        guard state == .speaking else {
            lastFilterResultText = "rejected noise"
            return
        }

        let decision = await bargeInGate.evaluate(event, speakerHint: speakerHint)
        switch decision {
        case .allowBargeIn:
            lastFilterResultText = "accepted"
            startBargeIn(partialText: text)
            if submitOnAllow {
                submitUserTurn(text)
            }
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

    private func rejectRecognitionDuringAssistantPlayback(_ text: String) {
        lastFilterResultText = "rejected playback"
        let preview = String(text.prefix(48))
        print("[VoiceCallCoordinator] gated recognition during assistant playback length=\(text.count) preview=\"\(preview)\"")
    }

    private func isLikelyAssistantEcho(_ text: String) -> Bool {
        let assistantText = currentAssistantEchoText()
        return echoDetector.isLikelyEcho(recognizedText: text, assistantText: assistantText)
    }

    private func userSpeechTextRemovingAssistantEcho(_ text: String) -> String? {
        let cleanText = clean(text)
        guard !cleanText.isEmpty else { return nil }
        let assistantText = currentAssistantEchoText()
        guard !isLikelyAssistantTailEcho(cleanText) else {
            lastFilterResultText = "rejected echo"
            return nil
        }
        guard !clean(assistantText).isEmpty else { return cleanText }
        let activeEchoDetector = state == .speaking && !containsASCIIWord(cleanText) ? playbackEchoDetector : echoDetector

        let removal = activeEchoDetector.removingEcho(from: cleanText, assistantText: assistantText)
        if removal.didRemoveEcho {
            guard let text = removal.text, !clean(text).isEmpty, isMeaningfulBargeInRemainder(text) else {
                lastFilterResultText = "rejected echo"
                return nil
            }
            lastFilterResultText = "stripped echo"
            return clean(text)
        }

        guard !activeEchoDetector.isLikelyEcho(recognizedText: cleanText, assistantText: assistantText) else {
            lastFilterResultText = "rejected echo"
            return nil
        }
        return cleanText
    }

    private func userSpeechTextForCurrentInput(_ text: String) -> String? {
        if isCapturingInterruptedInput || didObserveBargeIn {
            return userSpeechTextRemovingInterruptedAssistantTail(text)
        }
        return userSpeechTextRemovingAssistantEcho(text)
    }

    private func userSpeechTextRemovingInterruptedAssistantTail(_ text: String) -> String? {
        let cleanText = clean(text)
        guard !cleanText.isEmpty else { return nil }
        let assistantText = clean(interruptedAssistantEchoText.isEmpty ? currentAssistantEchoText() : interruptedAssistantEchoText)
        guard !assistantText.isEmpty else {
            return userSpeechTextRemovingAssistantEcho(cleanText)
        }

        if let remainder = interruptedUserRemainderAfterAssistantPrefix(
            recognizedText: cleanText,
            assistantText: assistantText
        ) {
            let cleanRemainder = clean(remainder)
            guard !cleanRemainder.isEmpty, isMeaningfulBargeInRemainder(cleanRemainder) else {
                lastFilterResultText = "rejected echo"
                return nil
            }
            lastFilterResultText = "stripped echo"
            return cleanRemainder
        }

        return userSpeechTextRemovingAssistantEcho(cleanText)
    }

    private func interruptedUserRemainderAfterAssistantPrefix(
        recognizedText: String,
        assistantText: String
    ) -> String? {
        let recognizedNormalized = normalizedRecognitionTurnText(recognizedText)
        let assistantNormalized = normalizedRecognitionTurnText(assistantText)
        guard !recognizedNormalized.isEmpty, !assistantNormalized.isEmpty else { return nil }

        let minimumPrefixLength = containsCJKCharacter(assistantText) ? 4 : 8
        let maximumLength = min(recognizedNormalized.count, assistantNormalized.count)
        guard maximumLength >= minimumPrefixLength else { return nil }

        for length in stride(from: maximumLength, through: minimumPrefixLength, by: -1) {
            let suffixStart = assistantNormalized.index(assistantNormalized.endIndex, offsetBy: -length)
            let assistantSuffix = String(assistantNormalized[suffixStart...])
            guard recognizedNormalized.hasPrefix(assistantSuffix) else { continue }
            return remainderAfterRemovingNormalizedPrefix(assistantSuffix, from: recognizedText)
        }

        for candidate in assistantBoundaryPrefixCandidates(assistantText) {
            let normalizedCandidate = normalizedRecognitionTurnText(candidate)
            guard normalizedCandidate.count >= minimumPrefixLength,
                  recognizedNormalized.hasPrefix(normalizedCandidate) else {
                continue
            }
            return remainderAfterRemovingNormalizedPrefix(normalizedCandidate, from: recognizedText)
        }

        let minimumContainedPrefixLength = containsCJKCharacter(assistantText) ? 8 : 16
        guard maximumLength >= minimumContainedPrefixLength else { return nil }

        for length in stride(from: maximumLength, through: minimumContainedPrefixLength, by: -1) {
            let prefixEnd = recognizedNormalized.index(recognizedNormalized.startIndex, offsetBy: length)
            let recognizedPrefix = String(recognizedNormalized[..<prefixEnd])
            guard assistantNormalized.contains(recognizedPrefix) else { continue }
            return remainderAfterRemovingNormalizedPrefix(recognizedPrefix, from: recognizedText)
        }

        return nil
    }

    private func assistantBoundaryPrefixCandidates(_ text: String) -> [String] {
        let delimiters: Set<Character> = ["。", "！", "？", "；", "\n", ".", "!", "?"]
        var candidates: [String] = []
        var current = ""

        for character in text {
            if delimiters.contains(character) {
                let candidate = clean(current)
                if !candidate.isEmpty {
                    candidates.append(candidate)
                }
                current.removeAll()
            } else {
                current.append(character)
            }
        }

        let tail = clean(current)
        if !tail.isEmpty {
            candidates.append(tail)
        }

        return candidates.sorted { $0.count > $1.count }
    }

    private func remainderAfterRemovingNormalizedPrefix(_ normalizedPrefix: String, from text: String) -> String? {
        guard !normalizedPrefix.isEmpty else { return nil }
        var prefixIndex = normalizedPrefix.startIndex

        for index in text.indices {
            let normalizedCharacter = normalizedRecognitionTurnText(String(text[index]))
            guard !normalizedCharacter.isEmpty else { continue }
            guard normalizedPrefix[prefixIndex...].hasPrefix(normalizedCharacter) else { return nil }
            prefixIndex = normalizedPrefix.index(prefixIndex, offsetBy: normalizedCharacter.count)
            if prefixIndex == normalizedPrefix.endIndex {
                let remainderStart = text.index(after: index)
                return String(text[remainderStart...])
            }
        }

        return prefixIndex == normalizedPrefix.endIndex ? "" : nil
    }

    private func isMeaningfulBargeInRemainder(_ text: String) -> Bool {
        let cleanText = clean(text)
        guard cleanText.count >= 3 else { return false }
        let fillerWords: Set<String> = ["哦", "嗯", "呃", "啊", "ok", "okay", "um", "uh"]
        return !fillerWords.contains(cleanText.lowercased())
    }

    private func containsASCIIWord(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.isASCII }
    }

    private func currentAssistantEchoText() -> String {
        var candidates: [String] = []
        appendEchoCandidate(activeAssistantText, to: &candidates)
        appendEchoCandidate(currentAssistantVoiceText, to: &candidates)
        guard let updatedAt = recentAssistantSpeechUpdatedAt,
              dateProvider().timeIntervalSince(updatedAt) <= assistantEchoMemoryWindow else {
            return candidates.joined(separator: " ")
        }
        recentAssistantSpeechTexts.forEach { appendEchoCandidate($0, to: &candidates) }
        return candidates.joined(separator: " ")
    }

    private func isLikelyAssistantTailEcho(_ text: String) -> Bool {
        let cleanText = clean(text)
        guard shouldEvaluateLongTailEcho(for: cleanText) else { return false }
        pruneAssistantTailEchoCandidates()
        return recentAssistantTailEchoCandidates.contains { candidate in
            echoDetector.isLikelyEcho(recognizedText: cleanText, assistantText: candidate.text)
        }
    }

    private func shouldEvaluateLongTailEcho(for text: String) -> Bool {
        let normalizedText = normalizedRecognitionTurnText(text)
        guard normalizedText.count >= 10 else { return false }
        guard containsCJKCharacter(text) || normalizedText.split(whereSeparator: \.isWhitespace).count >= 4 else {
            return false
        }
        return true
    }

    private func captureInterruptedAssistantEchoText() {
        let assistantText = currentAssistantEchoText()
        if !assistantText.isEmpty {
            interruptedAssistantEchoText = assistantText
        }
    }

    private func startBargeIn(partialText: String) {
        guard state == .speaking else { return }
        print("[VCC-BARGE] startBargeIn (final path) FIRED state=\(state)")
        captureInterruptedAssistantEchoText()
        invalidateActiveTurn()
        didObserveBargeIn = true
        isCapturingInterruptedInput = true
        isAssistantStreamComplete = false
        isAssistantPlaybackActive = false
        lastFilterResultText = "accepted"
        activeUserPartialText = partialText
        markCurrentAssistantInterrupted()
        state = .recognizing(partialText: partialText)
        // The barge-in partial only opens the interrupted turn for display.
        // Submission waits for the ASR final, mirroring the web coordinator, so
        // the interrupting utterance becomes one bubble instead of fragments.
        // NOTE: we intentionally do NOT restart the recognizer here. Restarting
        // dropped the rest of the interrupting sentence (the words after the
        // first few that triggered the barge-in) into a cancelled stream, so the
        // user's "等等 我想问英伟达" lost everything after "等等". Keeping the same
        // stream lets the full utterance arrive in one final, exactly like web.
        Task { [playback] in
            await playback.cancel()
            await playback.clear()
        }
    }

    private func startAudioBargeIn() {
        guard state == .speaking || state == .thinking || state == .listening else { return }
        print("[VCC-BARGE] startAudioBargeIn (VAD path) FIRED state=\(state)")
        captureInterruptedAssistantEchoText()
        invalidateActiveTurn()
        didObserveBargeIn = true
        isCapturingInterruptedInput = true
        isAssistantStreamComplete = false
        isAssistantPlaybackActive = false
        lastFilterResultText = "accepted"
        activeUserPartialText = ""
        markCurrentAssistantInterrupted()
        state = .interrupted
        scheduleAudioOnlyInterruptionRecovery()
        Task { [playback] in
            await playback.cancel()
            await playback.clear()
        }
    }

    private func startPendingResponseInterruption(partialText: String) {
        captureInterruptedAssistantEchoText()
        invalidateActiveTurn()
        didObserveBargeIn = true
        isCapturingInterruptedInput = true
        isAssistantStreamComplete = false
        isAssistantPlaybackActive = false
        lastFilterResultText = "accepted"
        activeUserPartialText = partialText
        activeUserChatID = nil
        activeBotChatID = nil
        currentAssistantMessageID = nil
        pendingUserContinuationMessageID = nil
        state = .recognizing(partialText: partialText)
        // Interrupting the pending response only opens the new turn for display.
        // The ASR final commits it, so a single utterance is one user bubble.
        Task { [playback] in
            await playback.cancel()
            await playback.clear()
        }
    }

    private func submitUserTurn(
        _ text: String,
        mergeWithCurrentUserMessage: Bool = false,
        speakerEvidence: UserTurnSpeakerEvidence? = nil
    ) {
        guard let conversation = ensureConversationContext() else { return }
        let submittedText = userTurnTextCollapsingRepeatedUtterance(text)
        guard !submittedText.isEmpty else { return }
        guard shouldSubmitUserTurn(submittedText, speakerEvidence: speakerEvidence) else { return }
        partialAutoSubmitTask?.cancel()
        partialAutoSubmitTask = nil
        cancelAudioOnlyInterruptionRecovery()
        clearPendingLeadIn()
        invalidateActiveTurn()
        interruptedAssistantEchoText = ""
        recentBackgroundRejection = nil

        let turnID = UUID()
        currentTurnID = turnID
        currentTurnSubmittedAt = dateProvider()
        didRecordAssistantResponseStart = false
        isCapturingInterruptedInput = false
        isAssistantPlaybackActive = false
        isAssistantStreamComplete = false
        lastLatencyDebugText = "user turn submitted"
        print("[VoiceCallCoordinator] user turn submitted length=\(submittedText.count)")
        activeUserPartialText = ""
        activeAssistantText = ""
        currentAssistantVoiceText = ""
        activeUserChatID = nil
        activeBotChatID = nil
        currentAssistantMessageID = nil
        pendingUserContinuationMessageID = nil

        let mergeMessageID = currentUserMessageID ?? messages.last(where: { $0.role == .user })?.id
        if mergeWithCurrentUserMessage, let mergeMessageID {
            currentUserMessageID = mergeMessageID
            updateUserMessage(id: mergeMessageID, displayText: submittedText)
        } else {
            let userMessageID = nextMessageID(prefix: "user")
            currentUserMessageID = userMessageID
            appendMessage(ChatMessage(
                id: userMessageID,
                conversationID: conversation.cid,
                role: .user,
                displayText: submittedText,
                voiceText: nil,
                createdAt: dateProvider(),
                deliveryState: .complete
            ))
        }
        currentUserText = submittedText
        state = .thinking
        scheduleAssistantResponseStartWatchdog(turnID: turnID)
        scheduleAssistantResponseHardTimeout(turnID: turnID)
        playLocalResponsePreludeIfNeeded()

        let stream = chatClient.sendMessage(submittedText, conversation: conversation)
        chatTask = Task { [weak self] in
            do {
                for try await update in stream {
                    await MainActor.run {
                        self?.handleChatUpdate(update, turnID: turnID, conversation: conversation)
                    }
                }
            } catch is CancellationError {
                return
            } catch let appError as AppError {
                await MainActor.run {
                    guard self?.currentTurnID == turnID else { return }
                    self?.state = .error(appError)
                }
            } catch {
                await MainActor.run {
                    guard self?.currentTurnID == turnID else { return }
                    self?.state = .error(.unknown(error.localizedDescription))
                }
            }
        }
    }

    private func shouldSubmitUserTurn(_ text: String, speakerEvidence: UserTurnSpeakerEvidence?) -> Bool {
        let candidate = UserTurnSubmissionCandidate(
            text: text,
            isAssistantPlaybackActive: state == .speaking || isAssistantPlaybackActive,
            isInterruptedInput: isCapturingInterruptedInput,
            speakerEvidence: speakerEvidence
        )
        return shouldSubmit(candidate)
    }

    private func shouldSubmit(_ candidate: UserTurnSubmissionCandidate) -> Bool {
        switch submissionGate.evaluate(candidate) {
        case .accept:
            return true
        case .reject(let reason):
            rejectUserTurnSubmission(reason)
            return false
        }
    }

    private func rejectUserTurnSubmission(_ reason: UserTurnSubmissionRejectionReason) {
        partialAutoSubmitTask?.cancel()
        partialAutoSubmitTask = nil
        cancelAudioOnlyInterruptionRecovery()
        activeUserPartialText = ""
        isCapturingInterruptedInput = false
        didObserveBargeIn = false
        interruptedAssistantEchoText = ""
        lastFilterResultText = filterText(for: reason)
        if state == .recognizing(partialText: activeUserPartialText) || state == .interrupted || state == .listening {
            state = .listening
        } else if case .recognizing = state {
            state = .listening
        }
    }

    private func rejectAsRecentBackgroundActivityIfNeeded() -> Bool {
        guard let rejection = recentBackgroundRejection,
              dateProvider().timeIntervalSince(rejection.updatedAt) <= backgroundRejectionMemoryWindow else {
            recentBackgroundRejection = nil
            return false
        }
        rejectUserTurnSubmission(rejection.reason)
        lastFilterResultText = rejection.filterText
        return true
    }

    private func rememberBackgroundRejection(for activity: VoiceActivityEvent) {
        switch activity.source {
        case .otherSpeaker:
            rememberBackgroundRejection(.otherSpeaker, filterText: "rejected other speaker")
        case .environmentNoise, .unknown:
            rememberBackgroundRejection(.speakerUnverified, filterText: "rejected noise")
        case .currentUser, .aiPlaybackEcho:
            break
        }
    }

    private func rememberBackgroundRejection(for evidence: UserTurnSpeakerEvidence?) {
        switch evidence?.match {
        case .otherSpeaker:
            rememberBackgroundRejection(.otherSpeaker, filterText: "rejected other speaker")
        case .uncertain, .unavailable, .none:
            rememberBackgroundRejection(.speakerUnverified, filterText: "speaker unverified")
        case .verifiedCurrentUser:
            recentBackgroundRejection = nil
        }
    }

    private func rememberBackgroundRejection(_ reason: UserTurnSubmissionRejectionReason, filterText: String) {
        recentBackgroundRejection = RecentBackgroundRejection(
            reason: reason,
            filterText: filterText,
            updatedAt: dateProvider()
        )
    }

    private func filterText(for reason: UserTurnSubmissionRejectionReason) -> String {
        switch reason {
        case .speakerUnverified:
            return "speaker unverified"
        case .otherSpeaker:
            return "rejected other speaker"
        case .aiPlaybackEcho:
            return "rejected echo"
        case .uncertainSpeaker:
            return "speaker uncertain"
        }
    }

    private func filterText(for evidence: UserTurnSpeakerEvidence?) -> String {
        switch evidence?.match {
        case .verifiedCurrentUser:
            return "accepted"
        case .otherSpeaker:
            return "rejected other speaker"
        case .uncertain:
            return "speaker uncertain"
        case .unavailable, .none:
            return "speaker unverified"
        }
    }

    private func handleChatUpdate(_ update: ChatStreamUpdate, turnID: UUID, conversation: ConversationContext) {
        guard currentTurnID == turnID else { return }

        switch update {
        case .started(let userChatID, let botChatID):
            activeUserChatID = userChatID
            activeBotChatID = botChatID
            currentAssistantMessageID = botChatID
        case .assistantToken(let token):
            guard !token.isEmpty else { return }
            recordAssistantResponseStartIfNeeded()
            let assistantID = activeBotChatID ?? currentAssistantMessageID ?? nextMessageID(prefix: "assistant")
            activeBotChatID = assistantID
            currentAssistantMessageID = assistantID
            activeAssistantText += token
            currentAssistantVoiceText += token
            rememberAssistantSpeech(currentAssistantVoiceText)
            appendOrUpdateAssistantMessage(
                id: assistantID,
                conversationID: conversation.cid,
                displayText: activeAssistantText,
                voiceText: nil,
                deliveryState: .streaming
            )
            // Display text updates live, but audio is NOT enqueued per token.
            // This backend buffers the whole turn then flushes all tokens within
            // ~0.5s, so per-token segmentation gains no latency yet splits words
            // mid-phrase and breaks prosody. The full turn is synthesized once at
            // `.final`. Keep the on-screen state as streaming; don't enter
            // `.speaking` until real audio plays.
        case .final(let displayText, let voiceText, _):
            recordAssistantResponseStartIfNeeded()
            let finalDisplayText = clean(displayText).isEmpty ? activeAssistantText : displayText
            let finalVoiceText = clean(voiceText ?? "").isEmpty ? finalDisplayText : (voiceText ?? finalDisplayText)
            activeAssistantText = finalDisplayText
            currentAssistantVoiceText = finalVoiceText
            rememberAssistantSpeech(finalDisplayText)
            rememberAssistantSpeech(finalVoiceText)
            let assistantID = activeBotChatID ?? currentAssistantMessageID ?? nextMessageID(prefix: "assistant")
            activeBotChatID = assistantID
            currentAssistantMessageID = assistantID
            appendOrUpdateAssistantMessage(
                id: assistantID,
                conversationID: conversation.cid,
                displayText: finalDisplayText,
                voiceText: finalVoiceText,
                deliveryState: .complete
            )
            // Speak the on-screen text (display_text), not the backend's separate
            // voice_text, so the spoken words match what the user is reading. The
            // whole turn is one segment for natural prosody; the playback queue's
            // sanitizer strips punctuation/symbols before synthesis.
            let speechText = clean(finalDisplayText)
            if !speechText.isEmpty {
                state = .speaking
                isAssistantPlaybackActive = true
                Task { [playback] in
                    await playback.enqueue(speechText, isFinal: true)
                }
            } else {
                Task { [playback] in
                    await playback.enqueue("", isFinal: true)
                }
            }
        case .messageIDs:
            break
        case .completed:
            guard currentTurnID == turnID else { return }
            isAssistantStreamComplete = true
            completeAssistantPlaybackIfReady()
        }
    }

    private func completeAssistantPlaybackIfReady() {
        guard isAssistantStreamComplete, !isAssistantPlaybackActive else { return }
        activeUserPartialText = ""
        activeAssistantText = ""
        currentAssistantVoiceText = ""
        currentTurnSubmittedAt = nil
        didRecordAssistantResponseStart = false
        isAssistantStreamComplete = false
        state = didObserveBargeIn ? .interrupted : .listening
        if didObserveBargeIn {
            didObserveBargeIn = false
            state = .listening
        }
    }

    private func ensureConversationContext() -> ConversationContext? {
        if let conversationContext {
            return conversationContext
        }
        let conversation = conversationIDFactory.makeConversationContext()
        conversationContext = conversation
        return conversation
    }

    private func recordAssistantResponseStartIfNeeded() {
        guard !didRecordAssistantResponseStart else { return }
        didRecordAssistantResponseStart = true
        assistantResponseStartWatchdogTask?.cancel()
        assistantResponseStartWatchdogTask = nil
        assistantResponseHardTimeoutTask?.cancel()
        assistantResponseHardTimeoutTask = nil
        guard let currentTurnSubmittedAt else {
            lastLatencyDebugText = "assistant response start latency unavailable"
            print("[VoiceCallCoordinator] assistant response start latency unavailable")
            return
        }

        let elapsedMilliseconds = Int(dateProvider().timeIntervalSince(currentTurnSubmittedAt) * 1000)
        lastLatencyDebugText = "assistant response start \(elapsedMilliseconds)ms"
        print("[VoiceCallCoordinator] assistant response start latencyMs=\(elapsedMilliseconds)")
    }

    private func invalidateActiveTurn() {
        currentTurnID = nil
        chatTask?.cancel()
        chatTask = nil
        assistantResponseStartWatchdogTask?.cancel()
        assistantResponseStartWatchdogTask = nil
        assistantResponseHardTimeoutTask?.cancel()
        assistantResponseHardTimeoutTask = nil
        isAssistantStreamComplete = false
    }

    private func scheduleAssistantResponseStartWatchdog(turnID: UUID) {
        assistantResponseStartWatchdogTask?.cancel()
        assistantResponseStartWatchdogTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: assistantResponseStartTimeoutNanoseconds)
            } catch {
                return
            }
            await MainActor.run {
                guard self.currentTurnID == turnID,
                      self.state == .thinking,
                      !self.didRecordAssistantResponseStart else {
                    return
                }
                self.lastLatencyDebugText = "assistant response delayed"
                print("[VoiceCallCoordinator] assistant response delayed")
            }
        }
    }

    private func scheduleAssistantResponseHardTimeout(turnID: UUID) {
        assistantResponseHardTimeoutTask?.cancel()
        assistantResponseHardTimeoutTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: assistantResponseHardTimeoutNanoseconds)
            } catch {
                return
            }
            await MainActor.run {
                guard self.currentTurnID == turnID,
                      self.state == .thinking,
                      !self.didRecordAssistantResponseStart else {
                    return
                }
                self.currentTurnID = nil
                self.chatTask?.cancel()
                self.chatTask = nil
                self.assistantResponseStartWatchdogTask?.cancel()
                self.assistantResponseStartWatchdogTask = nil
                self.assistantResponseHardTimeoutTask = nil
                self.currentTurnSubmittedAt = nil
                self.lastLatencyDebugText = "assistant response timed out"
                self.state = .error(.chatResponseTimedOut)
                print("[VoiceCallCoordinator] assistant response timed out")
                let playback = self.playback
                Task { [playback] in
                    await playback.cancel()
                    await playback.clear()
                }
            }
        }
    }

    private func scheduleAudioOnlyInterruptionRecovery() {
        audioOnlyInterruptionRecoveryTask?.cancel()
        audioOnlyInterruptionRecoveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: audioOnlyInterruptionTimeoutNanoseconds)
            } catch {
                return
            }
            await MainActor.run {
                guard self.state == .interrupted,
                      self.clean(self.activeUserPartialText).isEmpty else {
                    return
                }
                self.isCapturingInterruptedInput = false
                self.didObserveBargeIn = false
                self.lastFilterResultText = "rejected noise"
                self.state = .listening
            }
        }
    }

    private func cancelAudioOnlyInterruptionRecovery() {
        audioOnlyInterruptionRecoveryTask?.cancel()
        audioOnlyInterruptionRecoveryTask = nil
    }

    private func holdLeadIn(_ text: String) {
        let cleanText = clean(text)
        guard !cleanText.isEmpty else { return }
        pendingLeadInText = latestLeadInText(existing: pendingLeadInText, incoming: cleanText)
        activeUserPartialText = ""
        state = .listening
        leadInClearTask?.cancel()
        leadInClearTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: leadInHoldNanoseconds)
            } catch {
                return
            }
            await MainActor.run {
                self.clearPendingLeadIn()
            }
        }
    }

    private func clearPendingLeadIn() {
        pendingLeadInText = ""
        leadInClearTask?.cancel()
        leadInClearTask = nil
    }

    private func playLocalResponsePreludeIfNeeded() {
        guard let prelude = localResponsePreludes.first else { return }
        rememberAssistantSpeech(prelude)
        Task { [playback] in
            await playback.enqueue(prelude, isFinal: false)
        }
    }

    private func shouldPromotePlaybackStartedToSpeaking(_ text: String) -> Bool {
        guard state == .thinking || state == .listening else { return false }
        guard state == .thinking,
              !didRecordAssistantResponseStart,
              isLocalResponsePrelude(text) else {
            return true
        }
        return false
    }

    private func isLocalResponsePrelude(_ text: String) -> Bool {
        let cleanText = clean(text)
        return localResponsePreludes.contains { clean($0) == cleanText }
    }

    private var currentUserBaseText: String? {
        let messageID = pendingUserContinuationMessageID
            ?? currentUserMessageID
            ?? messages.last(where: { $0.role == .user })?.id
        guard let messageID,
              let message = messages.first(where: { $0.id == messageID }),
              !clean(message.displayText).isEmpty else {
            return clean(currentUserText).isEmpty ? nil : clean(currentUserText)
        }
        return clean(message.displayText)
    }

    private func partialTextForCurrentRecognition(_ text: String) -> String {
        guard pendingUserContinuationMessageID != nil else { return text }
        return mergedUserText(appending: text)
    }

    private func shouldAcceptPartialForDisplay(_ text: String, state: VoiceCallState) -> Bool {
        let cleanText = clean(text)
        if state == .thinking || state == .interrupted || isCapturingInterruptedInput || didObserveBargeIn {
            return cleanText.count >= 2
        }
        let minimumCount = containsCJKCharacter(cleanText) ? 5 : minimumStablePartialCharacterCount
        return cleanText.count >= minimumCount
    }

    private func shouldHoldAsLeadIn(_ text: String, state: VoiceCallState) -> Bool {
        guard state == .listening || state == .recognizing(partialText: activeUserPartialText) || state == .interrupted else {
            return false
        }
        let cleanText = clean(text)
        guard containsCJKCharacter(cleanText),
              cjkCharacterCount(cleanText) <= 10,
              !containsCompleteQuestionOrCommand(cleanText) else {
            return false
        }
        return startsWithDiscourseLeadIn(cleanText) || !pendingLeadInText.isEmpty
    }

    private func consumePendingLeadIn(appending text: String) -> String {
        let cleanText = clean(text)
        guard !pendingLeadInText.isEmpty else { return cleanText }
        let leadIn = pendingLeadInText
        clearPendingLeadIn()
        if normalizedLeadIn(cleanText).hasPrefix(normalizedLeadIn(leadIn)) {
            return cleanText
        }
        return "\(leadIn)\(cleanText)"
    }

    private func latestLeadInText(existing: String, incoming: String) -> String {
        let cleanExisting = clean(existing)
        let cleanIncoming = clean(incoming)
        guard !cleanExisting.isEmpty else { return cleanIncoming }
        let normalizedExisting = normalizedLeadIn(cleanExisting)
        let normalizedIncoming = normalizedLeadIn(cleanIncoming)
        if normalizedIncoming.contains(normalizedExisting) {
            return cleanIncoming
        }
        if normalizedExisting.contains(normalizedIncoming) {
            return cleanExisting
        }
        return cleanIncoming
    }

    private func startsWithDiscourseLeadIn(_ text: String) -> Bool {
        let normalized = normalizedLeadIn(text)
        let prefixes = ["好的", "好", "然后", "嗯", "呃", "啊", "那个", "就是"]
        return prefixes.contains { normalized.hasPrefix($0) }
    }

    private func containsCompleteQuestionOrCommand(_ text: String) -> Bool {
        let normalized = normalizedLeadIn(text)
        if text.contains("?") || text.contains("？") { return true }
        let markers = ["怎么样", "怎么", "什么", "多少", "价格", "行情", "推荐", "查询", "查一下", "帮我", "看一下"]
        return markers.contains { normalized.contains($0) }
    }

    private func normalizedLeadIn(_ text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
                (0x4E00...0x9FFF).contains(scalar.value) ||
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        })
    }

    private func cjkCharacterCount(_ text: String) -> Int {
        text.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        }.count
    }

    private func containsCJKCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    private func currentTurnCorrectionText(for recognizedText: String) -> String? {
        guard let base = currentUserBaseText else { return nil }
        let cleanBase = clean(base)
        let cleanRecognizedText = clean(recognizedText)
        guard !cleanBase.isEmpty, !cleanRecognizedText.isEmpty else { return nil }
        if cleanRecognizedText.hasPrefix(cleanBase) || cleanRecognizedText.contains(cleanBase) {
            return cleanRecognizedText
        }
        if cleanBase.contains(cleanRecognizedText) {
            return cleanBase
        }
        if isLikelyRecognitionRevision(base: cleanBase, incoming: cleanRecognizedText) {
            return preferredRecognitionRevision(base: cleanBase, incoming: cleanRecognizedText)
        }
        return mergedTextByCollapsingOverlap(base: cleanBase, addition: cleanRecognizedText)
    }

    private func applyCurrentTurnCorrectionIfNeeded(
        for recognizedText: String,
        allowsInterruptedInput: Bool
    ) -> Bool {
        guard allowsInterruptedInput || !isCapturingInterruptedInput else { return false }
        guard let correctedText = currentTurnCorrectionText(for: recognizedText) else { return false }
        if isCurrentUserTurnCorrectionDisplayChange(correctedText) {
            applyCurrentUserTurnCorrection(correctedText)
        }
        return true
    }

    private func isCurrentUserTurnCorrectionDisplayChange(_ text: String) -> Bool {
        guard let currentUserBaseText else { return true }
        return clean(text) != clean(currentUserBaseText)
    }

    private func applyCurrentUserTurnCorrection(_ text: String) {
        let correctedText = clean(text)
        guard !correctedText.isEmpty else { return }
        let messageID = currentUserMessageID ?? messages.last(where: { $0.role == .user })?.id
        if let messageID {
            currentUserMessageID = messageID
            updateUserMessage(id: messageID, displayText: correctedText)
        }
        currentUserText = correctedText
        activeUserPartialText = ""
    }

    private func mergedUserText(appending continuation: String) -> String {
        let base = currentUserBaseText ?? ""
        let addition = clean(continuation)
        guard !base.isEmpty else { return addition }
        guard !addition.isEmpty else { return base }
        if addition.hasPrefix(base) {
            return addition
        }
        if addition.contains(base) {
            return addition
        }
        if base.contains(addition) {
            return base
        }
        if let overlappedText = mergedTextByCollapsingOverlap(base: base, addition: addition) {
            return overlappedText
        }
        return "\(base) \(addition)"
    }

    private func userTurnTextCollapsingRepeatedUtterance(_ text: String) -> String {
        let cleanText = clean(text)
        let characters = Array(cleanText)
        guard characters.count >= 16 else { return cleanText }

        let midpoint = characters.count / 2
        let window = max(2, characters.count / 6)
        let lowerBound = max(1, midpoint - window)
        let upperBound = min(characters.count - 1, midpoint + window)
        var bestCandidate: (score: Double, balance: Int, text: String)?

        for splitIndex in lowerBound...upperBound {
            let first = clean(String(characters[..<splitIndex]))
            let second = clean(String(characters[splitIndex...]))
            guard let score = duplicateUtteranceSimilarity(first, second) else { continue }
            let balance = abs(first.count - second.count)
            let candidateText = duplicateUtteranceCandidate(first: first, second: second)
            if bestCandidate == nil ||
                score > bestCandidate!.score ||
                (score == bestCandidate!.score && balance < bestCandidate!.balance) {
                bestCandidate = (score, balance, candidateText)
            }
        }

        return bestCandidate?.text ?? cleanText
    }

    private func duplicateUtteranceSimilarity(_ first: String, _ second: String) -> Double? {
        let firstNormalized = normalizedCharactersForDuplicateDetection(first)
        let secondNormalized = normalizedCharactersForDuplicateDetection(second)
        let minimumNormalizedLength = containsCJKText(first) && containsCJKText(second) ? 6 : 12
        guard firstNormalized.count >= minimumNormalizedLength,
              secondNormalized.count >= minimumNormalizedLength else {
            return nil
        }

        let shorter = min(firstNormalized.count, secondNormalized.count)
        let longer = max(firstNormalized.count, secondNormalized.count)
        guard Double(shorter) / Double(longer) >= 0.72 else { return nil }

        let commonLength = longestCommonSubsequenceLength(firstNormalized, secondNormalized)
        let score = Double(commonLength) / Double(longer)
        return score >= 0.82 ? score : nil
    }

    private func containsCJKText(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value)) ||
                (0x3400...0x4DBF).contains(Int(scalar.value)) ||
                (0x3040...0x30FF).contains(Int(scalar.value)) ||
                (0xAC00...0xD7AF).contains(Int(scalar.value))
        }
    }

    private func duplicateUtteranceCandidate(first: String, second: String) -> String {
        let firstNormalizedCount = normalizedCharactersForDuplicateDetection(first).count
        let secondNormalizedCount = normalizedCharactersForDuplicateDetection(second).count
        if firstNormalizedCount != secondNormalizedCount {
            return secondNormalizedCount > firstNormalizedCount ? second : first
        }

        let firstIgnoredCount = duplicateDetectionIgnoredCharacterCount(first)
        let secondIgnoredCount = duplicateDetectionIgnoredCharacterCount(second)
        if firstIgnoredCount != secondIgnoredCount {
            return firstIgnoredCount < secondIgnoredCount ? first : second
        }

        return first.count <= second.count ? first : second
    }

    private func duplicateDetectionIgnoredCharacterCount(_ text: String) -> Int {
        text.filter { character in
            !character.unicodeScalars.contains { scalar in
                CharacterSet.alphanumerics.contains(scalar)
            }
        }.count
    }

    private func normalizedCharactersForDuplicateDetection(_ text: String) -> [Character] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return folded.filter { character in
            character.unicodeScalars.contains { scalar in
                CharacterSet.alphanumerics.contains(scalar)
            }
        }
    }

    private func longestCommonSubsequenceLength(_ first: [Character], _ second: [Character]) -> Int {
        guard !first.isEmpty, !second.isEmpty else { return 0 }
        var previous = Array(repeating: 0, count: second.count + 1)
        var current = previous

        for firstIndex in 1...first.count {
            current[0] = 0
            for secondIndex in 1...second.count {
                if first[firstIndex - 1] == second[secondIndex - 1] {
                    current[secondIndex] = previous[secondIndex - 1] + 1
                } else {
                    current[secondIndex] = max(previous[secondIndex], current[secondIndex - 1])
                }
            }
            swap(&previous, &current)
        }

        return previous[second.count]
    }

    private func mergedTextByCollapsingOverlap(base: String, addition: String) -> String? {
        let maximumOverlap = min(base.count, addition.count)
        guard maximumOverlap >= minimumRecognitionOverlapLength else { return nil }

        for overlapLength in stride(from: maximumOverlap, through: minimumRecognitionOverlapLength, by: -1) {
            if suffix(base, length: overlapLength) == prefix(addition, length: overlapLength) {
                let additionStart = addition.index(addition.startIndex, offsetBy: overlapLength)
                return base + addition[additionStart...]
            }
        }

        return nil
    }

    private var minimumRecognitionOverlapLength: Int {
        4
    }

    private func prefix(_ text: String, length: Int) -> Substring {
        let endIndex = text.index(text.startIndex, offsetBy: length)
        return text[..<endIndex]
    }

    private func suffix(_ text: String, length: Int) -> Substring {
        let startIndex = text.index(text.endIndex, offsetBy: -length)
        return text[startIndex...]
    }

    private func isDuplicateOfCurrentUserTurn(_ text: String) -> Bool {
        guard let currentUserBaseText else { return false }
        let currentClean = clean(currentUserBaseText)
        let incomingClean = clean(text)
        guard !currentClean.isEmpty, !incomingClean.isEmpty else { return false }
        if currentClean == incomingClean { return true }
        return normalizedRecognitionTurnText(currentClean) == normalizedRecognitionTurnText(incomingClean)
    }

    private func isLikelyRecognitionRevision(base: String, incoming: String) -> Bool {
        let baseCharacters = normalizedCharactersForDuplicateDetection(base)
        let incomingCharacters = normalizedCharactersForDuplicateDetection(incoming)
        guard !baseCharacters.isEmpty, !incomingCharacters.isEmpty else { return false }

        let containsCJK = containsCJKText(base) && containsCJKText(incoming)
        let minimumBaseLength = containsCJK ? 4 : 8
        guard baseCharacters.count >= minimumBaseLength,
              incomingCharacters.count >= baseCharacters.count else {
            return false
        }

        let commonLength = longestCommonSubsequenceLength(baseCharacters, incomingCharacters)
        let baseCoverage = Double(commonLength) / Double(baseCharacters.count)
        let incomingCoverage = Double(commonLength) / Double(incomingCharacters.count)
        if containsCJK {
            return baseCoverage >= 0.80 && incomingCoverage >= 0.25
        }
        return baseCoverage >= 0.88 && incomingCoverage >= 0.45
    }

    private func preferredRecognitionRevision(base: String, incoming: String) -> String {
        let baseCount = normalizedCharactersForDuplicateDetection(base).count
        let incomingCount = normalizedCharactersForDuplicateDetection(incoming).count
        return incomingCount >= baseCount ? incoming : base
    }

    private func normalizedRecognitionTurnText(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(folded.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
                (0x4E00...0x9FFF).contains(scalar.value) ||
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        })
    }

    private func updateUserMessage(id: String, displayText: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].displayText = displayText
        messages[index].deliveryState = .complete
    }

    private func markCurrentAssistantInterrupted() {
        guard let currentAssistantMessageID,
              let index = messages.firstIndex(where: { $0.id == currentAssistantMessageID }) else {
            return
        }
        messages[index].deliveryState = .interrupted
    }

    private func appendOrUpdateAssistantMessage(
        id: String,
        conversationID: String,
        displayText: String,
        voiceText: String?,
        deliveryState: ChatMessage.DeliveryState
    ) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].displayText = displayText
            messages[index].voiceText = voiceText
            messages[index].deliveryState = deliveryState
            return
        }

        appendMessage(ChatMessage(
            id: id,
            conversationID: conversationID,
            role: .assistant,
            displayText: displayText,
            voiceText: voiceText,
            createdAt: dateProvider(),
            deliveryState: deliveryState
        ))
    }

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
    }

    private func rememberAssistantSpeech(_ text: String) {
        let cleanText = clean(text)
        guard !cleanText.isEmpty else { return }
        recentAssistantSpeechTexts.removeAll { clean($0) == cleanText }
        recentAssistantSpeechTexts.append(cleanText)
        if recentAssistantSpeechTexts.count > 6 {
            recentAssistantSpeechTexts.removeFirst(recentAssistantSpeechTexts.count - 6)
        }
        recentAssistantSpeechUpdatedAt = dateProvider()
        rememberAssistantTailEchoCandidate(cleanText)
    }

    private func clearAssistantEchoMemory() {
        recentAssistantSpeechTexts = []
        recentAssistantSpeechUpdatedAt = nil
        recentAssistantTailEchoCandidates = []
    }

    private func rememberAssistantTailEchoCandidate(_ text: String) {
        guard shouldEvaluateLongTailEcho(for: text) else { return }
        let now = dateProvider()
        recentAssistantTailEchoCandidates.removeAll { clean($0.text) == text }
        recentAssistantTailEchoCandidates.append(TimedAssistantEchoCandidate(text: text, updatedAt: now))
        if recentAssistantTailEchoCandidates.count > 12 {
            recentAssistantTailEchoCandidates.removeFirst(recentAssistantTailEchoCandidates.count - 12)
        }
        pruneAssistantTailEchoCandidates(now: now)
    }

    private func pruneAssistantTailEchoCandidates(now: Date? = nil) {
        let referenceDate = now ?? dateProvider()
        recentAssistantTailEchoCandidates.removeAll {
            referenceDate.timeIntervalSince($0.updatedAt) > assistantTailEchoMemoryWindow
        }
    }

    private func appendEchoCandidate(_ text: String, to candidates: inout [String]) {
        let cleanText = clean(text)
        guard !cleanText.isEmpty,
              !candidates.contains(where: { clean($0) == cleanText }) else {
            return
        }
        candidates.append(cleanText)
    }

    private func nextMessageID(prefix: String) -> String {
        messageSequence += 1
        return "\(prefix)-\(messageSequence)"
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startTimer() {
        callStartDate = dateProvider()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self, let callStartDate = self.callStartDate, self.state.isActiveCall else { return }
                    self.elapsedSeconds = max(1, Int(self.dateProvider().timeIntervalSince(callStartDate)))
                }
            }
        }
    }
}
