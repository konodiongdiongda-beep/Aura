import Foundation
import VoiceCore

@MainActor
final class HistoryListViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?
    @Published var searchText: String

    private let store: any ConversationStoring

    init(
        store: any ConversationStoring = LocalConversationStore(),
        conversations: [Conversation] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        searchText: String = ""
    ) {
        self.store = store
        self.conversations = conversations
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.searchText = searchText
    }

    var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    static func previewLoaded() -> HistoryListViewModel {
        HistoryListViewModel(store: PreviewConversationStore.loaded)
    }

    static func previewError() -> HistoryListViewModel {
        HistoryListViewModel(store: PreviewConversationStore.failing)
    }

    func loadFirstPage() {
        isLoading = true
        do {
            conversations = try store.loadConversations()
            errorMessage = nil
        } catch {
            conversations = []
            errorMessage = "Unable to load local history."
        }
        isLoading = false
    }

    func loadNextPageIfNeeded(currentItem: Conversation?) {}

    func refresh() {
        loadFirstPage()
    }

    func makeMessageListViewModel(for conversation: Conversation) -> MessageListViewModel {
        MessageListViewModel(conversation: conversation, store: store)
    }
}
