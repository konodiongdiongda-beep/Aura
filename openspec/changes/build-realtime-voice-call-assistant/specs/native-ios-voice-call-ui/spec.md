## ADDED Requirements

### Requirement: Native SwiftUI call shell
The app SHALL provide a native SwiftUI interface for idle, in-call, history, and settings states using the supplied Aura/Lumina design references as the visual baseline.

#### Scenario: User opens the app before starting a call
- **WHEN** the app launches with no active call
- **THEN** the UI SHALL show an online assistant header, central voice entry control, start-call action, and bottom navigation for history, voice, keyboard, and profile/settings.
- **AND** the bottom navigation SHALL remain compact so it does not dominate or crowd the primary screen content.
- **AND** the header surface SHALL extend to the physical top edge behind the iOS status area while keeping header content below the status indicators.
- **AND** the bottom navigation surface SHALL sit flush with the bottom edge while preserving home-indicator safe-area spacing.

#### Scenario: User installs the app
- **WHEN** the app is installed on iOS
- **THEN** the home screen app icon SHALL use the supplied Aura microphone artwork.

#### Scenario: User starts a call
- **WHEN** the user taps the start-call action
- **THEN** the UI SHALL animate naturally into an in-call layout with call timer, live waveform/voice activity indicator, transcript area, mute control, end-call control, and speaker control.
- **AND** the in-call layout SHALL not show the idle/home top assistant header.
- **AND** the call timer SHALL remain below the top safe-area/Dynamic Island region with enough spacing to avoid overlap on modern iPhone devices.

#### Scenario: Existing transcript content is present during a call
- **WHEN** the in-call page has one or more prior user or assistant messages
- **THEN** the transcript area SHALL scroll within the available space without pushing the call controls or bottom navigation below the visible screen.

#### Scenario: New transcript content arrives during a call
- **WHEN** a new user or assistant transcript message appears
- **THEN** the transcript area SHALL keep the newest conversation content visible by default while still allowing the user to scroll upward to older messages.

### Requirement: Live transcript display
The app SHALL display user speech text and AI response text during the call.

#### Scenario: User speech is partially recognized
- **WHEN** Azure recognition emits partial user text
- **THEN** the call page SHALL display the current user utterance as an in-progress transcript.

#### Scenario: AI response streams from chat
- **WHEN** the chat WebSocket emits response tokens
- **THEN** the call page SHALL append the AI text progressively without waiting for final completion.

### Requirement: Local conversation history
The app SHALL show locally persisted conversation text in History instead of runtime mock data.

#### Scenario: User completes or leaves a conversation with transcript text
- **WHEN** the call transcript contains user or assistant messages
- **THEN** the app SHALL persist those app-domain messages locally under the current conversation.

#### Scenario: User opens History after local conversations exist
- **WHEN** the History tab is opened
- **THEN** the UI SHALL list locally stored conversations and SHALL NOT populate the list from `MockData`.

#### Scenario: User opens a History conversation detail
- **WHEN** the user selects a locally stored conversation
- **THEN** the message detail page SHALL show the locally stored text messages for that conversation.

### Requirement: Call state visibility
The app SHALL expose the current call state through concise visible status text and control state.

#### Scenario: AI is speaking
- **WHEN** synthesized AI audio is playing
- **THEN** the UI SHALL indicate that the assistant is speaking while keeping the microphone interruption path active unless muted.

#### Scenario: User interrupts AI speech
- **WHEN** the user speaks during AI playback and the input passes barge-in filtering
- **THEN** the UI SHALL stop showing the interrupted audio as active and SHALL show the new user utterance as the active turn.

### Requirement: Error and configuration states
The app SHALL present recoverable errors for missing permissions, missing Azure Speech configuration, network failures, and speech-service failures.

#### Scenario: Azure Speech key or region is missing
- **WHEN** the user attempts to start a voice call without configured Azure Speech credentials
- **THEN** the app SHALL block speech startup and show a settings/configuration error rather than failing silently.

### Requirement: In-app language preference
The settings UI SHALL provide an in-app language preference for English and Chinese display text.

#### Scenario: User switches display language
- **WHEN** the user changes the language setting between English and Chinese
- **THEN** settings, navigation, and primary Phase 1 UI labels SHALL update without requiring network access or app restart.
