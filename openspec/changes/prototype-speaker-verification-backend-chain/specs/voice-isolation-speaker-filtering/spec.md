## ADDED Requirements

### Requirement: Backend prototype precedes mobile speaker model integration
The app SHALL validate current-user verification behavior through an offline/backend prototype before integrating a production speaker-verification model into the mobile call path.

#### Scenario: Prototype report is generated
- **WHEN** the prototype processes current-user, AI playback, and mixed audio candidates
- **THEN** the resulting report SHALL identify which inputs would be accepted, rejected, or marked uncertain by the user-turn gate
