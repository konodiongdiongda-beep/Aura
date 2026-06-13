## ADDED Requirements

### Requirement: History Row Opens Detail
The app SHALL open the message detail view for the selected conversation when the user taps a visible history row.

#### Scenario: User taps a history record
- **GIVEN** the history tab displays at least one conversation row
- **WHEN** the user taps anywhere inside the visible row card
- **THEN** the app SHALL select that conversation
- **AND** the app SHALL display the matching message detail view.

#### Scenario: User dismisses message detail
- **GIVEN** a message detail view is open from history
- **WHEN** the user taps the detail back control
- **THEN** the app SHALL return to the history list
- **AND** the same history list state SHALL remain available.
