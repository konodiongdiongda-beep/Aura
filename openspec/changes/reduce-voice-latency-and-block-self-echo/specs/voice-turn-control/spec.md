## ADDED Requirements

### Requirement: Assistant playback is not accepted as user input
The system SHALL reject recognition text that is likely assistant playback echo, while allowing non-echo user speech during playback to interrupt the assistant.

#### Scenario: Assistant echo arrives while assistant is speaking
- **WHEN** the assistant is speaking and the recognizer emits text that matches recent assistant speech
- **THEN** the system rejects the text and does not submit a user turn

#### Scenario: User speech arrives while assistant is speaking
- **WHEN** the assistant is speaking and the recognizer emits non-echo user speech
- **THEN** the system cancels playback and captures the user interruption

#### Scenario: User voice activity starts while assistant is speaking
- **WHEN** the assistant is speaking and microphone voice activity is detected before recognition text exists
- **THEN** the system immediately cancels playback
- **AND** the following partial or final recognition text is captured as the interrupted user turn

#### Scenario: User voice activity starts while assistant audio is still playing after stream completion
- **WHEN** assistant speech was recently produced and microphone voice activity is detected before recognition text exists
- **AND** the backend stream has already returned the coordinator to listening
- **THEN** the system immediately cancels playback
- **AND** the following partial or final recognition text is captured as the user turn

### Requirement: Repeated user recognition text is deduplicated
The system SHALL collapse duplicated recognition text within a user turn before displaying or submitting the turn.

#### Scenario: Final recognition contains a repeated utterance
- **WHEN** the recognizer emits a final user phrase that repeats substantially the same utterance twice
- **THEN** the system submits only one copy of that utterance

#### Scenario: Final recognition contains a short repeated Chinese utterance
- **WHEN** the recognizer emits a short Chinese phrase twice with filler words, spaces, or punctuation
- **THEN** the system submits only one copy of that phrase

### Requirement: User speech interrupts pending assistant responses instead of merging with previous user text
The system SHALL treat new user speech while an assistant response is pending as a new interrupted input, not as a continuation appended to the previous user turn.

#### Scenario: Partial speech arrives while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant has not started speaking
- **AND** the recognizer emits a new partial phrase
- **THEN** the system cancels the pending assistant response
- **AND** it captures the new phrase without prepending the previous user turn

#### Scenario: Final speech arrives while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant has not started speaking
- **AND** the recognizer emits a new final phrase that is not a correction of the current turn
- **THEN** the system submits the new phrase as its own user turn
- **AND** it does not concatenate the previous user turn into the submitted text

#### Scenario: Voice activity starts while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant response is still pending
- **AND** microphone voice activity is detected before recognition text exists
- **THEN** the system immediately cancels the pending assistant response and playback
- **AND** the following partial or final recognition text is captured as the new user turn

#### Scenario: Incremental partials arrive while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant response is still pending
- **AND** the recognizer emits multiple partial prefixes for the same utterance before a final result
- **THEN** the system keeps updating one active partial input
- **AND** it does not submit each prefix as a separate user message

#### Scenario: Low-level microphone activity occurs while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant response is still pending
- **AND** microphone activity is below the immediate barge-in level
- **THEN** the system does not enter the interrupted state
- **AND** it does not cancel the pending response

#### Scenario: Unknown short microphone activity occurs while assistant response is pending
- **WHEN** a user turn has been submitted and the assistant response is still pending
- **AND** microphone activity has unknown source or insufficient sustained duration
- **THEN** the system waits for recognition text instead of entering interrupted state
- **AND** it does not cancel the pending response

#### Scenario: Short incremental partial prefixes arrive while listening
- **WHEN** the recognizer emits short partial prefixes for the same utterance such as "1", "12", and "123"
- **THEN** the system does not display or submit each prefix as a separate user input
- **AND** the final recognition text is submitted once when it arrives

#### Scenario: Audio-only interruption produces no recognition text
- **WHEN** microphone activity interrupts assistant playback before recognition text exists
- **AND** no partial or final recognition text follows within the recovery window
- **THEN** the system leaves interrupted input capture
- **AND** it does not submit an empty user turn

#### Scenario: Short discourse lead-in finals arrive before a complete question
- **WHEN** the recognizer emits short finalized lead-in fragments such as "好的然后" and "好的，然后当前。"
- **AND** a complete user question follows within the lead-in hold window
- **THEN** the system submits one merged user turn
- **AND** it does not display each lead-in fragment as a separate user message

### Requirement: Turn latency can be measured
The system SHALL expose lightweight diagnostic timing for user submission, assistant response start, and playback start.

#### Scenario: User turn is submitted
- **WHEN** the system submits a user turn
- **THEN** it records a timestamp for the submitted turn

#### Scenario: Assistant starts responding
- **WHEN** the first assistant token or final assistant response is received for a turn
- **THEN** the system records and logs the elapsed response-start latency for that turn

### Requirement: Simulator Azure mode uses configured neural voice
The system SHALL use the configured Azure speech synthesizer in simulator Azure mode when Azure Speech credentials are available.

#### Scenario: Simulator runs in explicit Azure mode
- **WHEN** the speech service factory is asked for Azure mode in the simulator with valid Azure Speech configuration
- **THEN** it creates Azure recognition and Azure synthesis services

### Requirement: Azure speech playback can be cancelled during speech
The system SHALL allow playback cancellation to reach Azure Speech synthesis while an utterance is actively being spoken.

#### Scenario: User interrupts Azure TTS playback
- **WHEN** Azure TTS is speaking and the coordinator requests playback cancellation
- **THEN** the synthesizer calls the Azure stop API without waiting for the current utterance to finish
