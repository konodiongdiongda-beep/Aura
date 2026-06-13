## ADDED Requirements

### Requirement: Runtime submission gate wiring
The app runtime SHALL provide a non-default user-turn submission gate to `VoiceCallCoordinator` when constructing the default voice call coordinator.

#### Scenario: Default coordinator uses runtime gate
- **WHEN** the app creates the default voice call coordinator from the speech service bundle
- **THEN** final recognition candidates SHALL be evaluated by the runtime submission gate before chat submission

### Requirement: Playback echo submission rejection
The runtime submission gate SHALL reject final recognition candidates captured while assistant playback is active unless the candidate has already been accepted as interrupted user input.

#### Scenario: Assistant playback final is rejected
- **WHEN** assistant playback is active and a final recognition candidate is not marked as interrupted user input
- **THEN** the candidate SHALL NOT be submitted to chat

#### Scenario: Normal user final is accepted
- **WHEN** assistant playback is not active and a final recognition candidate is received
- **THEN** the candidate SHALL be allowed to submit to chat

#### Scenario: Accepted interruption remains eligible
- **WHEN** assistant playback is active and a final recognition candidate is marked as interrupted user input
- **THEN** the candidate SHALL remain eligible for chat submission
