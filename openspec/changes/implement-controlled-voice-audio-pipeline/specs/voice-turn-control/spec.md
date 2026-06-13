## MODIFIED Requirements

### Requirement: Assistant playback is not accepted as user input
The system SHALL reject recognition text that is likely assistant playback echo, while allowing non-echo user speech during playback to interrupt the assistant. The system SHALL keep assistant playback lifecycle separate from backend stream lifecycle so queued or active TTS remains interruptible until playback is drained.

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
- **AND** the backend stream has completed but assistant audio playback has not drained
- **THEN** the system immediately cancels playback
- **AND** the following partial or final recognition text is captured as the user turn

#### Scenario: Backend stream completes while assistant audio remains queued
- **WHEN** the backend stream emits completion after assistant speech has been enqueued
- **AND** the playback controller has not emitted playback-drained
- **THEN** the system SHALL remain in speaking state instead of returning to listening

#### Scenario: Assistant playback drains after backend completion
- **WHEN** the backend stream has completed and the playback controller emits playback-drained
- **THEN** the system SHALL return to listening unless another interruption or error state is active
