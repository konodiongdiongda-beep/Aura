import Foundation

public final class MockHistoryClient: HistoryClient {
    private let conversations: [Conversation]
    private let messages: [ChatMessage]

    public init(
        conversations: [Conversation]? = nil,
        messages: [ChatMessage]? = nil
    ) {
        let now = Date(timeIntervalSince1970: 1_779_196_312)
        self.conversations = conversations ?? [
            Conversation(id: "mock-cid-1", cidMD5: "mockmd5000000001", title: "早盘市场", preview: "今天主要关注科技股和汇率。", updatedAt: now, durationText: "42s"),
            Conversation(id: "mock-cid-2", cidMD5: "mockmd5000000002", title: "新闻跟进", preview: "帮你整理了三条重点消息。", updatedAt: now.addingTimeInterval(-3600), durationText: "1m 12s"),
            Conversation(id: "mock-cid-3", cidMD5: "mockmd5000000003", title: "情绪复盘", preview: "先把压力拆开，再决定下一步。", updatedAt: now.addingTimeInterval(-7200), durationText: "55s"),
            Conversation(id: "mock-cid-4", cidMD5: "mockmd5000000004", title: "日常沟通", preview: "有什么问题都可以直接问我。", updatedAt: now.addingTimeInterval(-10_800), durationText: "36s")
        ]
        self.messages = messages ?? [
            ChatMessage(id: "mock-user-chat", conversationID: "mock-cid-1", role: .user, displayText: "你是谁", createdAt: now, deliveryState: .complete),
            ChatMessage(id: "mock-bot-chat", conversationID: "mock-cid-1", role: .assistant, displayText: "我是财经领域的对话助手。", voiceText: "我是财经领域的对话助手。", createdAt: now.addingTimeInterval(2), deliveryState: .complete)
        ]
    }

    public func fetchConversations(page: Int, pageSize: Int) async throws -> HistoryPage {
        let start = max(0, (page - 1) * pageSize)
        let end = min(conversations.count, start + pageSize)
        let items = start < end ? Array(conversations[start..<end]) : []
        return HistoryPage(items: items, page: page, pageSize: pageSize, total: conversations.count)
    }

    public func fetchMessages(cid: String, page: Int, pageSize: Int) async throws -> MessagePage {
        let filtered = messages.filter { $0.conversationID == cid || cid.isEmpty }
        let start = max(0, page * pageSize)
        let end = min(filtered.count, start + pageSize)
        let items = start < end ? Array(filtered[start..<end]) : []
        return MessagePage(items: items, page: page, pageSize: pageSize, total: filtered.count)
    }
}
