import Foundation

public protocol ChatClient {
    func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error>
}

public protocol HistoryClient {
    func fetchConversations(page: Int, pageSize: Int) async throws -> HistoryPage
    func fetchMessages(cid: String, page: Int, pageSize: Int) async throws -> MessagePage
}

public enum ChatStreamUpdate: Equatable {
    case started(userChatID: String, botChatID: String)
    case assistantToken(String)
    case final(displayText: String, voiceText: String?, intent: String?)
    case messageIDs(userMessageID: Int, botMessageID: Int)
    case completed
}
