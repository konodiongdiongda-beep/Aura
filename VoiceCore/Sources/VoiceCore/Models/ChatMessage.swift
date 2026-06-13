import Foundation

public struct ChatMessage: Identifiable, Equatable {
    public enum Role: Equatable {
        case user
        case assistant
        case system
    }

    public enum DeliveryState: Equatable {
        case draft
        case streaming
        case complete
        case interrupted
        case failed(String)
    }

    public let id: String
    public let conversationID: String
    public let role: Role
    public var displayText: String
    public var voiceText: String?
    public var createdAt: Date
    public var deliveryState: DeliveryState

    public init(
        id: String,
        conversationID: String,
        role: Role,
        displayText: String,
        voiceText: String? = nil,
        createdAt: Date,
        deliveryState: DeliveryState
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.displayText = displayText
        self.voiceText = voiceText
        self.createdAt = createdAt
        self.deliveryState = deliveryState
    }
}
