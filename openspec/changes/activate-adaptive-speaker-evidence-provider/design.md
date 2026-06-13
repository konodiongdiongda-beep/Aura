## Context

`AzureSpeechRecognizer` can now attach `UserTurnSpeakerEvidence` to final recognition events, and `SpeechServiceFactory` uses a profile-aware submission gate. However, the default provider is still `NoopUserTurnSpeakerEvidenceProvider`, so live App behavior cannot distinguish a bystander from the current user outside deterministic tests.

## Goals / Non-Goals

**Goals:**
- Replace the Azure runtime no-op evidence provider with a lightweight adaptive provider.
- Build an in-memory current-user profile from early speech samples.
- Reject later non-matching or uncertain samples through the existing profile-aware gate.
- Keep all production-model assumptions behind `UserTurnSpeakerEvidenceProviding`.

**Non-Goals:**
- Do not claim strong biometric security.
- Do not persist the adaptive profile across app launches in this change.
- Do not add a large model runtime or a new third-party dependency.

## Decisions

- Use deterministic signal features from PCM as a prototype embedding.
  - Rationale: it proves the live evidence path and keeps the app build simple.
  - Alternative considered: immediately add ONNX/CoreML. Rejected because model/license/runtime footprint should be chosen explicitly after the chain is correct.

- Enroll a small number of early samples before enforcing profile decisions.
  - Rationale: the app currently has no enrollment UI, and the user explicitly described voiceprint collection while the user speaks.
  - Alternative considered: strict mode before profile exists. Rejected because it would block normal conversation before enrollment.

- Keep playback echo protection in the gate before trusting evidence.
  - Rationale: a weak prototype must never reopen the AI self-echo path.

## Risks / Trade-offs

- If a bystander speaks before the current user profile is mature, the prototype can learn the wrong voice. Mitigation: this is a prototype provider; production should add explicit enrollment prompts or a stronger pre-existing profile.
- Lightweight features are less accurate than ECAPA/ONNX embeddings. Mitigation: uncertain results are rejected once a profile exists, and the adapter can be replaced without changing coordinator policy.
