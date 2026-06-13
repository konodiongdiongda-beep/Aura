## ADDED Requirements

### Requirement: Controlled assistant audio playback
The system SHALL play assistant speech through a controlled playback queue that exposes playback lifecycle events.

#### Scenario: Assistant speech starts playing
- **WHEN** assistant speech is enqueued for playback
- **THEN** the playback controller SHALL emit a playback-started event before speaking the segment

#### Scenario: Assistant speech finishes playing
- **WHEN** all queued assistant speech has been spoken
- **THEN** the playback controller SHALL emit a playback-drained event

#### Scenario: Assistant speech is cancelled
- **WHEN** playback is cancelled during active or queued assistant speech
- **THEN** the playback controller SHALL emit a playback-cancelled event and clear pending audio

### Requirement: Playback-aware microphone input classification
The system SHALL expose microphone input classification that can distinguish AI playback echo, current-user speech, other-speaker speech, environment noise, and unknown speech before user-turn submission.

#### Scenario: AI playback echo is detected
- **WHEN** microphone input is classified as AI playback echo during assistant playback
- **THEN** the system SHALL reject it as user input and keep visible filter diagnostics updated

#### Scenario: Other speaker is detected
- **WHEN** microphone input is classified as another speaker with sufficient confidence
- **THEN** the system SHALL reject it as user input and SHALL NOT submit it to the chat API

### Requirement: Pluggable current-user verification
The system SHALL keep current-user speaker verification behind a shared protocol so on-device or server-side verification can be added without changing coordinator orchestration.

#### Scenario: Speaker verification is unavailable
- **WHEN** the verifier cannot make a reliable decision because the utterance is too short or the verifier is disabled
- **THEN** the system SHALL expose an unavailable verification result rather than marking the speaker as verified

#### Scenario: Current user is verified
- **WHEN** the verifier confirms the enrolled user for sufficient speech evidence
- **THEN** the system SHALL allow the utterance to proceed through normal user-turn submission
