## ADDED Requirements

### Requirement: Default debug backend port is 6007
The app SHALL use port 6007 for the default chat and history backend endpoints during this debugging configuration.

#### Scenario: VoiceCore default service endpoints are built
- **GIVEN** no endpoint override is provided
- **WHEN** the default VoiceCore service configuration is created
- **THEN** chat WebSocket, history list, and history messages endpoints SHALL use host `43.98.164.20` and port `6007`.

#### Scenario: App default mock configuration is loaded
- **GIVEN** no endpoint override is provided
- **WHEN** app default configuration is used
- **THEN** chat WebSocket, history list, and history messages endpoints SHALL use port `6007`.
