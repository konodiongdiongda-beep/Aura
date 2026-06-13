## ADDED Requirements

### Requirement: Normal recording and playback barge-in are separate modes
The coordinator SHALL treat normal listening and assistant playback as different input modes.

#### Scenario: Normal listening user speech
- **WHEN** the assistant is not playing audio and the current user speaks
- **THEN** the coordinator SHALL allow the normal fast user-turn path

#### Scenario: Assistant playback partial recognition
- **WHEN** the assistant is playing audio and partial recognition text arrives
- **THEN** the coordinator SHALL NOT submit that partial as a user turn

### Requirement: Playback-time barge-in requires current-user evidence
The coordinator SHALL require current-user speaker evidence before cancelling assistant playback from microphone activity.

#### Scenario: Verified current user interrupts playback
- **WHEN** assistant playback is active and microphone activity contains current-user speaker evidence
- **THEN** the coordinator SHALL cancel playback and enter interrupted recognition

#### Scenario: Unverified playback activity
- **WHEN** assistant playback is active and microphone activity has no current-user evidence
- **THEN** the coordinator SHALL keep playback active and not submit a user turn

### Requirement: Apple echo-cancelled input preference
The app SHALL prefer echo-cancelled microphone input when the active iOS route supports it.

#### Scenario: Echo-cancelled input is available
- **WHEN** the call audio session starts and echo-cancelled input is available
- **THEN** the app SHALL request echo-cancelled input before starting recognition

### Requirement: Rolling PCM evidence is safe
Taking a rolling PCM snapshot SHALL NOT crash when the buffer is empty or changing size.

#### Scenario: Empty rolling buffer
- **WHEN** recent audio evidence is requested before PCM exists
- **THEN** the app SHALL return no evidence instead of crashing

### Requirement: Faster first audible response
The TTS queue SHALL start speaking a short first segment without waiting for a long sentence.

#### Scenario: First assistant tokens arrive
- **WHEN** the assistant starts streaming text
- **THEN** the TTS queue SHALL emit a speakable first segment quickly
