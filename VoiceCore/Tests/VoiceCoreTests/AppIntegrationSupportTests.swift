import XCTest
@testable import VoiceCore

final class AppIntegrationSupportTests: XCTestCase {
    func testConversationContextSupportsAppFacingUsernameAlias() {
        let context = ConversationContext(
            cid: "CID-1",
            cidMD5: "abc123def4567890",
            username: "test01",
            userID: 35
        )

        XCTAssertEqual(context.userName, "test01")
        XCTAssertEqual(context.username, "test01")
    }

    func testPageModelsExposeAppFacingCollectionAliasesAndHasMore() {
        let conversation = Conversation(
            id: "CID-1",
            cidMD5: "abc123def4567890",
            title: "Title",
            preview: "Preview",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let message = ChatMessage(
            id: "CHAT-1",
            conversationID: "CID-1",
            role: .user,
            displayText: "Hi",
            createdAt: Date(timeIntervalSince1970: 0),
            deliveryState: .complete
        )

        let historyPage = HistoryPage(items: [conversation], page: 1, pageSize: 1, total: 2)
        let messagePage = MessagePage(items: [message], page: 0, pageSize: 1, total: 1)

        XCTAssertEqual(historyPage.conversations, [conversation])
        XCTAssertTrue(historyPage.hasMore)
        XCTAssertEqual(messagePage.messages, [message])
        XCTAssertFalse(messagePage.hasMore)
    }

    func testVoiceCallStateSnapshotSupportsAppFacingFields() {
        let snapshot = VoiceCallStateSnapshot(stateLabel: "Listening", elapsedSeconds: 42)

        XCTAssertEqual(snapshot.stateName, "Listening")
        XCTAssertEqual(snapshot.stateLabel, "Listening")
        XCTAssertEqual(snapshot.elapsedSeconds, 42)
        XCTAssertTrue(VoiceCallState.listening.isActiveCall)
        XCTAssertFalse(VoiceCallState.idle.isActiveCall)
    }

    func testServiceContainerCreatesLiveAndMockClientsFromConfiguration() {
        let configuration = VoiceCoreServiceConfiguration(
            chatWebSocketURL: URL(string: "ws://example.com/ws")!,
            historyListURL: URL(string: "http://example.com/history")!,
            historyMessagesURL: URL(string: "http://example.com/messages")!,
            userName: "qa",
            userID: 42,
            useMocks: false
        )

        let live = AppServices.make(configuration: configuration)
        let mock = AppServices.make(configuration: VoiceCoreServiceConfiguration(useMocks: true))

        XCTAssertTrue(live.chatClient is ChatWebSocketClient)
        XCTAssertTrue(live.historyClient is HistoryService)
        XCTAssertTrue(mock.chatClient is MockChatClient)
        XCTAssertTrue(mock.historyClient is MockHistoryClient)
        XCTAssertEqual(live.idFactory.makeConversationContext().userName, "qa")
    }

    func testDefaultServiceEndpointsUseDebugPort6007() {
        let configuration = VoiceCoreServiceConfiguration()

        XCTAssertEqual(configuration.chatWebSocketURL.port, 6007)
        XCTAssertEqual(configuration.historyListURL.port, 6007)
        XCTAssertEqual(configuration.historyMessagesURL.port, 6007)
        XCTAssertEqual(configuration.chatWebSocketURL.host, "43.98.164.20")
        XCTAssertEqual(configuration.historyListURL.host, "43.98.164.20")
        XCTAssertEqual(configuration.historyMessagesURL.host, "43.98.164.20")
    }
}
