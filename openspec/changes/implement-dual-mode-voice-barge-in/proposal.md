## Why

The voice assistant still treats normal user recording and assistant-playback barge-in as one continuous recognition path. That means assistant playback can still leak into microphone recognition, and partial recognition during playback can interrupt too early. The app also crashed while reading rolling PCM evidence for speaker checks.

## What Changes

- Split voice input behavior into normal listening and assistant-playback barge-in modes.
- Use Apple call-style audio settings more fully by preferring echo-cancelled input when available.
- During assistant playback, suppress normal partial submission and only allow user interruption after local speaker evidence verifies the current user.
- Attach recent PCM evidence to voice activity so barge-in can be checked earlier than waiting for Azure final text.
- Fix rolling PCM snapshot safety so speaker evidence lookup cannot crash the voice session.
- Improve response speed by reducing the first spoken segment threshold.

## Capabilities

### New Capabilities
- `dual-mode-voice-barge-in`: Separate normal recording from playback-time user interruption detection.

### Modified Capabilities
- Runtime audio session setup, microphone evidence capture, coordinator input policy, and TTS first-segment timing.

## Impact

- Affected code: `VoiceCore` speech contracts/coordinator, app audio session and Azure input stream, speech factory, TTS queue configuration.
- No new third-party dependency.
- This uses Apple audio processing as a helper, not as the only protection.
