## Why

The app needs a native iOS voice-call experience similar to Doubao where users can speak naturally, see the transcript on screen, hear the model reply, and interrupt the model while it is speaking. The current workspace only provides chat/history API material and visual references, so the behavior must be specified before implementation.

## What Changes

- Create a native SwiftUI iOS app shell that follows the provided Aura/Lumina visual design for idle, in-call, history, and settings states.
- Add Microsoft Azure Speech speech-to-text and text-to-speech integration for real-time spoken conversation.
- Add a WebSocket chat client for the provided `ws://43.98.164.20:8007/ws/chat` streaming interface and parse token/final events into screen text and speech output.
- Add barge-in interruption so user speech during AI audio playback stops the current playback, clears pending speech, recognizes the new user utterance, and sends a fresh chat request.
- Add microphone/audio handling for echo cancellation, noise reduction, voice activity detection, and optional speaker verification to reduce other-speaker input.
- Add conversation history views backed by the provided history APIs for debugging and continuity.
- Keep Azure Speech credentials outside source control and surface missing key/region as a settings/configuration error.

## Capabilities

### New Capabilities

- `native-ios-voice-call-ui`: SwiftUI screens, visual states, controls, transcript display, and call lifecycle UI modeled after the provided design materials.
- `azure-speech-conversation`: Azure Speech STT/TTS integration, audio session management, continuous recognition, sentence-based synthesis, and playback queue control.
- `streaming-chat-integration`: WebSocket chat request generation, streaming response parsing, final result handling, and request/session identifier rules from the provided API document.
- `voice-isolation-speaker-filtering`: Noise suppression, echo cancellation, voice activity detection, barge-in trigger filtering, and optional enrolled-speaker verification.
- `conversation-history`: History list and message list integration using the provided HTTP endpoints.

### Modified Capabilities

- None. This workspace has no existing OpenSpec specs.

## Impact

- Adds a new native iOS Swift/SwiftUI codebase under this workspace.
- Adds dependencies on Microsoft Azure Speech SDK for iOS and Apple AVFoundation audio APIs.
- Uses the provided backend endpoints:
  - `POST http://43.98.164.20:8007/history/user/page`
  - `POST http://43.98.164.20:8007/history-with-alerts/`
  - `ws://43.98.164.20:8007/ws/chat`
- Requires runtime configuration for Azure Speech subscription key, region, and preferred voice name.
- Requires iOS microphone permission and true-device validation because simulator audio behavior is insufficient for call interruption and echo cancellation.
