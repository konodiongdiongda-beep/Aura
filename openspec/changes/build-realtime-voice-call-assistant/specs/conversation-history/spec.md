## ADDED Requirements

### Requirement: Conversation history list
The app SHALL fetch and display conversation history using the provided history-list endpoint.

#### Scenario: User opens history tab
- **WHEN** the user opens the history tab
- **THEN** the app SHALL call the configured `history/user/page` endpoint and display recent conversations with time, title/preview, and duration when available.

### Requirement: Conversation message list
The app SHALL fetch and display messages for a selected conversation using the provided message-list endpoint.

#### Scenario: User selects a history item
- **WHEN** the user opens a conversation from history
- **THEN** the app SHALL call the configured `history-with-alerts/` endpoint for that `cid` and display user and bot messages in chronological order.

### Requirement: History API configuration
The app SHALL keep user and endpoint settings configurable for development.

#### Scenario: Default QA user is used
- **WHEN** no custom user settings are provided
- **THEN** the app SHALL default to the documented QA identity `test01` with `user_id` 35 for history and chat requests.
