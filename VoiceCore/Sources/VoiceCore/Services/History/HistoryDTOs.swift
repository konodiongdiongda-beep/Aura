import Foundation

public struct HistoryListResponseDTO: Decodable {
    public let message: String?
    public let total: Int
    public let success: Bool
    public let data: [HistoryItemDTO]

    public func toDomain(page: Int, pageSize: Int) -> HistoryPage {
        HistoryPage(
            items: data.map { $0.toConversation() },
            page: page,
            pageSize: pageSize,
            total: total
        )
    }
}

public struct HistoryMessagesResponseDTO: Decodable {
    public let message: String?
    public let total: Int
    public let success: Bool
    public let data: [HistoryItemDTO]

    public func toDomain(page: Int, pageSize: Int) -> MessagePage {
        MessagePage(
            items: data.map { $0.toChatMessage() },
            page: page,
            pageSize: pageSize,
            total: total
        )
    }
}

public struct HistoryItemDTO: Decodable {
    public let id: Int?
    public let cid: String
    public let metadata: HistoryMetadataDTO?
    public let role: String?
    public let voiceText: String?
    public let createdAt: Date?
    public let chatID: String?
    public let updatedAt: Date?
    public let displayText: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cid
        case metadata
        case role
        case voiceText = "voice_text"
        case createdAt = "created_at"
        case chatID = "chat_id"
        case updatedAt = "updated_at"
        case displayText = "display_text"
    }

    public func toConversation() -> Conversation {
        let text = normalizedDisplayText
        return Conversation(
            id: cid,
            cidMD5: metadata?.cidMD5 ?? ConversationIDFactory.cidMD5(for: cid),
            title: text.isEmpty ? "Conversation" : text,
            preview: text,
            updatedAt: updatedAt ?? createdAt ?? Date(timeIntervalSince1970: 0),
            durationText: metadata?.durationText
        )
    }

    public func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: chatID ?? id.map(String.init) ?? "\(cid)-\(role ?? "message")",
            conversationID: cid,
            role: domainRole,
            displayText: normalizedDisplayText,
            voiceText: voiceText,
            createdAt: createdAt ?? updatedAt ?? Date(timeIntervalSince1970: 0),
            deliveryState: .complete
        )
    }

    private var normalizedDisplayText: String {
        displayText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var domainRole: ChatMessage.Role {
        switch role?.lowercased() {
        case "bot", "assistant":
            return .assistant
        case "system":
            return .system
        default:
            return .user
        }
    }
}

public struct HistoryMetadataDTO: Decodable {
    public let cidMD5: String?
    public let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case cidMD5 = "cid_md5"
        case processingTime = "processing_time"
    }

    var durationText: String? {
        guard let processingTime else { return nil }
        return String(format: "%.1fs", processingTime)
    }
}

struct HistoryPageRequestDTO: Encodable {
    let userID: Int
    let page: Int
    let pageSize: Int
    let userName: String
    let context: RequestContextMetadata

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case page
        case pageSize = "page_size"
        case userName = "user_name"
        case context
    }
}

struct HistoryMessagesRequestDTO: Encodable {
    let pageSize: Int
    let page: Int
    let userName: String
    let userID: Int
    let context: RequestContextMetadata
    let cid: String

    enum CodingKeys: String, CodingKey {
        case pageSize = "page_size"
        case page
        case userName = "user_name"
        case userID = "user_id"
        case context
        case cid
    }
}
