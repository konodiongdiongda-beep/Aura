## ADDED Requirements

### Requirement: Playback text barge-in is echo-first and low latency
The system SHALL allow meaningful non-echo user recognition text to interrupt assistant playback without waiting for separate speaker verification, while still rejecting assistant self-playback.

#### Scenario: Non-echo partial interrupts assistant playback
- **WHEN** assistant playback is active
- **AND** recognition emits a meaningful partial that does not match current or recent assistant speech
- **THEN** the coordinator SHALL cancel and clear assistant playback
- **AND** it SHALL enter user recognition for the partial text
- **AND** it SHALL submit only the user speech after the fast partial delay

#### Scenario: Assistant partial echo remains blocked
- **WHEN** assistant playback is active
- **AND** recognition emits partial text that substantially matches current or recent assistant speech
- **THEN** the coordinator SHALL keep playback active
- **AND** it SHALL NOT submit the assistant text as a user turn

#### Scenario: ASR revisions update one pending user bubble
- **WHEN** a user partial has already been fast-submitted and the coordinator is waiting for the assistant response
- **AND** ASR emits later partials or a final result that revise or extend the same utterance
- **THEN** the coordinator SHALL update the existing user message display text
- **AND** it SHALL NOT append additional user messages for those revisions
- **AND** it SHALL NOT submit the revised text as a separate chat turn

### Requirement: Local response prelude masks backend and TTS startup latency
The system SHALL support a short local assistant prelude that starts after a user turn is accepted and before backend response text arrives.

#### Scenario: Prelude starts after user turn submission
- **WHEN** a user turn is submitted
- **AND** local prelude text is configured
- **THEN** the coordinator SHALL enqueue the prelude for playback immediately
- **AND** it SHALL remember the prelude as assistant speech for echo rejection
- **AND** it SHALL NOT append the prelude as an assistant chat message
- **AND** it SHALL NOT mark the backend assistant response as started
- **AND** it SHALL NOT prevent delayed-response and hard-timeout watchdogs

#### Scenario: Prelude is cancelable by barge-in
- **WHEN** the local prelude is playing
- **AND** the user speaks a meaningful non-echo interruption
- **THEN** the coordinator SHALL cancel and clear the prelude playback
- **AND** it SHALL submit only the new user interruption

#### Scenario: Prelude keeps waiting state when backend stalls
- **WHEN** a user turn is submitted
- **AND** local prelude text is playing or has played
- **AND** no backend assistant token or final response arrives
- **THEN** the coordinator SHALL remain in the pending-response path
- **AND** it SHALL surface delayed-response status after the soft timeout
- **AND** it SHALL enter the chat timeout error after the hard timeout

### Requirement: Noise and endpoint constraints remain explicit
The system SHALL preserve background voice rejection and the current debug backend endpoint while changing duplex turn policy.

#### Scenario: Recently rejected background voice does not barge in by text
- **WHEN** background or other-speaker activity has just been rejected
- **AND** ASR emits partial or final text from that rejected window
- **THEN** the coordinator SHALL reject that text
- **AND** it SHALL NOT cancel assistant playback or submit chat

#### Scenario: Backend port remains 6007
- **WHEN** app service configuration is loaded for the current debug runtime
- **THEN** the chat backend SHALL use port `6007`
- **AND** the change SHALL NOT switch defaults to port `8007`
