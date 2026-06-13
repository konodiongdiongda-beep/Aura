# VoiceCore Chat Debug Smoke

Use this only for manual debugging. Unit tests should not call the public backend.

```swift
import VoiceCore

let services = AppServices.live(
    chatWebSocketURL: VoiceCoreServiceConfiguration.defaultChatWebSocketURL,
    historyListURL: VoiceCoreServiceConfiguration.defaultHistoryListURL,
    historyMessagesURL: VoiceCoreServiceConfiguration.defaultHistoryMessagesURL,
    userName: "test01",
    userID: 35
)

let conversation = services.idFactory.makeConversationContext()
let updates = try await VoiceCoreDebugHelper.collectUpdates(
    text: "你是谁",
    client: services.chatClient,
    conversation: conversation
)

for update in updates {
    print(update)
}
```

Expected behavior:

- The first update is `.started(userChatID:botChatID:)`.
- `final_token.step_output.display_text` events appear as `.assistantToken`.
- A `finish` event appears as `.final(displayText:voiceText:intent:)` followed by `.completed`.
