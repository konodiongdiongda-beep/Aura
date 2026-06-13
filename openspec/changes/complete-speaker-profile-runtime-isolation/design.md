## Context

The current system has three partial protections:

- iOS audio processing uses `.voiceChat` and app-owned PCM input attempts to enable voice processing.
- `VoiceCallCoordinator` strips text that closely matches recent assistant speech.
- `PlaybackAwareUserTurnSubmissionGate` rejects playback-window final recognition before it is marked as a user interruption.

These do not identify who spoke. A bystander can still be submitted while the assistant is not playing, and a true user interruption during playback needs a profile-backed path to be accepted without reopening the AI self-echo hole.

Open-source review shows speaker embedding is the appropriate abstraction: SpeechBrain ECAPA-TDNN provides speaker verification/embedding tooling, WeSpeaker focuses on speaker embedding and verification, and sherpa-onnx has mobile-oriented speaker identification examples. The app should not hard-code one model into coordination logic; it should define a small extractor/scorer seam and keep policy in `VoiceCore`.

## Goals / Non-Goals

**Goals:**
- Make recognition submission depend on audio evidence and speaker/profile decision, not only recognized text.
- Reject AI playback, bystander, and uncertain-speaker candidates before chat submission.
- Allow verified current-user speech both during normal listening and while interrupting AI playback.
- Provide deterministic replay reports for recorded user, generated AI playback, other speaker surrogate, and mixed audio.
- Keep model implementation replaceable: current lightweight verifier for chain validation, future ONNX/CoreML verifier for production accuracy.

**Non-Goals:**
- Do not claim bank-grade biometric security.
- Do not bundle a large third-party model until model size, license, and iOS runtime cost are explicitly accepted.
- Do not remove iOS voice processing/AEC; it remains a first-stage signal cleanup layer.

## Decisions

- Extend `UserTurnSubmissionCandidate` with optional speaker verification evidence.
  - Rationale: the coordinator already owns the final submit decision. Adding evidence there prevents app-layer bypass and keeps tests in `VoiceCore`.
  - Alternative considered: do speaker checks inside Azure recognizer only. Rejected because mock recognizers and future STT providers must share the same policy.

- Introduce a profile-backed gate with conservative fallback.
  - Rationale: if a profile exists and audio evidence is available, decisions must be based on speaker score. If evidence is missing during playback, reject rather than submit unknown echo.
  - Alternative considered: accept unknown speakers outside playback. Rejected because the user's explicit requirement is to reject bystanders too.

- Capture a rolling PCM window in `ProcessedAzureAudioInputStream` and attach it to recognition finals through a runtime evidence provider.
  - Rationale: Azure final events contain text, not the audio slice. The app-owned PCM stream is the only local place where we can correlate recent mic audio with recognition timing.
  - Alternative considered: rely on Azure speaker recognition APIs. Rejected for this change because it would add vendor-specific enrollment/runtime dependencies and still needs local gating.

- Use deterministic replay tooling as the first validation target.
  - Rationale: Simulator acoustic behavior varies by Mac speaker/mic and room. File-driven replay gives repeatable failures and pass/fail reports.
  - Alternative considered: only manual Simulator testing. Rejected because it cannot prove bystander and mixed-audio behavior.

## Risks / Trade-offs

- Lightweight embeddings may reject or accept incorrectly in difficult acoustic conditions. Mitigation: use them to validate chain behavior, keep extractor replaceable, and require strict uncertain-as-reject policy.
- Rejecting uncertain speakers can block valid users until enrollment has enough audio. Mitigation: require a visible profile state and allow enrollment refresh.
- Mixed user + AI playback can be difficult. Mitigation: accept only when current-user score clears playback threshold and margin; otherwise do not submit.
- Simulator is not a true iPhone acoustic environment. Mitigation: keep Simulator replay validation and require true-device QA before production release.
