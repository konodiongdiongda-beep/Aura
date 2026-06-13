## ADDED Requirements

### Requirement: Post-playback assistant echo is rejected
The system SHALL reject recognition text that substantially matches recent assistant output after assistant playback has drained.

#### Scenario: Assistant prompt is captured after playback
- **WHEN** assistant playback has completed and the recognizer emits final text matching the recent assistant prompt with punctuation or leading words removed
- **THEN** the system SHALL NOT submit that text to chat
- **AND** the transcript SHALL NOT add a user message for that assistant echo

### Requirement: Recent assistant echo memory includes display and voice variants
The system SHALL keep recent assistant display text and voice text available for echo comparison during the assistant echo memory window.

#### Scenario: Display text differs from voice text
- **WHEN** the assistant final response has distinct display and voice text
- **AND** the recognizer emits final text matching the display text after playback
- **THEN** the system SHALL reject the recognition as assistant echo
