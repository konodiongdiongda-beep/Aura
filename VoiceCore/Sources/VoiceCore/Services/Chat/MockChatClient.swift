import Foundation

public final class MockChatClient: ChatClient {
    private let updates: [ChatStreamUpdate]
    private let delayNanoseconds: UInt64

    public init(
        updates: [ChatStreamUpdate] = [
            .started(userChatID: "mock-user-chat", botChatID: "mock-bot-chat"),
            .assistantToken("你好"),
            .assistantToken("，我是语音助手。"),
            .final(displayText: "你好，我是语音助手。", voiceText: "你好，我是语音助手。", intent: "chat"),
            .completed
        ],
        delayNanoseconds: UInt64 = 0
    ) {
        self.updates = updates
        self.delayNanoseconds = delayNanoseconds
    }

    public func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for update in updates {
                    if delayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: delayNanoseconds)
                    }
                    continuation.yield(update)
                }
                continuation.finish()
            }
        }
    }
}
