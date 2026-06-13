import XCTest
import SwiftUI
import VoiceCore
@testable import AuraVoiceAssistant

@MainActor
final class HistoryListViewModelTests: XCTestCase {
    func testLoadFirstPageReadsLocalStoredConversations() {
        let store = InMemoryConversationStore()
        let conversation = Conversation(
            id: "local-cid-1",
            cidMD5: "local-md5-1",
            title: "Local call",
            preview: "Saved transcript",
            updatedAt: Date(timeIntervalSince1970: 100),
            durationText: "12s"
        )
        store.records = [
            StoredConversation(conversation: conversation, messages: [
                ChatMessage(
                    id: "local-message-1",
                    conversationID: "local-cid-1",
                    role: .user,
                    displayText: "Saved transcript",
                    createdAt: Date(timeIntervalSince1970: 100),
                    deliveryState: .complete
                )
            ])
        ]

        let viewModel = HistoryListViewModel(store: store)

        viewModel.loadFirstPage()

        XCTAssertEqual(viewModel.conversations, [conversation])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSearchFiltersTitleAndPreview() {
        let store = InMemoryConversationStore()
        store.records = [
            StoredConversation(
                conversation: Conversation(
                    id: "local-recipe",
                    cidMD5: "local-recipe-md5",
                    title: "Recipe Assistance",
                    preview: "Spinach dinner idea",
                    updatedAt: Date(timeIntervalSince1970: 200),
                    durationText: nil
                ),
                messages: []
            )
        ]
        let viewModel = HistoryListViewModel(store: store)
        viewModel.loadFirstPage()

        viewModel.searchText = "recipe"

        XCTAssertEqual(viewModel.filteredConversations.map(\.title), ["Recipe Assistance"])
    }

    func testFailureStateSurfacesErrorMessage() {
        let viewModel = HistoryListViewModel(store: FailingConversationStore())

        viewModel.loadFirstPage()

        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Unable to load local history.")
    }

    func testMessageListLoadsMessagesFromLocalStore() {
        let store = InMemoryConversationStore()
        let conversation = Conversation(
            id: "local-cid-2",
            cidMD5: "local-md5-2",
            title: "Stored detail",
            preview: "Message detail",
            updatedAt: Date(timeIntervalSince1970: 300),
            durationText: nil
        )
        let message = ChatMessage(
            id: "detail-message-1",
            conversationID: "local-cid-2",
            role: .assistant,
            displayText: "Loaded from local storage.",
            createdAt: Date(timeIntervalSince1970: 301),
            deliveryState: .complete
        )
        store.records = [StoredConversation(conversation: conversation, messages: [message])]

        let viewModel = MessageListViewModel(conversation: conversation, store: store)

        viewModel.loadFirstPage()

        XCTAssertEqual(viewModel.messages, [message])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testHistoryListSelectionPublishesSelectedConversation() {
        let conversation = Conversation(
            id: "local-cid-3",
            cidMD5: "local-md5-3",
            title: "Selectable detail",
            preview: "Tap opens detail",
            updatedAt: Date(timeIntervalSince1970: 400),
            durationText: nil
        )
        var selectedConversation: Conversation?

        HistoryListView.select(conversation, onSelectConversation: { selectedConversation = $0 })

        XCTAssertEqual(selectedConversation, conversation)
    }

    func testGlassPanelDecorativeOverlayDoesNotBlockRowSelection() {
        let panel = GlassPanel {
            Text("Selectable row")
        }

        let bodyType = String(reflecting: type(of: panel.body))

        XCTAssertTrue(
            bodyType.contains("_AllowsHitTestingModifier"),
            "GlassPanel's decorative overlay must not participate in hit testing because history rows use it inside a Button."
        )
    }

    func testLocalStoreBuildsConversationSummaryFromMessages() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuraHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let store = LocalConversationStore(directory: directory)
        let messages = [
            ChatMessage(
                id: "user-1",
                conversationID: "cid-local",
                role: .user,
                displayText: "Plan my afternoon and call mom.",
                createdAt: Date(timeIntervalSince1970: 10),
                deliveryState: .complete
            ),
            ChatMessage(
                id: "assistant-1",
                conversationID: "cid-local",
                role: .assistant,
                displayText: "You can work first, then call at 5 PM.",
                createdAt: Date(timeIntervalSince1970: 70),
                deliveryState: .complete
            )
        ]

        try store.upsertConversation(
            id: "cid-local",
            cidMD5: "md5-local",
            messages: messages,
            elapsedSeconds: 60
        )

        let conversations = try store.loadConversations()

        XCTAssertEqual(conversations.first?.title, "Plan my afternoon and call mom.")
        XCTAssertEqual(conversations.first?.preview, "You can work first, then call at 5 PM.")
        XCTAssertEqual(conversations.first?.durationText, "1m 00s")
        XCTAssertEqual(try store.loadMessages(conversationID: "cid-local"), messages)
    }
}

private final class InMemoryConversationStore: ConversationStoring {
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
                title: messages.first?.displayText ?? "Conversation",
                preview: messages.last?.displayText ?? "",
                updatedAt: messages.last?.createdAt ?? Date(),
                durationText: "\(elapsedSeconds)s"
            ),
            messages: messages
        ))
    }
}

private struct FailingConversationStore: ConversationStoring {
    func loadConversations() throws -> [Conversation] {
        throw NSError(domain: "test", code: 1)
    }

    func loadMessages(conversationID: String) throws -> [ChatMessage] {
        throw NSError(domain: "test", code: 1)
    }

    func upsertConversation(id: String, cidMD5: String, messages: [ChatMessage], elapsedSeconds: Int) throws {
        throw NSError(domain: "test", code: 1)
    }
}
