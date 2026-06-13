## Context

The app runs on iOS and already uses `playAndRecord` with `voiceChat`, plus `AVAudioInputNode.setVoiceProcessingEnabled(true)`. Those settings help reduce speaker echo, but they do not define the product policy for when microphone audio should become user input.

The current policy is still too close to "always listen, then filter later." The desired behavior is:

- Normal mode: listen quickly and submit current-user speech.
- Assistant playback mode: do not submit recognized text by default; only stop playback and open the user turn after the current user is verified.

The crash report shows a separate bug in `RollingPCMAudioBuffer.snapshot(maxDuration:)` while Azure final recognition asks for recent PCM evidence.

## Goals / Non-Goals

**Goals:**
- Keep normal user recording fast.
- Treat assistant playback as a guarded mode where microphone input is not trusted by default.
- Use Apple echo-cancelled input preference when available.
- Verify user barge-in from voice activity audio before cancelling assistant playback.
- Prevent rolling PCM snapshot crashes.

**Non-Goals:**
- Do not add a production speaker embedding model in this change.
- Do not add enrollment UI.
- Do not depend on Azure to solve local speaker echo.

## Decisions

- Keep Azure continuous recognition running, but coordinator policy decides which events are trusted.
  - Rationale: This is a smaller change than starting/stopping Azure on every playback segment, and it avoids recognizer startup latency.

- During playback, ignore partial text as a user turn.
  - Rationale: partial text has no speaker evidence and can be assistant echo.

- Attach `SpeechAudioEvidence` to `VoiceActivityEvent`.
  - Rationale: it allows earlier speaker verification for barge-in than waiting for Azure final recognition.

- Ask `AVAudioSession` for echo-cancelled input when available.
  - Rationale: Apple audio processing reduces leakage before our policy layer sees it.

- Lower first TTS segment length.
  - Rationale: speaking the first chunk sooner improves perceived response speed.

## Risks / Trade-offs

- If no current-user profile exists, playback-time barge-in may be rejected until the user speaks normally once.
- Echo cancellation availability depends on device/runtime route.
- The lightweight adaptive provider remains weaker than a production voiceprint model.
