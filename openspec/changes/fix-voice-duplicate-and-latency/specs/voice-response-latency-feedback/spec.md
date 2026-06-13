## ADDED Requirements

### Requirement: Slow assistant startup is visible
The system SHALL surface a distinct slow-response status when the assistant has not produced a token shortly after a user turn is submitted.

#### Scenario: Chat backend does not produce an early token
- **GIVEN** the user has submitted a speech turn
- **WHEN** no assistant token or final response arrives within the configured response-start threshold
- **THEN** the call UI SHALL remain active
- **AND** the status detail SHALL indicate the app is still waiting for the assistant response.

#### Scenario: Assistant starts responding
- **GIVEN** the slow-response status is visible
- **WHEN** the assistant produces the first token or final response
- **THEN** the app SHALL clear the slow-response status
- **AND** transition to speaking.

### Requirement: Stalled assistant startup times out
The system SHALL stop waiting for a pending assistant response when no assistant output arrives before the configured hard startup timeout.

#### Scenario: Chat backend accepts the turn but never streams output
- **GIVEN** the user has submitted a speech turn
- **WHEN** no assistant token or final response arrives before the configured hard startup timeout
- **THEN** the app SHALL cancel the pending turn
- **AND** the call state SHALL become an error that clearly indicates the chat backend response timed out.

#### Scenario: Timeout error is visible in the call UI
- **GIVEN** the pending assistant response timed out
- **WHEN** the in-call status is rendered
- **THEN** the status title SHALL show the error state
- **AND** the status detail SHALL show the timeout reason rather than only a generic attention message.
