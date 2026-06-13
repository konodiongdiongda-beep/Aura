## Context

Three user recordings now exist in `tmp/voice_samples/`. The app already has `VoiceActivityEvent.source` and `SpeakerVerifying` seams, but no real verifier. The next useful step is an offline backend-style chain that simulates audio input and verifies decision behavior before doing iOS UI/model work.

## Goals / Non-Goals

**Goals:**

- Build an enrollment profile from the recorded current-user samples.
- Score candidate WAV files against that profile.
- Simulate AI playback and mixed user+AI audio using local generated audio.
- Emit deterministic JSON reports with accept/reject decisions and scores.
- Keep the model extractor replaceable.

**Non-Goals:**

- Claim production-grade voice biometrics from the lightweight prototype.
- Store private voice samples in committed source files.
- Add a mobile on-device ML runtime in this change.
- Solve overlapping two-human source separation without a real target-speaker model.

## Decisions

- Use a self-contained numpy-based MFCC-like embedding for the prototype because heavyweight speaker-model packages are not installed locally. This gives a deterministic chain to test gate behavior, not final biometric quality.
- Use cosine similarity against an enrollment centroid. The threshold is configurable and calibrated from positive holdout scores when possible.
- Generate AI playback with macOS `say` plus `ffmpeg` conversion so the negative test does not require an external service.
- Generate mixed samples by summing normalized WAV signals. This tests whether the gate weakens confidence when AI playback contaminates user audio.
- Report decisions as `accepted_current_user`, `rejected_non_user`, or `uncertain`, matching the future app gate vocabulary.

## Risks / Trade-offs

- Lightweight acoustic features are weaker than ECAPA/WeSpeaker embeddings. Mitigation: keep the extractor contract isolated and mark reports as prototype output.
- Generated macOS TTS is not identical to the app's Azure TTS. Mitigation: use it first to validate the chain, then replay real Azure output once captured.
- Mixed audio acceptance may vary by volume ratio. Mitigation: generate multiple mix ratios and record the score trend.
- Three short samples are enough for a prototype but not enough for robust production enrollment. Mitigation: request more enrollment phrases before production tuning.
