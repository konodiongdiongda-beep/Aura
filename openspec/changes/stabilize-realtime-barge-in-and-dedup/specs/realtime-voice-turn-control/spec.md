## ADDED Requirements

### Requirement: ASR revisions do not create duplicate user turns
The system SHALL treat revised recognition results from one continuous spoken sentence as updates to the current user turn instead of creating duplicate transcript messages or chat submissions.

#### Scenario: Short Chinese partial is corrected by longer final
- **WHEN** a short Chinese partial has been submitted for latency
- **AND** a later final recognition result is a longer correction of the same spoken sentence with inserted repeated characters or punctuation
- **THEN** the transcript SHALL contain one user message for that sentence
- **AND** the chat layer SHALL NOT receive an additional submission for the same sentence
- **AND** the visible user message SHALL use the corrected final text

#### Scenario: Delayed final revision arrives after coordinator returns to listening
- **WHEN** a partial recognition result has already been fast-submitted as a user turn
- **AND** the assistant response ends or errors before Azure emits the longer final revision for the same spoken sentence
- **THEN** the final revision SHALL update the existing user message
- **AND** it SHALL NOT append a second user bubble
- **AND** it SHALL NOT open another chat submission for that same spoken sentence

#### Scenario: Genuine non-overlapping continuation remains allowed
- **WHEN** the user speaks a separate non-overlapping follow-up before the assistant starts responding
- **THEN** the system MAY submit a new turn or merged continuation according to the existing continuation policy

### Requirement: Playback barge-in is verified and keeps audio output enabled
The system SHALL keep assistant audio output enabled during calls while allowing the current user to interrupt assistant playback after current-user evidence is accepted.

#### Scenario: Verified current user interrupts assistant playback
- **WHEN** assistant playback is active
- **AND** microphone activity is accepted as current-user speech
- **THEN** the coordinator SHALL cancel/clear assistant playback
- **AND** the next user speech SHALL be accepted as the interrupted user turn

#### Scenario: Assistant-like playback partial is not enough to interrupt
- **WHEN** assistant playback is active
- **AND** partial recognition text matches assistant speech or is too short to be meaningful user input
- **THEN** the coordinator SHALL keep playback active
- **AND** it SHALL NOT submit the partial as a user turn

### Requirement: Assistant self-playback is never submitted as user input
The system SHALL reject recognition text that matches assistant playback during the active playback window and during the recent post-playback echo memory window.

#### Scenario: Assistant output is captured by microphone
- **WHEN** recognition text substantially matches current or recent assistant display/voice output
- **THEN** the system SHALL reject it before chat submission
- **AND** no user transcript message SHALL be added for the assistant echo

#### Scenario: Recent assistant tail is captured after playback or over headphones
- **WHEN** assistant output recently included a sentence tail
- **AND** recognition text repeats that tail while the coordinator is thinking, listening, or waiting for playback drain
- **THEN** the system SHALL reject it as assistant echo
- **AND** it SHALL NOT add a user bubble or submit chat

### Requirement: Rejected background voice does not hold recognition state
The system SHALL keep environment noise and verified other-speaker activity out of the visible user recognition turn.

#### Scenario: Environment voice activity suppresses following ASR text
- **WHEN** microphone activity is classified as environment noise
- **AND** the recognizer emits partial or final text from that same short audio window
- **THEN** the coordinator SHALL reject the text
- **AND** it SHALL remain or return to listening
- **AND** it SHALL NOT show a recognizing partial, add a user bubble, or submit chat

#### Scenario: Other-speaker evidence rejects background speech
- **WHEN** final recognition text includes speaker evidence classified as another speaker
- **THEN** the coordinator SHALL reject that final text
- **AND** it SHALL return to listening
- **AND** it SHALL NOT add a user bubble or submit chat

#### Scenario: Unverified noisy final is rejected when strict speaker evidence is enabled
- **WHEN** final recognition text does not include verified current-user speaker evidence
- **AND** strict speaker evidence gating is enabled
- **THEN** the coordinator SHALL reject that final text
- **AND** it SHALL return to listening without submitting chat

### Requirement: Real-voice regressions are replayable as deterministic traces
The system SHALL provide a local regression harness that converts recorded or scripted voice scenarios into deterministic coordinator traces and a machine-readable report.

#### Scenario: Assistant echo trace is replayed
- **WHEN** a trace contains an assistant response followed by recognition text that repeats the assistant tail
- **THEN** the replay test SHALL reject the repeated assistant text as echo
- **AND** the report SHALL show zero user submissions for that echo segment

#### Scenario: Short user answer trace remains accepted
- **WHEN** a trace contains an assistant prompt followed by a short real user answer that overlaps prompt terms
- **THEN** the replay test SHALL submit the short answer as a user turn
- **AND** it SHALL NOT classify the short answer as assistant echo

#### Scenario: Regression report records runtime evidence
- **WHEN** a real-voice fixture is evaluated
- **THEN** the report SHALL include scenario ID, runtime target, route, AEC mode, ASR events, playback events, coordinator filter result, submitted text, and pass/fail status
- **AND** Simulator results SHALL be labeled as wiring validation rather than physical AEC validation
