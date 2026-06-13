## ADDED Requirements

### Requirement: Continuous Azure speech recognition
The app SHALL use Microsoft Azure Speech SDK to recognize user speech from the device microphone during active calls.

#### Scenario: User speaks during listening state
- **WHEN** the call is active, unmuted, and in listening state
- **THEN** the app SHALL stream microphone input to Azure Speech recognition and produce partial and final transcript updates.

#### Scenario: Azure recognition starts during a call
- **WHEN** Azure continuous recognition is started for an active voice call
- **THEN** the app SHALL feed Azure STT with an app-owned processed microphone PCM stream instead of the Azure SDK default microphone capture.
- **AND** the stream SHALL use iOS voice-processing capture where supported before audio reaches Azure recognition.

#### Scenario: User mutes the microphone
- **WHEN** the user enables mute
- **THEN** the app SHALL stop submitting microphone audio for recognition until mute is disabled.

### Requirement: Azure text-to-speech playback
The app SHALL synthesize AI response text through Microsoft Azure Speech TTS and play it through the iOS audio session.

#### Scenario: A complete sentence is available
- **WHEN** streamed AI text contains a complete sentence or the response finishes
- **THEN** the app SHALL enqueue that text for Azure TTS synthesis and playback.

#### Scenario: TTS synthesis fails
- **WHEN** Azure TTS returns an error for a segment
- **THEN** the app SHALL keep the text visible, mark speech output as failed for that segment, and continue the call without crashing.

### Requirement: Speech playback interruption
The app SHALL allow current and queued AI speech playback to be cancelled immediately.

#### Scenario: User barge-in occurs during AI playback
- **WHEN** the app detects valid user speech while AI audio is playing
- **THEN** the app SHALL stop current playback, clear queued TTS segments, and prevent cancelled segments from resuming.

### Requirement: Audio session lifecycle
The app SHALL configure and restore the iOS audio session around active calls.

#### Scenario: Call starts
- **WHEN** a voice call starts
- **THEN** the app SHALL configure `AVAudioSession` for play-and-record voice interaction with speaker output by default.

#### Scenario: Call ends
- **WHEN** the user ends the call
- **THEN** the app SHALL stop recognition, stop playback, clear transient audio buffers, and deactivate or restore the audio session.
