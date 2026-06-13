## ADDED Requirements

### Requirement: Device package targets requested UDIDs
The packaging workflow SHALL produce a device-installable iOS package for `AuraVoiceAssistant` only when the signing profile matches the app bundle identifier and includes the requested devices, or SHALL report the exact missing signing condition.

#### Scenario: Matching provisioning is available
- **GIVEN** a provisioning profile for `com.aura.voiceassistant` includes the requested UDIDs
- **WHEN** the app is archived and exported
- **THEN** an installable `.ipa` SHALL be produced.

#### Scenario: Matching provisioning is unavailable
- **GIVEN** no suitable provisioning profile is available locally or through automatic signing
- **WHEN** packaging is attempted
- **THEN** packaging SHALL stop and report the missing profile or device registration issue.
