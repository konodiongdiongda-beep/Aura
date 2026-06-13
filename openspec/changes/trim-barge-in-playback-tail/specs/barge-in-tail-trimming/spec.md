## ADDED Requirements

### Requirement: Interrupted final transcripts exclude assistant playback tail
When a verified user interrupts assistant playback, the coordinator SHALL remove assistant playback text that appears before the user's interrupted speech before submitting the user turn.

#### Scenario: Assistant prefix followed by user interruption
- **WHEN** assistant playback says "这里是机器人自己的回答" and the current user interrupts
- **AND** final recognition returns "这里是机器人自己的回答 帮我查黄金"
- **THEN** the coordinator SHALL submit only "帮我查黄金"

#### Scenario: Assistant-only interrupted final
- **WHEN** assistant playback is interrupted
- **AND** final recognition returns only assistant playback text
- **THEN** the coordinator SHALL NOT submit a user turn

#### Scenario: Normal listening remains unchanged
- **WHEN** assistant playback is not active and the current user speaks normally
- **THEN** the coordinator SHALL submit the recognized user speech without assistant-tail trimming
