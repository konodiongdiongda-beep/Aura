import Foundation

public enum VoiceCoreDebugHelper {
    public static func collectUpdates(
        text: String,
        client: any ChatClient,
        conversation: ConversationContext
    ) async throws -> [ChatStreamUpdate] {
        var updates: [ChatStreamUpdate] = []
        for try await update in client.sendMessage(text, conversation: conversation) {
            updates.append(update)
        }
        return updates
    }

    public static func makeDefaultConversation(
        userName: String = "test01",
        userID: Int = 35
    ) -> ConversationContext {
        ConversationIDFactory(userName: userName, userID: userID).makeConversationContext()
    }
}
