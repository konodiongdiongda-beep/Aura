## ADDED Requirements

### Requirement: Barge-in resets stale recognition state
When a verified user barge-in begins during assistant playback, the coordinator SHALL reset speech recognition so old assistant playback audio cannot be emitted as the interrupted user turn.

#### Scenario: Verified voice activity starts barge-in
- **WHEN** assistant playback is active
- **AND** current-user voice activity is verified
- **THEN** the coordinator SHALL cancel the current recognizer session and start a fresh recognition session

#### Scenario: Stale old-stream result after reset
- **WHEN** barge-in has reset recognition
- **AND** the old recognition stream emits assistant playback text
- **THEN** the coordinator SHALL NOT submit that stale text as a user turn

#### Scenario: Fresh post-reset user result
- **WHEN** barge-in has reset recognition
- **AND** the fresh recognition stream emits the user's interrupted speech
- **THEN** the coordinator SHALL submit that user speech normally
