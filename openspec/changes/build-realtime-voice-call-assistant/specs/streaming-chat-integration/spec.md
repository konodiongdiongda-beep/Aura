## ADDED Requirements

### Requirement: Chat request metadata
The app SHALL generate chat request metadata according to the provided interface document.

#### Scenario: New conversation starts
- **WHEN** the app creates a new chat conversation
- **THEN** it SHALL generate `cid` with `UUID().uuidString`, compute lowercase `cid_md5` from the MD5 of `cid` using the first 16 characters, and reuse that `cid` for turns in the same conversation.

#### Scenario: User utterance is submitted
- **WHEN** the app sends user text to the chat WebSocket
- **THEN** it SHALL generate `user_chat_id`, `bot_chat_id`, `second_time`, and `request_id` using the documented request shape.

### Requirement: WebSocket streaming response handling
The app SHALL connect to the configured chat WebSocket and parse newline-delimited JSON events.

#### Scenario: Response token includes display text
- **WHEN** an event has `step_type` of `final_token` and `step_output.display_text`
- **THEN** the app SHALL append that display text to the current AI message and make it available for TTS segmentation.

#### Scenario: Response finishes
- **WHEN** an event has `step_type` of `finish`
- **THEN** the app SHALL parse the final result JSON, finalize the visible AI message, flush remaining TTS text, and mark the turn complete.

### Requirement: Request cancellation on interruption
The app SHALL protect the active turn from stale WebSocket events after barge-in.

#### Scenario: User interrupts while a prior AI turn is still streaming
- **WHEN** the user barge-in creates a new turn
- **THEN** the app SHALL close or ignore the prior stream and SHALL not append stale prior tokens to the new active AI message.

### Requirement: Text fallback for voice output
The app SHALL use visible AI text for speech when the backend does not provide `voice_text`.

#### Scenario: Backend final result has empty voice text
- **WHEN** the final result contains empty `voice_text` and non-empty `display_text`
- **THEN** the app SHALL use `display_text` as the text source for Azure TTS.
