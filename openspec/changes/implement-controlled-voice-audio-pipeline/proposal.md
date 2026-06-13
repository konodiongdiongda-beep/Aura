## Why

The current voice call path can display assistant text without reliably owning the synthesized audio playback lifecycle, and microphone recognition can still accept assistant speaker output or nearby speakers as user input. This change moves the app toward a normal real-time voice-agent pipeline: controlled TTS playback, playback-aware microphone gating, and pluggable current-user verification.

## What Changes

- Add controlled speech playback events so the coordinator knows when TTS playback starts, finishes, or is cancelled.
- Keep the call state in `speaking` while queued assistant audio is still playing, even if the chat stream has completed.
- Route Azure TTS through app-controlled audio-data synthesis and playback where available, instead of relying only on SDK default-speaker playback.
- Expose a playback-aware microphone gate so app-owned audio capture can mark frames as AI playback echo, current-user speech, other-speaker speech, or unknown.
- Add protocol seams for enrolled-speaker verification without claiming a real production voiceprint model in this slice.
- Preserve existing simulator/mock paths and visible filter diagnostics.

## Capabilities

### New Capabilities
- `controlled-voice-audio-pipeline`: Controlled TTS playback, playback-aware input gating, and pluggable speaker verification for voice calls.

### Modified Capabilities
- `voice-turn-control`: Assistant completion behavior changes so playback lifecycle, not only backend stream completion, controls when the call returns to listening.

## Impact

- `VoiceCore` speech protocols, playback queue, coordinator state transitions, mocks, and tests.
- `AuraVoiceAssistant` Azure speech synthesizer, speech service factory, and app-side playback implementation.
- OpenSpec voice isolation and turn-control validation.
- No new committed secrets. Any model or Azure configuration remains injectable through existing app configuration paths.
