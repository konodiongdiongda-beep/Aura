import XCTest
@testable import VoiceCore

@MainActor
final class VoiceCallCoordinatorTests: XCTestCase {
    func testStartCallTransitionsFromIdleToListening() async throws {
        let harness = CoordinatorHarness()

        try await harness.coordinator.startCall()

        XCTAssertEqual(harness.coordinator.state, .listening)
        let audioStartCallCount = await harness.audio.startCallCountSnapshot()
        let recognizerStartCount = await harness.recognizer.startCountSnapshot()
        XCTAssertEqual(audioStartCallCount, 1)
        XCTAssertEqual(recognizerStartCount, 1)
        XCTAssertEqual(harness.coordinator.conversationContext?.cid, "conversation-1")
    }

    func testFinalSpeechTransitionsFromListeningToThinkingAndAddsUserMessage() async throws {
        let harness = CoordinatorHarness(chatClient: ControlledChatClient())
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertTrue(harness.coordinator.messages.contains { $0.role == .user && $0.displayText == "Hello Aura" })
        XCTAssertEqual(harness.chatClient.sentMessages, ["Hello Aura"])
    }

    func testSubmissionGateRejectsFinalSpeechBeforeChatSubmission() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            submissionGate: FixedUserTurnSubmissionGate(decision: .reject(.speakerUnverified))
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("旁边的人在说话")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "speaker unverified")
    }

    func testPlaybackAwareGateRejectsSpeakingFinalBeforeBargeInMarksInterrupted() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: PlaybackAwareUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("The assistant is still talking about markets.")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitFinal("this is recognized speaker output")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testSpeakerEvidenceRejectsOtherSpeakerBeforeChatSubmission() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinalWithEvidence(
            "旁边的人在说话",
            UserTurnSpeakerEvidence(match: .otherSpeaker, score: 0.42, threshold: 0.84)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected other speaker")
    }

    func testSpeakerEvidenceAllowsVerifiedCurrentUserDuringListening() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinalWithEvidence(
            "我想看黄金行情",
            UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.91, threshold: 0.84)
        )
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["我想看黄金行情"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["我想看黄金行情"])
    }

    func testSpeakerEvidenceDoesNotPromoteUninterruptedPlaybackFinal() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在解释上一条问题。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitFinalWithEvidence(
            "please show gold price",
            UserTurnSpeakerEvidence(match: .uncertain, score: 0.83, threshold: 0.86)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testUnknownPlaybackActivityDoesNotPromoteAssistantEchoToInterruptedUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("当前正在播放机器人自己的回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.85,
            duration: 0.8,
            isAIPlaybackActive: true,
            source: .unknown
        ))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.coordinator.state, .speaking)
        let cancelCountAfterUnknownActivity = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCountAfterUnknownActivity, 0)

        await harness.recognizer.emitFinalWithEvidence(
            "当前正在播放机器人自己的回答。",
            UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.95, threshold: 0.82)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testShortPlaybackPartialRecognitionDoesNotInterruptOrSubmitUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitPartial("嗯")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(chatClient.sentMessages, [])
        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "waiting final")
    }

    func testVerifiedVoiceActivityDuringPlaybackStartsBargeInBeforeRecognitionText() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        let requests = await speakerEvidenceProvider.requestsSnapshot()
        XCTAssertEqual(requests.first?.isAssistantPlaybackActive, true)
        XCTAssertEqual(requests.first?.allowsEnrollment, false)
    }

    func testInterruptedFinalTrimsAssistantPrefixBeforeSubmittingUserSpeech() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("这里是机器人自己的回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)

        await harness.recognizer.emitFinalWithEvidence(
            "这里是机器人自己的回答 帮我查黄金",
            UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.94, threshold: 0.82)
        )
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["帮我查黄金"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["帮我查黄金"])
    }

    func testInterruptedPartialTrimsAssistantPrefixBeforeFastSubmit() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("这里是机器人自己的回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)

        await harness.recognizer.emitPartial("这里是机器人自己的回答 帮我查黄金")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["帮我查黄金"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["帮我查黄金"])
    }

    func testInterruptedFinalRejectsAssistantOnlyPlaybackTail() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("这里是机器人自己的回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)

        await harness.recognizer.emitFinalWithEvidence(
            "这里是机器人自己的回答",
            UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.94, threshold: 0.82)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testVerifiedBargeInResetsRecognizerBeforeCapturingInterruptedSpeech() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)
        try await harness.recognizer.waitForStartCount(2)

        let cancelCount = await harness.recognizer.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
    }

    func testStaleOldRecognitionStreamAfterBargeInResetIsIgnored() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()
        let oldStreamIndex = await harness.recognizer.activeStreamIndexSnapshot()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在回答自己的内容。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await harness.coordinator.waitForState(.interrupted)
        try await harness.recognizer.waitForStartCount(2)

        if let oldStreamIndex {
            await harness.recognizer.emitFinal("机器人正在回答自己的内容", onStream: oldStreamIndex)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(chatClient.sentMessages, [])

        await harness.recognizer.emitPartial("帮我查黄金")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["帮我查黄金"])
    }

    func testUnverifiedVoiceActivityDuringPlaybackKeepsPlaybackActive() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .uncertain, score: 0.7, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("机器人正在回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.86,
            duration: 0.22,
            isAIPlaybackActive: true,
            source: .unknown,
            audioEvidence: SpeechAudioEvidence(pcm16MonoData: Data(repeating: 1, count: 32_000), sampleRate: 16_000, duration: 1)
        ))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.coordinator.state, .speaking)
        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "speaker uncertain")
    }

    func testPlaybackAudioEvidenceRequestDisablesSpeakerEnrollment() async throws {
        let chatClient = ControlledChatClient()
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(
            evidence: UserTurnSpeakerEvidence(match: .uncertain, score: 0.5, threshold: 0.82)
        )
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()

        await harness.coordinator.simulateAssistantSpeaking("这是机器人正在播放的回答。")
        try await harness.coordinator.waitForState(.speaking)
        await harness.recognizer.emitFinalWithAudioEvidence(
            "这是机器人正在播放的回答。",
            SpeechAudioEvidence(pcm16MonoData: Data(repeating: 0, count: 32_000), sampleRate: 16_000, duration: 1)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        let requests = await speakerEvidenceProvider.requestsSnapshot()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.isAssistantPlaybackActive, true)
        XCTAssertEqual(requests.first?.isInterruptedInput, false)
        XCTAssertEqual(requests.first?.allowsEnrollment, false)
        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.state, .speaking)
    }

    func testStablePartialSpeechSubmitsWithoutWaitingForFinalEvent() async throws {
        let harness = CoordinatorHarness(
            chatClient: ControlledChatClient(),
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.chatClient.sentMessages, ["Hello Aura"])
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "Hello Aura"
        })
    }

    func testFastPartialSubmitUsesLatestPartialText() async throws {
        let harness = CoordinatorHarness(
            chatClient: ControlledChatClient(),
            fastPartialSubmitDelayNanoseconds: 40_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("Hello")
        try await Task.sleep(nanoseconds: 10_000_000)
        await harness.recognizer.emitPartial("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.chatClient.sentMessages, ["Hello Aura"])
    }

    func testShortIncrementalPartialsWhileListeningDoNotDisplayOrSubmitPrefixes() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("1")
        try await Task.sleep(nanoseconds: 40_000_000)
        await harness.recognizer.emitPartial("12")
        try await Task.sleep(nanoseconds: 40_000_000)
        await harness.recognizer.emitPartial("123")
        try await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)

        await harness.recognizer.emitFinal("123")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["123"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["123"])
    }

    func testShortChineseLeadInFinalsMergeIntoFollowingQuestion() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("好的然后")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)

        await harness.recognizer.emitFinal("好的，然后当前。")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(chatClient.sentMessages, [])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 0)

        await harness.recognizer.emitFinal("呃业务价格是怎么样的?")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["好的，然后当前。呃业务价格是怎么样的?"])
        XCTAssertEqual(
            harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
            ["好的，然后当前。呃业务价格是怎么样的?"]
        )
    }

    func testDuplicateFinalAfterFastPartialSubmitDoesNotResendSameUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("帮我查黄金")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("帮我查黄金")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["帮我查黄金"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 1)
    }

    func testPunctuatedChineseFinalAfterFastPartialSubmitCorrectsExistingUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("嘿晚上好啊")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("嘿，晚上好啊。")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["嘿晚上好啊"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["嘿，晚上好啊。"])
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
    }

    func testASRRevisionsWhileThinkingUpdateOneUserBubble() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000,
            interruptedPartialSubmitDelayNanoseconds: 120_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("呃我想看一下")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitPartial("我想看一下那个 x")
        try await Task.sleep(nanoseconds: 50_000_000)
        await harness.recognizer.emitFinal("我想看一下那个 X 的股票。")
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["呃我想看一下"])
        XCTAssertEqual(
            harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
            ["我想看一下那个 X 的股票。"]
        )
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
    }

    func testSlowAssistantResponseUpdatesLatencyStatusBeforeFirstToken() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            assistantResponseStartTimeoutNanoseconds: 30_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("嘿晚上好")
        try await harness.coordinator.waitForState(.thinking)
        try await Task.sleep(nanoseconds: 60_000_000)

        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(harness.coordinator.lastLatencyDebugText, "assistant response delayed")

        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("晚上好"))
        try await harness.coordinator.waitForState(.speaking)

        XCTAssertTrue(harness.coordinator.lastLatencyDebugText.contains("assistant response start"))
    }

    func testStalledAssistantResponseTimesOutBeforeFirstToken() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            assistantResponseStartTimeoutNanoseconds: 20_000_000,
            assistantResponseHardTimeoutNanoseconds: 60_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("嘿晚上好")
        try await harness.coordinator.waitForState(.thinking)
        try await harness.coordinator.waitForState(.error(.chatResponseTimedOut), timeout: 1)

        XCTAssertEqual(harness.coordinator.lastLatencyDebugText, "assistant response timed out")
    }

    func testExtendedFinalAfterFastPartialSubmitCorrectsCurrentUserTurnWithoutResending() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("帮我查黄金")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("帮我查黄金和英伟达")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["帮我查黄金"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 1)
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "帮我查黄金和英伟达"
        })
    }

    func testDelayedFinalAfterFastPartialSubmitCorrectsTurnAfterReturningToListening() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("呃第194题早上当前是什么问题女生收件时")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("呃第194题早上当前是什么问题女生收件时想起来关于")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["呃第194题早上当前是什么问题女生收件时"])
        XCTAssertEqual(
            harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
            ["呃第194题早上当前是什么问题女生收件时想起来关于"]
        )
        XCTAssertEqual(harness.coordinator.state, .listening)
    }

    func testOverlappingFinalAfterFastPartialSubmitDoesNotDuplicateSharedText() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("eating we eating me")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("eating me he say kidding me")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["eating we eating me"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 1)
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "eating we eating me he say kidding me"
        })
    }

    func testRepeatedFinalRecognitionCollapsesDuplicateUserUtterance() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal(
            "今天天气不错 那我们今天推荐哪只股票 今天天气不错 那我们今天推荐哪只股票"
        )
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["今天天气不错 那我们今天推荐哪只股票"])
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "今天天气不错 那我们今天推荐哪只股票"
        })
    }

    func testShortRepeatedChineseFinalRecognitionCollapsesDuplicateUserUtterance() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("呢我想看一下那个 呢，我想看一下那个。")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["呢我想看一下那个"])
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "呢我想看一下那个"
        })
    }

    func testChinesePartialFinalRevisionUpdatesOneUserTurnWithoutDuplicateBubble() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitPartial("呢我想看")
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertTrue(chatClient.sentMessages.isEmpty)
        await harness.recognizer.emitFinal("呢，我想看看英伟达的股票")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["呢，我想看看英伟达的股票"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), [
            "呢，我想看看英伟达的股票"
        ])
    }

    func testAssistantTokenTransitionsFromThinkingToSpeaking() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("Hi"))
        try await harness.coordinator.waitForState(.speaking)

        XCTAssertEqual(harness.coordinator.activeAssistantText, "Hi")
        let containsStreamingAssistant = harness.coordinator.messages.contains { message in
            message.id == "bot-chat-1" &&
            message.role == .assistant &&
            message.displayText == "Hi" &&
            message.deliveryState == .streaming
        }
        let enqueuedTexts = await harness.playback.enqueuedTextsSnapshot()
        XCTAssertTrue(containsStreamingAssistant)
        XCTAssertEqual(enqueuedTexts, ["Hi"])
    }

    func testAssistantResponseStartRecordsLatencyDebugText() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("Hi"))
        try await harness.coordinator.waitForState(.speaking)

        XCTAssertTrue(harness.coordinator.lastLatencyDebugText.contains("assistant response start"))
    }

    func testNonEchoPartialDuringAssistantPlaybackInterruptsWithoutSpeakerVerification() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("Long answer"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitPartial("等等 我想问英伟达")
        try await harness.coordinator.waitForState(.recognizing(partialText: "等等 我想问英伟达"))
        try await harness.chatClient.waitForSentMessageCount(2)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        let clearCount = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question", "等等 我想问英伟达"])
    }

    func testRecognitionFinalDuringAssistantPlaybackInterruptsWhenNotEcho() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("Long answer"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitFinal("Stop and answer this")
        try await harness.coordinator.waitForState(.thinking)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question", "Stop and answer this"])
    }

    func testVoiceActivityDuringAssistantPlaybackInterruptsBeforeRecognitionText() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("Long answer still playing"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitVoiceActivity(inputLevel: 0.8, duration: 0.12)
        try await harness.coordinator.waitForState(.interrupted)

        let cancelCountAfterActivity = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCountAfterActivity, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question"])

        await harness.recognizer.emitPartial("Actually answer this")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.chatClient.sentMessages, ["First question", "Actually answer this"])
    }

    func testVerifiedPlaybackBargeInKeepsSpeakerEnabledAndSubmitsOnlyUserSpeech() async throws {
        let chatClient = ControlledChatClient()
        let verifiedEvidence = UserTurnSpeakerEvidence(match: .verifiedCurrentUser, score: 0.93, threshold: 0.82)
        let speakerEvidenceProvider = RecordingSpeakerEvidenceProvider(evidence: verifiedEvidence)
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            submissionGate: SpeakerProfileUserTurnSubmissionGate(),
            speakerEvidenceProvider: speakerEvidenceProvider
        )
        try await harness.coordinator.startCall()
        XCTAssertTrue(harness.coordinator.isSpeakerEnabled)

        await harness.recognizer.emitFinalWithEvidence("先解释一下英伟达", verifiedEvidence)
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("英伟达目前的核心问题是估值和增长预期。"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.7,
            duration: 0.4,
            isAIPlaybackActive: true,
            source: .currentUser,
            audioEvidence: SpeechAudioEvidence(
                pcm16MonoData: Data(repeating: 1, count: 16_000),
                sampleRate: 16_000,
                duration: 0.5
            )
        ))
        try await harness.coordinator.waitForState(.interrupted)

        await harness.recognizer.emitFinalWithEvidence(
            "等一下我想看英伟达的股票",
            verifiedEvidence
        )
        try await harness.coordinator.waitForState(.thinking)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertTrue(harness.coordinator.isSpeakerEnabled)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(chatClient.sentMessages, [
            "先解释一下英伟达",
            "等一下我想看英伟达的股票"
        ])
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText.contains("估值和增长预期")
        })
    }

    func testVoiceActivityAfterAssistantStreamCompletionStillCancelsAudiblePlayback() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("我在这儿，您想看哪个标的？"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitVoiceActivity(inputLevel: 0.8, duration: 0.12)
        try await harness.coordinator.waitForState(.interrupted)

        let cancelCountAfterActivity = await harness.playback.cancelCountSnapshot()
        let clearCountAfterActivity = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(cancelCountAfterActivity, 1)
        XCTAssertEqual(clearCountAfterActivity, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(harness.chatClient.sentMessages, ["看一下行情"])

        await harness.recognizer.emitPartial("我想看一下那个")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.chatClient.sentMessages, ["看一下行情", "我想看一下那个"])
    }

    func testAssistantStreamCompletionWaitsForPlaybackDrainBeforeListening() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)

        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("我在这儿，您想看哪个标的？"))
        try await harness.coordinator.waitForState(.speaking)
        chatClient.yield(.completed)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.coordinator.state, .speaking)

        await harness.playback.emit(.drained)
        try await harness.coordinator.waitForState(.listening)
    }

    func testAssistantEchoPartialDoesNotInterruptPlaybackOrSendChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("好的 我来解释这个问题"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitPartial("好的 我来解释")
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question"])
    }

    func testLocalResponsePreludeStartsAfterUserTurnWithoutAssistantMessage() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false,
            localResponsePreludes: ["好的 我来看看"]
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("帮我看一下今天英伟达")
        try await harness.coordinator.waitForState(.thinking)
        try await Task.sleep(nanoseconds: 50_000_000)

        let enqueuedTexts = await harness.playback.enqueuedTextsSnapshot()
        XCTAssertEqual(enqueuedTexts, ["好的 我来看看"])
        XCTAssertEqual(harness.chatClient.sentMessages, ["帮我看一下今天英伟达"])
        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(harness.coordinator.lastLatencyDebugText, "user turn submitted")
        XCTAssertFalse(harness.coordinator.messages.contains { message in
            message.role == .assistant && message.displayText == "好的 我来看看"
        })

        await harness.recognizer.emitPartial("好的 我来看看")
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
        XCTAssertEqual(harness.chatClient.sentMessages, ["帮我看一下今天英伟达"])
    }

    func testLocalResponsePreludeDoesNotMaskBackendTimeout() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            assistantResponseStartTimeoutNanoseconds: 20_000_000,
            assistantResponseHardTimeoutNanoseconds: 70_000_000,
            playbackAutoDrains: false,
            localResponsePreludes: ["好的 我来看看"]
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("你好早上好")
        try await harness.coordinator.waitForState(.thinking)
        try await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(harness.coordinator.lastLatencyDebugText, "assistant response delayed")

        try await harness.coordinator.waitForState(.error(.chatResponseTimedOut), timeout: 1)
        XCTAssertEqual(harness.coordinator.lastLatencyDebugText, "assistant response timed out")
    }

    func testUserCanInterruptLocalResponsePrelude() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000,
            playbackAutoDrains: false,
            localResponsePreludes: ["好的 我来看看"]
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("帮我看一下今天英伟达")
        try await harness.coordinator.waitForState(.thinking)
        try await Task.sleep(nanoseconds: 50_000_000)

        await harness.recognizer.emitPartial("等等 先看特斯拉")
        try await harness.coordinator.waitForState(.recognizing(partialText: "等等 先看特斯拉"))
        try await harness.chatClient.waitForSentMessageCount(2)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        let clearCount = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(harness.chatClient.sentMessages, ["帮我看一下今天英伟达", "等等 先看特斯拉"])
    }

    func testAssistantEchoFinalDoesNotInterruptPlaybackOrSendChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("今天我们先看成本和风险"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitFinal("我们先看成本和风险")
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question"])
    }

    func testAssistantEchoWithSmallFillerPrefixDoesNotInterruptPlaybackOrSendChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("早上好，您想听今天的行情吗？"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitFinal("哦 早上好 你想要听到今天行情吗")
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(harness.chatClient.sentMessages, ["First question"])
    }

    func testAssistantEchoAfterStreamCompletedDoesNotCreateUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("我在。您想先看黄金，还是先看英伟达的情况？"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitPartial("我在你想先看黄金还是先看英")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
        XCTAssertEqual(harness.chatClient.sentMessages, ["看一下行情"])
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText.contains("我在你想先看黄金")
        })
    }

    func testPostPlaybackAssistantPromptEchoDoesNotCreateUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("开始")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.final(
            displayText: "您好。今天想看哪只标的，或想聊哪个问题？",
            voiceText: "您好。今天想看哪只标的，或想聊哪个问题？",
            intent: "chat"
        ))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("今天想看哪只标的或想聊哪个问题")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["开始"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["开始"])
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testPostPlaybackDisplayTextEchoIsRejectedWhenVoiceTextDiffers() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("开始")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.final(
            displayText: "您好。今天想看哪只标的，或想聊哪个问题？",
            voiceText: "您好。",
            intent: "chat"
        ))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("今天想看哪只标的或想聊哪个问题")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["开始"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText), ["开始"])
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testRecentAssistantTailEchoWhileThinkingDoesNotCreateUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("确认一下")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.final(
            displayText: "您想确认不是全部条件，而是特定的一些。请告诉我具体是哪些条件，我来帮您确认。",
            voiceText: "您想确认不是全部条件，而是特定的一些。请告诉我具体是哪些条件，我来帮您确认。",
            intent: "chat"
        ))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("我只想确认其中几个条件")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("请告诉我具体是哪些条件我来帮您确认")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["确认一下", "我只想确认其中几个条件"])
        XCTAssertEqual(
            harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
            ["确认一下", "我只想确认其中几个条件"]
        )
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testDelayedAssistantTailEchoBeyondShortMemoryDoesNotCreateUserTurn() async throws {
        let chatClient = ControlledChatClient()
        let clock = MutableTestClock()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            dateProvider: { clock.now }
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("确认一下")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.final(
            displayText: "您想确认不是全部条件，而是特定的一些。请告诉我具体是哪些条件，我来帮您确认。",
            voiceText: "您想确认不是全部条件，而是特定的一些。请告诉我具体是哪些条件，我来帮您确认。",
            intent: "chat"
        ))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        clock.advance(by: 20)
        await harness.recognizer.emitFinal("请告诉我具体是哪些条件我来帮您确认")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["确认一下"])
        XCTAssertEqual(
            harness.coordinator.messages.filter { $0.role == .user }.map(\.displayText),
            ["确认一下"]
        )
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected echo")
    }

    func testShortUserAnswerAfterAssistantPromptIsNotRejectedAsEcho() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您想先看黄金，还是先看英伟达的情况？"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("黄金")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(harness.coordinator.lastFilterResultText, "verification unavailable")
        XCTAssertEqual(harness.chatClient.sentMessages, ["看一下行情", "黄金"])
    }

    func testMixedUserSpeechAndAssistantEchoFinalKeepsOnlyUserPrefix() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您今天想先看黄金的行情，还是英伟达（NVDA）的市场动态？"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitPartial("您好早上好")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitFinal("您好早上好您今天想先看黄金的行情还是英伟达的市场动态 您好早上好您今天想先看黄金的行情还是英伟达的市场动态")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["看一下行情", "您好早上好"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText.contains("您今天想先看黄金")
        })
    }

    func testInterruptedFinalStripsAssistantPlaybackPrefixBeforeUserSpeech() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            playbackAutoDrains: false
        )
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下阿里巴巴")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您想继续说说还是先放放？我可以先帮你整理阿里巴巴的股价。"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitVoiceActivity(inputLevel: 0.12, duration: 0.15)
        try await harness.coordinator.waitForState(.interrupted)
        try await harness.recognizer.waitForStartCount(2)
        await harness.recognizer.emitFinal("您想继续说说还是先放放我想特别想了解一下那个关于阿里巴巴的股价")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, [
            "看一下阿里巴巴",
            "我想特别想了解一下那个关于阿里巴巴的股价"
        ])
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText.hasPrefix("您想继续说说还是先放放")
        })
    }

    func testLongUserAnswerSharingAssistantPromptTermsIsNotRejectedAsEcho() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("看一下行情")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您今天想先看黄金的行情，还是英伟达（NVDA）的市场动态？"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)

        await harness.recognizer.emitFinal("我想看黄金行情")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["看一下行情", "我想看黄金行情"])
    }

    func testRejectedNoiseDuringSpeakingDoesNotCancelPlaybackOrSendChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.coordinator.simulateAssistantSpeaking("Long answer")
        let sentCount = chatClient.sentMessages.count

        await harness.coordinator.simulateVoiceActivity(
            VoiceActivityEvent(
                inputLevel: 0.1,
                duration: 0.8,
                isAIPlaybackActive: true,
                source: .environmentNoise
            ),
            speakerHint: .unknown,
            text: "background noise"
        )

        let cancelCount = await harness.playback.cancelCountSnapshot()
        let clearCount = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected noise")
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(clearCount, 0)
        XCTAssertEqual(chatClient.sentMessages.count, sentCount)
    }

    func testEnvironmentNoiseSuppressesFollowingRecognitionTextWithoutHoldingRecognizing() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitVoiceActivity(
            VoiceActivityEvent(
                inputLevel: 0.2,
                duration: 0.8,
                isAIPlaybackActive: false,
                source: .environmentNoise
            )
        )
        await harness.recognizer.emitPartial("背景里有人一直在说话")
        await harness.recognizer.emitFinal("背景里有人一直在说话")
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected noise")
        XCTAssertTrue(harness.coordinator.messages.isEmpty)
        XCTAssertTrue(chatClient.sentMessages.isEmpty)
    }

    func testOtherSpeakerFinalDoesNotHoldRecognizingOrSubmitChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            submissionGate: SpeakerProfileUserTurnSubmissionGate()
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinalWithEvidence(
            "旁边人在说话",
            UserTurnSpeakerEvidence(match: .otherSpeaker, score: 0.42, threshold: 0.84)
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "rejected other speaker")
        XCTAssertTrue(harness.coordinator.messages.isEmpty)
        XCTAssertTrue(chatClient.sentMessages.isEmpty)
    }

    func testUnavailableSpeakerVerificationDoesNotCancelPlaybackOrSendChat() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            bargeInGate: BargeInGate(
                voiceActivityDetector: LocalVoiceActivityDetector(),
                speakerVerifier: MockSpeakerVerifier(result: .unavailableInsufficientAudio)
            )
        )
        try await harness.coordinator.startCall()
        await harness.coordinator.simulateAssistantSpeaking("Long answer")

        await harness.coordinator.simulateVoiceActivity(
            VoiceActivityEvent(inputLevel: 0.8, duration: 0.8, isAIPlaybackActive: true),
            speakerHint: .unknown,
            text: "short user audio"
        )

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .speaking)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "verification unavailable")
        XCTAssertEqual(cancelCount, 0)
        XCTAssertTrue(chatClient.sentMessages.isEmpty)
    }

    func testEndCallCleansRecognizerPlaybackAndAudioSession() async throws {
        let harness = CoordinatorHarness()
        try await harness.coordinator.startCall()

        await harness.coordinator.endCall()

        XCTAssertEqual(harness.coordinator.state, .ended)
        let recognizerStopCount = await harness.recognizer.stopCountSnapshot()
        let playbackCancelCount = await harness.playback.cancelCountSnapshot()
        let playbackClearCount = await harness.playback.clearCountSnapshot()
        let audioEndCallCount = await harness.audio.endCallCountSnapshot()
        XCTAssertEqual(recognizerStopCount, 1)
        XCTAssertEqual(playbackCancelCount, 1)
        XCTAssertEqual(playbackClearCount, 1)
        XCTAssertEqual(audioEndCallCount, 1)
    }

    func testStaleStreamIsIgnoredAfterInterruptionStartsNewTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("First")
        try await harness.coordinator.waitForState(.thinking)
        let firstStream = try XCTUnwrap(chatClient.streams.last)
        firstStream.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        firstStream.yield(.assistantToken("Old"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.coordinator.simulateVoiceActivity(
            VoiceActivityEvent(
                inputLevel: 0.8,
                duration: 0.8,
                isAIPlaybackActive: true,
                source: .currentUser
            ),
            speakerHint: .currentUser,
            text: "Second"
        )
        try await harness.coordinator.waitForState(.thinking)
        let secondStream = try XCTUnwrap(chatClient.streams.last)
        firstStream.yield(.assistantToken(" stale"))
        secondStream.yield(.started(userChatID: "user-chat-2", botChatID: "bot-chat-2"))
        secondStream.yield(.assistantToken("New"))
        try await harness.coordinator.waitForAssistantText("New")

        XCTAssertEqual(harness.coordinator.activeAssistantText, "New")
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.id == "bot-chat-2" && $0.displayText.contains("stale")
        })
    }

    func testFinalSpeechWhileThinkingBeforeAssistantTokenSubmitsNewTurnWithoutPrependingPreviousTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        await harness.recognizer.emitFinal("Trailing fragment")
        try await chatClient.waitForSentMessageCount(2)

        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(chatClient.sentMessages, ["First question", "Trailing fragment"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "First question Trailing fragment"
        })
    }

    func testPartialSpeechWhileThinkingBeforeAssistantTokenSubmitsNewTurnWithoutPrependingPreviousTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitPartial("with more context")
        try await harness.coordinator.waitForState(.recognizing(partialText: "with more context"))
        try await chatClient.waitForSentMessageCount(2)

        XCTAssertEqual(chatClient.sentMessages, ["First question", "with more context"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
        XCTAssertFalse(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "First question with more context"
        })
    }

    func testRepeatedPartialSpeechBeforeAssistantTokenKeepsLatestNewInputWithoutPrependingPreviousTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("第一句")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitPartial("第二句")
        try await harness.coordinator.waitForState(.recognizing(partialText: "第二句"))
        await harness.recognizer.emitPartial("第三句")
        try await harness.coordinator.waitForState(.recognizing(partialText: "第三句"))
        try await chatClient.waitForSentMessageCount(2)

        XCTAssertEqual(chatClient.sentMessages, ["第一句", "第三句"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.role == .user && $0.displayText == "第三句"
        })
    }

    func testVoiceActivityWhileThinkingCancelsPendingResponseBeforeRecognitionText() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitVoiceActivity(inputLevel: 0.8, duration: 0.12)
        try await harness.coordinator.waitForState(.interrupted)

        let cancelCountAfterActivity = await harness.playback.cancelCountSnapshot()
        let clearCountAfterActivity = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(cancelCountAfterActivity, 1)
        XCTAssertEqual(clearCountAfterActivity, 1)

        await harness.recognizer.emitPartial("New question")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentMessages, ["First question", "New question"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
    }

    func testIncrementalPartialsWhileThinkingDoNotSubmitEachPrefixAsSeparateUserMessages() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            fastPartialSubmitDelayNanoseconds: 20_000_000,
            interruptedPartialSubmitDelayNanoseconds: 250_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("先问一下")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitPartial("呃我今天想")
        try await Task.sleep(nanoseconds: 80_000_000)
        await harness.recognizer.emitPartial("呃我今天想看一下")
        try await Task.sleep(nanoseconds: 80_000_000)
        await harness.recognizer.emitPartial("呃我今天想看一下那个")
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(chatClient.sentMessages, ["先问一下"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "呃我今天想看一下那个")

        await harness.recognizer.emitFinal("呃，我今天想看一下那个。")
        try await chatClient.waitForSentMessageCount(2)

        XCTAssertEqual(chatClient.sentMessages, ["先问一下", "呃，我今天想看一下那个。"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 2)
    }

    func testLowLevelVoiceActivityWhileThinkingDoesNotEnterInterruptedState() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitVoiceActivity(inputLevel: 0.04, duration: 0.12)
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCountAfterActivity = await harness.playback.cancelCountSnapshot()
        let clearCountAfterActivity = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(cancelCountAfterActivity, 0)
        XCTAssertEqual(clearCountAfterActivity, 0)
        XCTAssertEqual(chatClient.sentMessages, ["First question"])
    }

    func testUnknownShortVoiceActivityWhileThinkingDoesNotEnterInterruptedState() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        await harness.recognizer.emitVoiceActivity(VoiceActivityEvent(
            inputLevel: 0.5,
            duration: 0.05,
            isAIPlaybackActive: true,
            source: .unknown
        ))
        try await Task.sleep(nanoseconds: 50_000_000)

        let cancelCountAfterActivity = await harness.playback.cancelCountSnapshot()
        let clearCountAfterActivity = await harness.playback.clearCountSnapshot()
        XCTAssertEqual(harness.coordinator.state, .thinking)
        XCTAssertEqual(cancelCountAfterActivity, 0)
        XCTAssertEqual(clearCountAfterActivity, 0)
        XCTAssertEqual(chatClient.sentMessages, ["First question"])
    }

    func testAudioOnlyInterruptionWithoutRecognitionReturnsToListening() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(
            chatClient: chatClient,
            audioOnlyInterruptionTimeoutNanoseconds: 50_000_000
        )
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("先解释一下")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("好的 我先介绍这个方案的背景和成本"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.recognizer.emitVoiceActivity(inputLevel: 0.8, duration: 0.5)
        try await harness.coordinator.waitForState(.interrupted)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(harness.coordinator.state, .listening)
        XCTAssertEqual(harness.coordinator.activeUserPartialText, "")
        XCTAssertEqual(chatClient.sentMessages, ["先解释一下"])
        XCTAssertEqual(harness.coordinator.messages.filter { $0.role == .user }.count, 1)
    }

    func testExplicitVoiceActivityInterruptionStopsPlaybackAndSubmitsTurn() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()
        await harness.recognizer.emitFinal("先解释一下")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("好的 我先介绍这个方案的背景和成本"))
        try await harness.coordinator.waitForState(.speaking)

        await harness.coordinator.simulateVoiceActivity(
            VoiceActivityEvent(
                inputLevel: 0.8,
                duration: 0.8,
                isAIPlaybackActive: true,
                source: .currentUser
            ),
            speakerHint: .currentUser,
            text: "等一下 先回答我刚才的问题"
        )
        try await harness.coordinator.waitForState(.thinking)
        try await Task.sleep(nanoseconds: 10_000_000)

        let cancelCount = await harness.playback.cancelCountSnapshot()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(harness.coordinator.lastFilterResultText, "accepted")
        XCTAssertEqual(chatClient.sentMessages, ["先解释一下", "等一下 先回答我刚才的问题"])
    }

    func testFinalEventCompletesTranscriptWithoutRepeatingAlreadyStreamedSpeech() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您好。"))
        chatClient.yield(.final(displayText: "您好。", voiceText: "您好。", intent: "chat"))
        try await harness.coordinator.waitForState(.speaking)

        let enqueuedTexts = await harness.playback.enqueuedTextsSnapshot()
        XCTAssertEqual(enqueuedTexts, ["您好。"])
        XCTAssertTrue(harness.coordinator.messages.contains {
            $0.id == "bot-chat-1" && $0.displayText == "您好。" && $0.deliveryState == .complete
        })
    }

    func testFinalEventFlushesUnpunctuatedStreamedSpeechWithoutRepeatingFullAnswer() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("Hello Aura")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.assistantToken("您好"))
        chatClient.yield(.final(displayText: "您好", voiceText: "您好", intent: "chat"))
        try await harness.coordinator.waitForState(.speaking)

        let enqueuedTexts = await harness.playback.enqueuedTextsSnapshot()
        XCTAssertEqual(enqueuedTexts, ["您好"])
        let finalFlags = await harness.playback.finalFlagsSnapshot()
        XCTAssertEqual(finalFlags, [false, true])
    }

    func testMultipleTurnsReuseSameConversationIDForBackendMemory() async throws {
        let chatClient = ControlledChatClient()
        let harness = CoordinatorHarness(chatClient: chatClient)
        try await harness.coordinator.startCall()

        await harness.recognizer.emitFinal("First question")
        try await harness.coordinator.waitForState(.thinking)
        chatClient.yield(.started(userChatID: "user-chat-1", botChatID: "bot-chat-1"))
        chatClient.yield(.completed)
        try await harness.coordinator.waitForState(.listening)
        await harness.recognizer.emitFinal("What did I just ask?")
        try await harness.coordinator.waitForState(.thinking)

        XCTAssertEqual(chatClient.sentConversations.map(\.cid), ["conversation-1", "conversation-1"])
        XCTAssertEqual(chatClient.sentMessages, ["First question", "What did I just ask?"])
    }
}

@MainActor
private final class CoordinatorHarness {
    let recognizer: TestSpeechRecognizer
    let playback: RecordingPlaybackController
    let audio: RecordingAudioSessionManager
    let chatClient: ControlledChatClient
    let coordinator: VoiceCallCoordinator

    init(
        chatClient: ControlledChatClient = ControlledChatClient(),
        bargeInGate: BargeInGate = BargeInGate(),
        fastPartialSubmitDelayNanoseconds: UInt64 = 450_000_000,
        interruptedPartialSubmitDelayNanoseconds: UInt64 = 700_000_000,
        audioOnlyInterruptionTimeoutNanoseconds: UInt64 = 900_000_000,
        assistantResponseStartTimeoutNanoseconds: UInt64 = 3_000_000_000,
        assistantResponseHardTimeoutNanoseconds: UInt64 = 15_000_000_000,
        playbackAutoDrains: Bool = true,
        submissionGate: any UserTurnSubmissionGating = AcceptingUserTurnSubmissionGate(),
        speakerEvidenceProvider: any UserTurnSpeakerEvidenceProviding = NoopUserTurnSpeakerEvidenceProvider(),
        localResponsePreludes: [String] = [],
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.recognizer = TestSpeechRecognizer()
        self.playback = RecordingPlaybackController(autoDrains: playbackAutoDrains)
        self.audio = RecordingAudioSessionManager()
        self.chatClient = chatClient
        self.coordinator = VoiceCallCoordinator(
            chatClient: chatClient,
            recognizer: recognizer,
            synthesizer: NoopSpeechSynthesizer(),
            playback: playback,
            audioSession: audio,
            conversationIDFactory: StaticConversationIDFactory(),
            bargeInGate: bargeInGate,
            submissionGate: submissionGate,
            speakerEvidenceProvider: speakerEvidenceProvider,
            dateProvider: dateProvider,
            fastPartialSubmitDelayNanoseconds: fastPartialSubmitDelayNanoseconds,
            interruptedPartialSubmitDelayNanoseconds: interruptedPartialSubmitDelayNanoseconds,
            audioOnlyInterruptionTimeoutNanoseconds: audioOnlyInterruptionTimeoutNanoseconds,
            assistantResponseStartTimeoutNanoseconds: assistantResponseStartTimeoutNanoseconds,
            assistantResponseHardTimeoutNanoseconds: assistantResponseHardTimeoutNanoseconds,
            localResponsePreludes: localResponsePreludes
        )
    }
}

@MainActor
private final class MutableTestClock {
    private(set) var now: Date = Date(timeIntervalSince1970: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private actor RecordingSpeakerEvidenceProvider: UserTurnSpeakerEvidenceProviding {
    private let evidence: UserTurnSpeakerEvidence?
    private var requests: [UserTurnSpeakerEvidenceRequest] = []

    init(evidence: UserTurnSpeakerEvidence?) {
        self.evidence = evidence
    }

    func evidence(for request: UserTurnSpeakerEvidenceRequest) async -> UserTurnSpeakerEvidence? {
        requests.append(request)
        return evidence
    }

    func requestsSnapshot() -> [UserTurnSpeakerEvidenceRequest] {
        requests
    }
}

private struct FixedUserTurnSubmissionGate: UserTurnSubmissionGating {
    let decision: UserTurnSubmissionDecision

    func evaluate(_ candidate: UserTurnSubmissionCandidate) -> UserTurnSubmissionDecision {
        decision
    }
}

private final class ControlledChatClient: ChatClient {
    private(set) var sentMessages: [String] = []
    private(set) var sentConversations: [ConversationContext] = []
    private(set) var streams: [ControlledChatStream] = []

    func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        sentMessages.append(text)
        sentConversations.append(conversation)
        let stream = ControlledChatStream()
        streams.append(stream)
        return stream.stream
    }

    func yield(_ update: ChatStreamUpdate) {
        streams.last?.yield(update)
    }

    func waitForSentMessageCount(_ count: Int, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while sentMessages.count < count {
            if Date() > deadline {
                XCTFail("Timed out waiting for \(count) sent messages; got \(sentMessages)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class ControlledChatStream {
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

    func finish() {
        continuation.finish()
    }
}

private actor TestSpeechRecognizer: SpeechRecognizing {
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    private var continuations: [AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation] = []
    private var activeStreamIndex: Int?
    private var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0

    func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            self.continuations.append(continuation)
            self.activeStreamIndex = self.continuations.count - 1
        }
    }

    func start() async throws {
        isRunning = true
        startCount += 1
    }

    func stop() async {
        isRunning = false
        stopCount += 1
    }

    func cancel() async {
        isRunning = false
        cancelCount += 1
    }

    func emitPartial(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.partial(text))
    }

    func emitFinal(_ text: String) {
        guard isRunning else { return }
        continuation?.yield(.final(text))
    }

    func emitFinal(_ text: String, onStream streamIndex: Int) {
        guard continuations.indices.contains(streamIndex) else { return }
        continuations[streamIndex].yield(.final(text))
    }

    func emitFinalWithEvidence(_ text: String, _ evidence: UserTurnSpeakerEvidence) {
        guard isRunning else { return }
        continuation?.yield(.finalWithEvidence(text, evidence))
    }

    func emitFinalWithAudioEvidence(_ text: String, _ audioEvidence: SpeechAudioEvidence) {
        guard isRunning else { return }
        continuation?.yield(.finalWithAudioEvidence(text, audioEvidence))
    }

    func emitVoiceActivity(inputLevel: Double, duration: TimeInterval) {
        guard isRunning else { return }
        continuation?.yield(.voiceActivity(VoiceActivityEvent(
            inputLevel: inputLevel,
            duration: duration,
            isAIPlaybackActive: true,
            source: .currentUser
        )))
    }

    func emitVoiceActivity(_ event: VoiceActivityEvent) {
        guard isRunning else { return }
        continuation?.yield(.voiceActivity(event))
    }

    func startCountSnapshot() -> Int {
        startCount
    }

    func waitForStartCount(_ count: Int, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while startCount < count {
            if Date() > deadline {
                XCTFail("Timed out waiting for recognizer start count \(count); got \(startCount)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func stopCountSnapshot() -> Int {
        stopCount
    }

    func cancelCountSnapshot() -> Int {
        cancelCount
    }

    func activeStreamIndexSnapshot() -> Int? {
        activeStreamIndex
    }
}

private actor NoopSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String) async throws {}

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        SpeechSynthesisOutput(audioData: Data(), text: text)
    }

    func cancel() async {}
}

private actor RecordingPlaybackController: SpeechPlaybackControlling {
    private var enqueuedTexts: [String] = []
    private var finalFlags: [Bool] = []
    private(set) var cancelCount = 0
    private(set) var clearCount = 0
    private let autoDrains: Bool
    private var playbackContinuations: [AsyncStream<SpeechPlaybackEvent>.Continuation] = []

    init(autoDrains: Bool = true) {
        self.autoDrains = autoDrains
    }

    func playbackEvents() async -> AsyncStream<SpeechPlaybackEvent> {
        AsyncStream { continuation in
            self.addPlaybackContinuation(continuation)
        }
    }

    func enqueue(_ text: String, isFinal: Bool) async {
        if !text.isEmpty {
            enqueuedTexts.append(text)
            emit(.started(text))
            if autoDrains {
                emit(.finished(text))
            }
        }
        finalFlags.append(isFinal)
        if autoDrains {
            emit(.drained)
        }
    }

    func clear() async {
        clearCount += 1
        enqueuedTexts.removeAll()
    }

    func cancel() async {
        cancelCount += 1
        emit(.cancelled)
    }

    func enqueuedTextsSnapshot() -> [String] {
        enqueuedTexts
    }

    func finalFlagsSnapshot() -> [Bool] {
        finalFlags
    }

    func cancelCountSnapshot() -> Int {
        cancelCount
    }

    func clearCountSnapshot() -> Int {
        clearCount
    }

    func emit(_ event: SpeechPlaybackEvent) {
        playbackContinuations.forEach { $0.yield(event) }
    }

    private func addPlaybackContinuation(_ continuation: AsyncStream<SpeechPlaybackEvent>.Continuation) {
        playbackContinuations.append(continuation)
    }
}

private actor RecordingAudioSessionManager: AudioSessionManaging {
    private(set) var isSpeakerEnabled = true
    private(set) var startCallCount = 0
    private(set) var endCallCount = 0

    func startCall() async throws {
        startCallCount += 1
    }

    func endCall() async {
        endCallCount += 1
    }

    func setSpeakerEnabled(_ enabled: Bool) async throws {
        isSpeakerEnabled = enabled
    }

    func startCallCountSnapshot() -> Int {
        startCallCount
    }

    func endCallCountSnapshot() -> Int {
        endCallCount
    }
}

private struct StaticConversationIDFactory: ConversationIDProviding {
    func makeConversationContext() -> ConversationContext {
        ConversationContext(cid: "conversation-1", cidMD5: "cidmd5", userName: "test01", userID: 35)
    }
}

private extension VoiceCallCoordinator {
    func waitForState(_ expectedState: VoiceCallState, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while state != expectedState {
            if Date() > deadline {
                XCTFail("Timed out waiting for \(expectedState); got \(state)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func waitForAssistantText(_ expectedText: String, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while activeAssistantText != expectedText {
            if Date() > deadline {
                XCTFail("Timed out waiting for assistant text \(expectedText); got \(activeAssistantText)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
