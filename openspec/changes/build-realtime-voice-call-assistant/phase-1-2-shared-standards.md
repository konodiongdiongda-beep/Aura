# Phase 1 and 2 Shared Development Standards

## Scope

This document defines the shared contracts for parallel development of:

- Phase 1: native SwiftUI UI and call/history screens.
- Phase 2: chat WebSocket, stream parsing, history APIs, and network models.

The goal is to let UI work proceed with mock data while network work proceeds with real endpoints, then integrate through stable app-domain models.

## Module Boundaries

### UI Layer

UI code SHALL:

- Render only app-domain models and view state.
- Drive user actions through coordinator/view-model methods.
- Use mock services for previews and early screen development.
- Avoid `URLSession`, WebSocket parsing, Azure SDK calls, MD5 generation, and backend DTO parsing inside SwiftUI views.

UI code SHALL NOT:

- Read raw backend JSON.
- Construct chat/history request payloads.
- Know backend field names such as `cid_md5`, `bot_chat_id`, or `step_output`.

### Network Layer

Network code SHALL:

- Own backend DTOs, request payloads, WebSocket event decoding, and HTTP history decoding.
- Convert backend DTOs into app-domain models before exposing data to UI.
- Preserve raw event logging in debug builds for parser troubleshooting.

Network code SHALL NOT:

- Import SwiftUI.
- Format final screen layout strings.
- Mutate UI state directly.

### Coordinator/ViewModel Layer

Coordinator/view-model code SHALL:

- Bridge user actions to services.
- Own loading/error/empty states.
- Translate streaming events into transcript updates.
- Be the integration point between Phase 1 UI and Phase 2 network services.

## Folder Standard

Use `VoiceCore` as the shared local Swift Package for Phase 1 and Phase 2 contracts and non-UI services. The Phase 1 iOS app SHALL reference `VoiceCore` as a local package and SHALL NOT redefine shared models or protocols such as `ChatMessage`, `Conversation`, `ChatClient`, `HistoryClient`, or `ChatStreamUpdate`.

Use this structure for the shared core package:

```text
VoiceCore/
  Package.swift
  Sources/
    VoiceCore/
      Models/
      Services/
        Chat/
        History/
  Tests/
    VoiceCoreTests/
```

The eventual iOS app may use this structure for app-only UI code:

```text
App/
  VoiceCallAssistantApp.swift
  AppConfig.swift
DesignSystem/
  AppColors.swift
  AppTypography.swift
  GlassPanel.swift
  VoiceWaveView.swift
Models/
  ChatMessage.swift
  Conversation.swift
  ConversationTurn.swift
  VoiceCallState.swift
Services/
ViewModels/
  VoiceCallViewModel.swift
  HistoryListViewModel.swift
  MessageListViewModel.swift
Views/
  Voice/
  History/
  Settings/
Tests/
  ChatStreamParserTests.swift
  ConversationIDFactoryTests.swift
  HistoryMappingTests.swift
```

## App-Domain Models

UI and network SHALL share app-domain models instead of backend DTOs.

### ChatMessage

```swift
struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
        case system
    }

    enum DeliveryState: Equatable {
        case draft
        case streaming
        case complete
        case interrupted
        case failed(String)
    }

    let id: String
    let conversationID: String
    let role: Role
    var displayText: String
    var voiceText: String?
    var createdAt: Date
    var deliveryState: DeliveryState
}
```

### Conversation

```swift
struct Conversation: Identifiable, Equatable {
    let id: String
    let cidMD5: String
    var title: String
    var preview: String
    var updatedAt: Date
    var durationText: String?
}
```

### VoiceCallState

```swift
enum VoiceCallState: Equatable {
    case idle
    case requestingPermission
    case listening
    case recognizing(partialText: String)
    case thinking
    case speaking
    case interrupted
    case muted(previous: VoiceCallStateSnapshot)
    case ended
    case error(AppError)
}
```

If Swift rejects recursive enum equality details during implementation, replace `muted(previous:)` with `isMuted` on the view model and keep the state enum non-recursive.

## ViewModel Contracts

### VoiceCallViewModel

Phase 1 SHALL build views against this shape, using mock implementations until services are ready:

```swift
@MainActor
final class VoiceCallViewModel: ObservableObject {
    @Published private(set) var state: VoiceCallState
    @Published private(set) var elapsedSeconds: Int
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var activeUserPartialText: String
    @Published private(set) var activeAssistantText: String
    @Published var isMuted: Bool
    @Published var isSpeakerEnabled: Bool

    func startCall()
    func endCall()
    func toggleMute()
    func toggleSpeaker()
    func sendTextForDebug(_ text: String)
}
```

### HistoryListViewModel

```swift
@MainActor
final class HistoryListViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?
    @Published var searchText: String

    func loadFirstPage()
    func loadNextPageIfNeeded(currentItem: Conversation?)
    func refresh()
}
```

## Service Protocols

Phase 1 SHALL depend on protocols so Phase 2 can replace mocks with real services.

```swift
protocol ChatClient {
    func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error>
}

protocol HistoryClient {
    func fetchConversations(page: Int, pageSize: Int) async throws -> HistoryPage
    func fetchMessages(cid: String, page: Int, pageSize: Int) async throws -> MessagePage
}
```

## Streaming Update Standard

The WebSocket parser SHALL expose parsed updates as app events:

```swift
enum ChatStreamUpdate: Equatable {
    case started(userChatID: String, botChatID: String)
    case assistantToken(String)
    case final(displayText: String, voiceText: String?, intent: String?)
    case messageIDs(userMessageID: Int, botMessageID: Int)
    case completed
}
```

UI SHALL render `assistantToken` immediately. TTS integration later SHALL consume the same token stream through the call coordinator.

## Error Standard

Use one app error shape across UI and services:

```swift
enum AppError: LocalizedError, Equatable {
    case missingAzureSpeechConfig
    case microphonePermissionDenied
    case networkUnavailable
    case websocketDisconnected
    case responseParsingFailed
    case backendRejected(String)
    case unknown(String)
}
```

UI SHALL show human-readable localized text derived from `AppError`, not raw backend stack traces or raw JSON.

## Date and Time Standard

- Backend `second_time` SHALL use local time formatted as `yyyyMMddHHmmss`.
- User-visible dates SHALL be formatted by UI helpers, not DTOs.
- DTO timestamps from backend SHALL be decoded into `Date` as early as practical.

## Identifier Standard

- `cid` SHALL be generated once per active conversation and reused for all turns in that conversation.
- `cid_md5` SHALL be generated by MD5 hashing `cid`, lowercasing, and taking the first 16 hex characters.
- Each sent user turn SHALL generate new `user_chat_id` and `bot_chat_id`.
- UI message IDs SHALL use chat IDs where available to avoid duplicate rows during streaming updates.

## Concurrency Standard

- UI-facing view models SHALL be `@MainActor`.
- Network and parser services SHALL avoid main-actor isolation unless updating UI-facing state.
- Streaming APIs SHALL use `AsyncThrowingStream`.
- Cancellation SHALL be explicit: ending a call or interrupting a turn must cancel or ignore stale streams.

## Mock Data Standard

Phase 1 SHALL include mocks that match Phase 2 domain models:

- One idle state preview.
- One active listening preview.
- One AI streaming preview.
- One interrupted preview.
- At least four history conversations matching the supplied reference layout.
- One message detail transcript with both user and assistant messages.

Mocks SHALL live outside production network code and SHALL be selectable in SwiftUI previews and debug builds.

## Test Standard

Phase 2 SHALL provide tests before integration:

- `ConversationIDFactoryTests`: validates `cid_md5`, `second_time`, and `request_id`.
- `ChatStreamParserTests`: validates `display_text` token accumulation, final result parsing, empty `voice_text` fallback, and ignored stale stream behavior.
- `HistoryMappingTests`: validates history and message DTO conversion into app-domain models.

Phase 1 SHALL provide view-model tests where feasible:

- Initial idle state.
- Start-call state transition with mock services.
- History loading success and failure.
- Search filtering behavior.
