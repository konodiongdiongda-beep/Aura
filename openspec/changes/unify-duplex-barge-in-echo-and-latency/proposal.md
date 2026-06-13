## Why

The current realtime voice loop blocks playback-window partial text until speaker verification, which makes barge-in fail when the audio evidence path is unavailable or delayed. The same loop also waits for backend/TTS output before the user hears anything, increasing perceived response latency.

## What Changes

- Define one duplex turn policy for assistant playback: reject assistant echo first, accept meaningful non-echo user partial/final text as a barge-in, and keep background/other-speaker rejection intact.
- Add a cancelable local prelude response that can start immediately after a user turn is submitted while backend text/TTS is still loading.
- Ensure local prelude audio is remembered as assistant speech for echo rejection but is not added as an assistant chat message.
- Keep the live backend endpoint on port `6007`; port `8007` is not part of this change.

## Capabilities

### New Capabilities
- `duplex-voice-turn-control`: Unified playback barge-in, assistant echo rejection, background filtering, and local response prelude behavior.

### Modified Capabilities

## Impact

- Affects `VoiceCore` coordinator state policy, playback queue usage, and deterministic regression tests.
- Affects OpenSpec architecture documentation where text-only playback interruption was previously forbidden.
- No backend API change and no default port change.
