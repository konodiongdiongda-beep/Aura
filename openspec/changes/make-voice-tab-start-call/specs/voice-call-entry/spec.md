## ADDED Requirements

### Requirement: Voice Tab Opens Phone Screen
The app SHALL treat the center Voice tab as navigation to the Voice phone screen.

#### Scenario: User taps center voice tab from history
- **GIVEN** the bottom navigation is visible
- **AND** the History screen is selected
- **WHEN** the user taps the center Voice tab
- **THEN** the app selects the Voice screen
- **AND** the app does not start the voice call flow

### Requirement: Call Entry Uses Phone Iconography
The app SHALL use phone-oriented iconography for idle call entry controls instead of microphone/recording iconography.

#### Scenario: User views idle call entry controls
- **GIVEN** the Voice screen is idle
- **WHEN** call entry controls are displayed
- **THEN** the center bottom navigation entry uses a phone symbol
- **AND** the primary idle call entry visual uses a phone symbol
