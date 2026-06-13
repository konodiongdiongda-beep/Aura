import Foundation
import VoiceCore

struct PreviewConversationStore: ConversationStoring {
    static let loaded = PreviewConversationStore(records: MockData.conversations.map { conversation in
        StoredConversation(
            conversation: conversation,
            messages: MockData.detailMessages.filter { $0.conversationID == conversation.id } + MockData.detailMessages
        )
    })

    static let failing = PreviewConversationStore(records: [], error: "Preview history unavailable.")

    var records: [StoredConversation]
    var error: String?

    func loadConversations() throws -> [Conversation] {
        if let error {
            throw NSError(domain: "PreviewConversationStore", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        return records.map(\.conversation)
    }

    func loadMessages(conversationID: String) throws -> [ChatMessage] {
        if let error {
            throw NSError(domain: "PreviewConversationStore", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        return records.first { $0.conversation.id == conversationID }?.messages ?? []
    }

    func upsertConversation(id: String, cidMD5: String, messages: [ChatMessage], elapsedSeconds: Int) throws {}
}
