## ADDED Requirements

### Requirement: Formatting-only recognition revisions stay one turn
The system SHALL treat a final recognition result as the same user turn when it only changes punctuation, spacing, or other non-semantic formatting from an already submitted partial.

#### Scenario: Short Chinese partial followed by punctuated final
- **GIVEN** a partial recognition result `嘿晚上好` has already been submitted
- **WHEN** a later final recognition result is `嘿，晚上好。` before the assistant responds
- **THEN** the transcript SHALL contain one user message
- **AND** the chat client SHALL receive one user turn for that utterance.

### Requirement: Genuine new speech still creates a new turn
The system SHALL still create a new user turn when recognition while thinking is not a formatting-only revision of the submitted turn.

#### Scenario: New utterance arrives while waiting
- **GIVEN** the user turn `嘿晚上好` is waiting for assistant response
- **WHEN** the user says `再查一下黄金`
- **THEN** the system SHALL submit a second user turn.
