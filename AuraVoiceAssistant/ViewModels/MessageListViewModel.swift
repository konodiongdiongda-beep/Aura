import Foundation
import VoiceCore

@MainActor
final class MessageListViewModel: ObservableObject {
    @Published private(set) var conversation: Conversation
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?

    private let store: any ConversationStoring

    init(
        conversation: Conversation,
        store: any ConversationStoring = LocalConversationStore(),
        messages: [ChatMessage] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.conversation = conversation
        self.store = store
        self.messages = messages
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    static func preview(conversation: Conversation = MockData.conversations[0]) -> MessageListViewModel {
        MessageListViewModel(conversation: conversation, store: PreviewConversationStore.loaded)
    }

    func loadFirstPage() {
        isLoading = true
        do {
            messages = try store.loadMessages(conversationID: conversation.id)
            errorMessage = nil
        } catch {
            messages = []
            errorMessage = "Unable to load local messages."
        }
        isLoading = false
    }
}
