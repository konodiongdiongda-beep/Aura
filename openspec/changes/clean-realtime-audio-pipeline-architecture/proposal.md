## Why

The realtime voice loop now has the right functional direction, but the implementation boundary is still too implicit. Audio capture, platform voice processing, reference AEC, local voice activity, rolling audio evidence, speaker evidence, and final turn-submission policy are easy to confuse because several responsibilities are concentrated in the live Azure input path.

That makes future fixes risky: a latency tweak can accidentally weaken echo rejection, and a speaker-evidence tweak can be mistaken for acoustic echo cancellation.

## What Changes

- Define the realtime audio pipeline as a layered architecture:
  - platform audio session and voice processing
  - optional far-end reference echo processing
  - microphone PCM conversion and evidence buffering
  - sustained voice activity events
  - speaker-evidence classification
  - coordinator turn policy, text echo fallback, ASR revision deduplication
- Refactor live Azure microphone input so VAD/event emission and rolling evidence buffering are separate helper components.
- Rename/debug-label non-production acoustic and speaker heuristics so the runtime boundary is explicit.
- Preserve the current behavioral guarantees:
  - assistant speaker stays enabled
  - verified user speech can barge in
  - assistant playback echo cannot become user input
  - one spoken sentence does not create duplicate turns

## Impact

- `VoiceCore` remains the shared, testable policy layer.
- `AuraVoiceAssistant` remains the app-side AVFoundation/Azure implementation layer.
- No provider swap is required in this change.
- Real-device acoustic quality still needs physical route testing; simulator tests can only verify policy and wiring.
