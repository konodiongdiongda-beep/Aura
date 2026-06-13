import Foundation

public struct HistoryPage: Equatable {
    public let items: [Conversation]
    public let page: Int
    public let pageSize: Int
    public let total: Int

    public init(items: [Conversation], page: Int, pageSize: Int, total: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.total = total
    }

    public var conversations: [Conversation] {
        items
    }

    public var hasMore: Bool {
        page * pageSize < total
    }
}

public struct MessagePage: Equatable {
    public let items: [ChatMessage]
    public let page: Int
    public let pageSize: Int
    public let total: Int

    public init(items: [ChatMessage], page: Int, pageSize: Int, total: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.total = total
    }

    public var messages: [ChatMessage] {
        items
    }

    public var hasMore: Bool {
        (page + 1) * pageSize < total
    }
}
