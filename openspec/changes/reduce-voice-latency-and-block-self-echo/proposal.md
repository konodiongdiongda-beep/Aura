## Why

Voice calls currently feel too slow after the user finishes speaking, and assistant speaker playback can be re-captured as user input, causing self-triggered loops. The app needs a clearer turn-control boundary that prioritizes fast user turn submission and blocks assistant playback from entering recognition.

## What Changes

- Add a playback-aware recognition gate so assistant speech is not accepted as user input while Aura is speaking.
- Keep explicit interruption paths available through voice-activity evaluation rather than treating any recognized text during playback as a barge-in.
- Add lightweight latency markers for recognition, chat, and assistant playback transitions so slow segments can be measured during simulator/device testing.
- Preserve the existing fast partial-submit behavior and existing transcript merge behavior.
- Use configured Azure Neural TTS in simulator Azure mode so manual testing reflects production voice quality instead of the robotic local fallback.
- Interrupt assistant playback as soon as microphone voice activity is detected, before recognition text is available.

## Capabilities

### New Capabilities
- `voice-turn-control`: Defines low-latency turn handling and playback-period self-echo protection for voice calls.

### Modified Capabilities

## Impact

- Affects `VoiceCallCoordinator` recognition handling and diagnostic state.
- Affects Azure microphone audio activity reporting.
- Affects simulator Azure speech service selection.
- Affects tests for barge-in and assistant echo behavior.
- No backend API, dependency, or persistence changes.
