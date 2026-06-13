import Foundation
import VoiceCore

struct ConversationTurn: Identifiable, Equatable {
    let id: String
    var userMessage: ChatMessage
    var assistantMessage: ChatMessage?
}
