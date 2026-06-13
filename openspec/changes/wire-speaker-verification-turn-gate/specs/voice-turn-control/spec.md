## ADDED Requirements

### Requirement: User turn submission gate
The system SHALL evaluate recognized user-turn text through a submission gate before sending it to the chat API.

#### Scenario: Gate accepts recognized text
- **WHEN** recognized text passes the submission gate
- **THEN** the coordinator SHALL submit the user turn normally

#### Scenario: Gate rejects recognized text
- **WHEN** recognized text is rejected by the submission gate
- **THEN** the coordinator SHALL NOT send it to the chat API
- **AND** it SHALL expose a visible filter result explaining the rejection

#### Scenario: Default gate is used
- **WHEN** no production speaker verifier is configured
- **THEN** the default gate SHALL preserve existing accepted-turn behavior
