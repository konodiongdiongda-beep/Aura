import Foundation
import VoiceCore

enum MockData {
    static let conversationID = "mock-cid-20260528120000"
    static let cidMD5 = "7bc8c5d4e3a21990"
    static let now = Date(timeIntervalSince1970: 1_779_951_600)

    static let conversations: [Conversation] = [
        Conversation(
            id: "mock-cid-1",
            cidMD5: "f1a7d2b9034c9912",
            title: "Daily Schedule Planning",
            preview: "Discussed project deadlines, workout timing, and a calmer break schedule.",
            updatedAt: now.addingTimeInterval(-60 * 34),
            durationText: "5m 24s"
        ),
        Conversation(
            id: "mock-cid-2",
            cidMD5: "b98c113ee04d7720",
            title: "Recipe Assistance",
            preview: "Asked for a quick vegetarian dinner idea using spinach and chickpeas.",
            updatedAt: now.addingTimeInterval(-60 * 247),
            durationText: "1m 12s"
        ),
        Conversation(
            id: "mock-cid-3",
            cidMD5: "c5e871401aae32f4",
            title: "Reflective Session",
            preview: "Explored mindfulness techniques and intentional silence during work hours.",
            updatedAt: now.addingTimeInterval(-60 * 60 * 19),
            durationText: "12m 45s"
        ),
        Conversation(
            id: "mock-cid-4",
            cidMD5: "a7729c613bb07e18",
            title: "Language Practice",
            preview: "Practiced conversational Spanish for restaurant ordering and directions.",
            updatedAt: now.addingTimeInterval(-60 * 60 * 28),
            durationText: "3m 08s"
        )
    ]

    static let idleSystemMessage = ChatMessage(
        id: "mock-system-ready",
        conversationID: conversationID,
        role: .system,
        displayText: "Aura is ready for a new call.",
        voiceText: nil,
        createdAt: now,
        deliveryState: .complete
    )

    static let activeMessages: [ChatMessage] = [
        ChatMessage(
            id: "mock-user-1",
            conversationID: conversationID,
            role: .user,
            displayText: "What is my next meeting?",
            voiceText: nil,
            createdAt: now.addingTimeInterval(-70),
            deliveryState: .complete
        ),
        ChatMessage(
            id: "mock-assistant-1",
            conversationID: conversationID,
            role: .assistant,
            displayText: "Your next meeting is at 2:00 PM with the design team. I can also help you prepare a short agenda.",
            voiceText: "Your next meeting is at 2:00 PM with the design team.",
            createdAt: now.addingTimeInterval(-62),
            deliveryState: .complete
        )
    ]

    static let detailMessages: [ChatMessage] = [
        ChatMessage(
            id: "history-user-1",
            conversationID: "mock-cid-1",
            role: .user,
            displayText: "Help me plan the rest of today.",
            voiceText: nil,
            createdAt: now.addingTimeInterval(-3_400),
            deliveryState: .complete
        ),
        ChatMessage(
            id: "history-assistant-1",
            conversationID: "mock-cid-1",
            role: .assistant,
            displayText: "You have one design review in the afternoon. I suggest grouping the remaining work into prep, review, and follow-up blocks.",
            voiceText: nil,
            createdAt: now.addingTimeInterval(-3_360),
            deliveryState: .complete
        ),
        ChatMessage(
            id: "history-user-2",
            conversationID: "mock-cid-1",
            role: .user,
            displayText: "Add a workout break too.",
            voiceText: nil,
            createdAt: now.addingTimeInterval(-3_180),
            deliveryState: .complete
        ),
        ChatMessage(
            id: "history-assistant-2",
            conversationID: "mock-cid-1",
            role: .assistant,
            displayText: "A 30-minute break at 5:30 PM keeps the afternoon focused without pushing dinner too late.",
            voiceText: nil,
            createdAt: now.addingTimeInterval(-3_120),
            deliveryState: .complete
        )
    ]
}
