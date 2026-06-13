## ADDED Requirements

### Requirement: Bottom Navigation Destinations
The app SHALL expose only History, Voice, and Settings as user-facing bottom navigation destinations.

#### Scenario: Bottom bar renders primary destinations
- **GIVEN** the main app shell is displayed
- **WHEN** the bottom navigation is rendered
- **THEN** the available destinations are History, Voice, and Settings
- **AND** Text Input / Keyboard is not available from the bottom navigation

### Requirement: Text Input Page Exclusion
The app SHALL NOT present the Text Input page as a primary tab destination.

#### Scenario: User navigates primary tabs
- **GIVEN** a user switches between bottom navigation destinations
- **WHEN** any primary tab is selected
- **THEN** the app does not show the Text Input page
- **AND** no selected indicator is rendered for a Text Input / Keyboard tab
