import XCTest
import VoiceCore
@testable import AuraVoiceAssistant

@MainActor
final class VoiceCallViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = VoiceCallViewModel.preview(.idle)

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertFalse(viewModel.shouldShowCallScreen)
        XCTAssertEqual(viewModel.elapsedSeconds, 0)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertTrue(viewModel.isSpeakerEnabled)
    }

    func testRuntimeErrorDuringCallStaysOnCallScreen() {
        let viewModel = VoiceCallViewModel(
            state: .error(.speechRecognitionCanceled("network error")),
            elapsedSeconds: 4,
            messages: []
        )

        XCTAssertTrue(viewModel.shouldShowCallScreen)
    }

    func testThinkingStatusShowsSlowAssistantResponseDetail() {
        let viewModel = VoiceCallViewModel(
            state: .thinking,
            lastLatencyDebugText: "assistant response delayed"
        )

        XCTAssertEqual(viewModel.localizedStatusDetail(.localized(.english)), "Still waiting for Aura's response.")
        XCTAssertEqual(viewModel.localizedStatusDetail(.localized(.chinese)), "仍在等待 Aura 回复。")
    }

    func testDefaultCoordinatorConfiguresLocalResponsePrelude() {
        XCTAssertEqual(VoiceCallViewModel.defaultLocalResponsePreludes, ["好的 我来看看"])
    }

    func testErrorStatusShowsSpecificErrorDetail() {
        let viewModel = VoiceCallViewModel(state: .error(.chatResponseTimedOut))

        XCTAssertEqual(viewModel.localizedStatusTitle(.localized(.english)), "Needs attention")
        XCTAssertEqual(viewModel.localizedStatusDetail(.localized(.english)), "The chat backend response timed out.")
    }

    func testVoiceRootHidesTopHeaderDuringCall() {
        XCTAssertTrue(VoiceRootView.shouldShowTopHeader(for: VoiceCallViewModel.preview(.idle)))
        XCTAssertFalse(VoiceRootView.shouldShowTopHeader(for: VoiceCallViewModel.preview(.listening)))
    }

    func testInCallTopPaddingClearsDynamicIslandSafeArea() {
        XCTAssertEqual(
            InCallView.topContentPadding(topSafeAreaInset: 59, compact: false),
            83
        )
        XCTAssertEqual(
            InCallView.topContentPadding(topSafeAreaInset: 50, compact: true),
            66
        )
    }

    func testBottomNavigationUsesCompactHeight() {
        XCTAssertEqual(ContentView.bottomNavigationHeight, 52)
        XCTAssertEqual(BottomNavigationBar.primaryItemSize, 42)
        XCTAssertEqual(BottomNavigationBar.secondaryItemSize, 36)
    }

    func testVoiceTabUsesPhoneIconAndDoesNotStartCall() {
        XCTAssertEqual(AppTab.voice.icon, "phone.fill")
        XCTAssertFalse(BottomNavigationBar.shouldStartCall(whenSelecting: .voice))
        XCTAssertFalse(BottomNavigationBar.shouldStartCall(whenSelecting: .history))
        XCTAssertFalse(BottomNavigationBar.shouldStartCall(whenSelecting: .settings))
    }

    func testVoiceOrbUsesPhoneIconBeforeCall() {
        XCTAssertEqual(VoiceOrbView.symbolName(for: .idle), "phone.fill")
        XCTAssertEqual(VoiceOrbView.symbolName(for: .listening), "waveform")
    }

    func testStartCallTransitionsToListeningWithMockConversation() {
        let viewModel = VoiceCallViewModel.preview(.idle)

        viewModel.startCall()

        XCTAssertEqual(viewModel.state, .listening)
        XCTAssertFalse(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.activeUserPartialText, "")
    }

    func testDebugTextDrivesThinkingAndAssistantResponse() {
        let viewModel = VoiceCallViewModel.preview(.listening)

        viewModel.sendTextForDebug("What is next?")

        XCTAssertEqual(viewModel.state, .speaking)
        XCTAssertTrue(viewModel.messages.contains { $0.role == .user && $0.displayText == "What is next?" })
        XCTAssertFalse(viewModel.activeAssistantText.isEmpty)
    }

    func testDebugTextPersistsLocalConversation() throws {
        let store = VoiceCallTestConversationStore()
        let viewModel = VoiceCallViewModel(state: .listening, historyStore: store)

        viewModel.sendTextForDebug("Remember this locally")

        let conversations = try store.loadConversations()
        XCTAssertEqual(conversations.first?.title, "Remember this locally")
        XCTAssertTrue(try store.loadMessages(conversationID: MockData.conversationID).contains {
            $0.role == .user && $0.displayText == "Remember this locally"
        })
    }

    func testSimulateSpeechFinalPublishesRecognitionEvent() {
        let viewModel = VoiceCallViewModel.preview(.listening)

        viewModel.simulateSpeechFinal("模拟用户说话")

        XCTAssertEqual(viewModel.lastSpeechRecognitionEvent, .final("模拟用户说话"))
        XCTAssertTrue(viewModel.messages.contains { $0.role == .user && $0.displayText == "模拟用户说话" })
        XCTAssertEqual(viewModel.state, .speaking)
    }

    func testSimulatedUserBargeInCreatesNewTurnWhenSpeaking() async {
        let viewModel = VoiceCallViewModel.preview(.speaking)
        let originalCount = viewModel.messages.count

        await viewModel.simulateUserBargeInForDebug()

        XCTAssertEqual(viewModel.lastFilterResultText, "accepted")
        XCTAssertEqual(viewModel.state, .speaking)
        XCTAssertGreaterThan(viewModel.messages.count, originalCount)
    }

    func testSimulatedNoiseDoesNotCreateNewTurnWhenSpeaking() async {
        let viewModel = VoiceCallViewModel.preview(.speaking)
        let originalCount = viewModel.messages.count

        await viewModel.simulateEnvironmentNoiseForDebug()

        XCTAssertEqual(viewModel.lastFilterResultText, "rejected noise")
        XCTAssertEqual(viewModel.messages.count, originalCount)
    }

    func testSimulatedOtherSpeakerDoesNotCreateNewTurnWhenSpeaking() async {
        let viewModel = VoiceCallViewModel.preview(.speaking)
        let originalCount = viewModel.messages.count

        await viewModel.simulateOtherSpeakerForDebug()

        XCTAssertEqual(viewModel.lastFilterResultText, "rejected other speaker")
        XCTAssertEqual(viewModel.messages.count, originalCount)
    }
}

private final class VoiceCallTestConversationStore: ConversationStoring {
    var records: [StoredConversation] = []

    func loadConversations() throws -> [Conversation] {
        records.map(\.conversation)
    }

    func loadMessages(conversationID: String) throws -> [ChatMessage] {
        records.first { $0.conversation.id == conversationID }?.messages ?? []
    }

    func upsertConversation(id: String, cidMD5: String, messages: [ChatMessage], elapsedSeconds: Int) throws {
        records.removeAll { $0.conversation.id == id }
        records.append(StoredConversation(
            conversation: Conversation(
                id: id,
                cidMD5: cidMD5,
                title: messages.first?.displayText ?? "",
                preview: messages.last?.displayText ?? "",
                updatedAt: messages.last?.createdAt ?? Date(),
                durationText: nil
            ),
            messages: messages
        ))
    }
}
