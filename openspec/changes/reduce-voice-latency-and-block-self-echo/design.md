## Context

The current coordinator treats recognized text during assistant playback as a barge-in unless semantic echo filtering rejects it. This is fragile because speaker playback is still physically captured by the microphone. The app also lacks timing markers across recognition, chat, and playback, so perceived latency cannot be attributed to a specific segment.

## Goals / Non-Goals

**Goals:**
- Prevent assistant playback from being submitted as user speech.
- Keep user interruption support through the existing voice-activity gate, where acoustic/speaker checks can be layered in.
- Add low-overhead timing diagnostics to expose recognition-to-chat and chat-to-playback latency.
- Keep the change local and testable in the current Azure/WebSocket architecture.

**Non-Goals:**
- Replace the current stack with Azure Voice Live or OpenAI Realtime.
- Add real speaker verification or voiceprint enrollment in this change.
- Rework the backend streaming protocol.

## Decisions

- Recognition text received while `state == .speaking` will first go through assistant-echo rejection. Non-echo text will be treated as a user barge-in so playback stops immediately.
- Explicit interruption continues through `evaluateBargeIn`, because that path is designed for future audio-level activity decisions.
- User turn text will be normalized before submission to collapse duplicated phrases caused by unstable partial/final recognition.
- Timing diagnostics will be kept as simple coordinator debug fields and console logs instead of a new telemetry dependency.
- Simulator Azure mode will use the same Azure synthesizer as device mode when Azure credentials are configured. The local iOS synthesizer remains available only as a fallback type, not as the Azure-mode default.
- The microphone capture path will emit lightweight voice-activity events from audio levels. While the assistant is speaking, the coordinator will cancel playback on voice activity immediately, then wait for partial/final recognition text to fill and submit the interrupted user turn.
- Azure TTS playback will run the blocking SDK `speakText` call outside the synthesizer actor so `cancel()` can enter the actor immediately and call `stopSpeaking()` during active playback.
- Voice activity should also cancel playback during the short tail after the backend stream completes, because TTS playback can still be audible after the chat stream has already returned the coordinator to listening.
- Duplicate utterance collapse should handle short Chinese repeated phrases with filler words and punctuation, not only long utterances that split into two 12+ character halves.

## Risks / Trade-offs

- Text-only barge-in while assistant is speaking becomes stricter. This is intentional until a real acoustic/speaker verification path is wired into production.
- Latency logging does not itself reduce backend/model latency, but it identifies which segment must be optimized next.
- Azure TTS in simulator can add network latency relative to local iOS speech, but it gives the realistic voice quality needed for manual acceptance testing.
- Audio-level activity can include residual playback echo. The existing iOS voice processing and later text echo filtering still remain in place; this change prioritizes immediate user barge-in over waiting for cloud text.
- Azure SDK cancellation depends on `stopSpeaking()` interrupting the current SDK playback; the actor must not be blocked by the synchronous SDK call while cancellation is requested.
- Allowing voice activity during the recent-assistant-speech tail may call playback cancellation when audio has already ended. This is acceptable because cancelling an idle playback queue is harmless and prevents the worse failure where audible TTS cannot be interrupted.
