import Foundation
import VoiceCore

struct StoredConversation: Equatable {
    var conversation: Conversation
    var messages: [ChatMessage]
}

protocol ConversationStoring {
    func loadConversations() throws -> [Conversation]
    func loadMessages(conversationID: String) throws -> [ChatMessage]
    func upsertConversation(id: String, cidMD5: String, messages: [ChatMessage], elapsedSeconds: Int) throws
}

final class LocalConversationStore: ConversationStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.fileURL = directory.appendingPathComponent("aura-local-history.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadConversations() throws -> [Conversation] {
        try loadRecords()
            .map(\.conversation)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadMessages(conversationID: String) throws -> [ChatMessage] {
        try loadRecords()
            .first { $0.conversation.id == conversationID }?
            .messages
            .sorted { $0.createdAt < $1.createdAt } ?? []
    }

    func upsertConversation(id: String, cidMD5: String, messages: [ChatMessage], elapsedSeconds: Int) throws {
        let completeMessages = messages.filter { !$0.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !completeMessages.isEmpty else { return }

        var records = try loadRecords()
        records.removeAll { $0.conversation.id == id }
        records.append(StoredConversation(
            conversation: Conversation(
                id: id,
                cidMD5: cidMD5,
                title: Self.title(from: completeMessages),
                preview: Self.preview(from: completeMessages),
                updatedAt: completeMessages.map(\.createdAt).max() ?? Date(),
                durationText: Self.durationText(for: elapsedSeconds)
            ),
            messages: completeMessages.sorted { $0.createdAt < $1.createdAt }
        ))
        try saveRecords(records)
    }

    private func loadRecords() throws -> [StoredConversation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([StoredConversationDTO].self, from: data).map { $0.toStoredConversation() }
    }

    private func saveRecords(_ records: [StoredConversation]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(records.map(StoredConversationDTO.init(record:)))
        try data.write(to: fileURL, options: .atomic)
    }

    private static func title(from messages: [ChatMessage]) -> String {
        let firstUser = messages.first { $0.role == .user }?.displayText
        return clipped(firstUser ?? messages.first?.displayText ?? "Conversation", limit: 48)
    }

    private static func preview(from messages: [ChatMessage]) -> String {
        clipped(messages.last?.displayText ?? "", limit: 96)
    }

    private static func clipped(_ text: String, limit: Int) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText.count > limit else { return cleanText }
        return String(cleanText.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func durationText(for elapsedSeconds: Int) -> String? {
        guard elapsedSeconds > 0 else { return nil }
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return "\(seconds)s"
    }
}

private struct StoredConversationDTO: Codable {
    var conversation: ConversationDTO
    var messages: [ChatMessageDTO]

    init(record: StoredConversation) {
        self.conversation = ConversationDTO(conversation: record.conversation)
        self.messages = record.messages.map(ChatMessageDTO.init(message:))
    }

    func toStoredConversation() -> StoredConversation {
        StoredConversation(
            conversation: conversation.toConversation(),
            messages: messages.map { $0.toChatMessage() }
        )
    }
}

private struct ConversationDTO: Codable {
    var id: String
    var cidMD5: String
    var title: String
    var preview: String
    var updatedAt: Date
    var durationText: String?

    init(conversation: Conversation) {
        self.id = conversation.id
        self.cidMD5 = conversation.cidMD5
        self.title = conversation.title
        self.preview = conversation.preview
        self.updatedAt = conversation.updatedAt
        self.durationText = conversation.durationText
    }

    func toConversation() -> Conversation {
        Conversation(
            id: id,
            cidMD5: cidMD5,
            title: title,
            preview: preview,
            updatedAt: updatedAt,
            durationText: durationText
        )
    }
}

private struct ChatMessageDTO: Codable {
    var id: String
    var conversationID: String
    var role: String
    var displayText: String
    var voiceText: String?
    var createdAt: Date
    var deliveryState: DeliveryStateDTO

    init(message: ChatMessage) {
        self.id = message.id
        self.conversationID = message.conversationID
        self.role = message.role.storageValue
        self.displayText = message.displayText
        self.voiceText = message.voiceText
        self.createdAt = message.createdAt
        self.deliveryState = DeliveryStateDTO(state: message.deliveryState)
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            role: ChatMessage.Role(storageValue: role),
            displayText: displayText,
            voiceText: voiceText,
            createdAt: createdAt,
            deliveryState: deliveryState.toDeliveryState()
        )
    }
}

private struct DeliveryStateDTO: Codable {
    var kind: String
    var message: String?

    init(state: ChatMessage.DeliveryState) {
        switch state {
        case .draft:
            self.kind = "draft"
            self.message = nil
        case .streaming:
            self.kind = "streaming"
            self.message = nil
        case .complete:
            self.kind = "complete"
            self.message = nil
        case .interrupted:
            self.kind = "interrupted"
            self.message = nil
        case .failed(let message):
            self.kind = "failed"
            self.message = message
        }
    }

    func toDeliveryState() -> ChatMessage.DeliveryState {
        switch kind {
        case "draft":
            return .draft
        case "streaming":
            return .streaming
        case "interrupted":
            return .interrupted
        case "failed":
            return .failed(message ?? "")
        default:
            return .complete
        }
    }
}

private extension ChatMessage.Role {
    var storageValue: String {
        switch self {
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        case .system:
            return "system"
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case "assistant":
            self = .assistant
        case "system":
            self = .system
        default:
            self = .user
        }
    }
}
