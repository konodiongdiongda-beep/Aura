## ADDED Requirements

### Requirement: Voice processing audio capture
The app SHALL use iOS voice-processing audio session settings to reduce echo and noise during simultaneous microphone capture and AI playback.

#### Scenario: AI audio is playing while microphone remains active
- **WHEN** synthesized AI speech is playing through the device speaker
- **THEN** the app SHALL keep capture in a voice-processing mode intended for echo cancellation and voice calls.

### Requirement: Voice activity filtering
The app SHALL apply local voice activity and noise-gate filtering before treating microphone input as user speech or barge-in.

#### Scenario: Ambient noise occurs
- **WHEN** microphone input is below configured speech thresholds or lacks sustained voice activity
- **THEN** the app SHALL not submit it as a user turn and SHALL not interrupt AI playback.

#### Scenario: Sustained user speech occurs during AI playback
- **WHEN** microphone input exceeds speech thresholds for the configured minimum duration while AI is speaking
- **THEN** the app SHALL trigger barge-in interruption.

### Requirement: Optional enrolled-speaker verification
The app SHALL support optional enrolled-speaker verification to reduce accepting other people as the active user.

#### Scenario: User enrolls voice profile
- **WHEN** the user records the required enrollment speech in settings
- **THEN** the app SHALL store the resulting speaker profile reference locally without storing Azure subscription secrets in source code.

#### Scenario: Other speaker is detected with sufficient audio
- **WHEN** speaker verification returns a failed or below-threshold match for an utterance with sufficient verification audio
- **THEN** the app SHALL not send that utterance to the chat API and SHALL show that the voice was not accepted as the enrolled user.

### Requirement: Confidence-aware fallback
The app SHALL be explicit when speaker verification cannot confidently decide.

#### Scenario: Barge-in utterance is too short for speaker verification
- **WHEN** a short utterance triggers barge-in but does not contain enough audio for reliable speaker verification
- **THEN** the app SHALL apply local VAD/echo filtering and mark the speaker verification result as unavailable rather than claiming the speaker was verified.
