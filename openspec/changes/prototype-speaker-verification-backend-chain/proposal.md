## Why

The app needs a current-user priority signal so AI playback, nearby speakers, and environment audio are not submitted as user turns. Before wiring a production on-device model into iOS, we need a backend/offline prototype that proves the enrollment, scoring, and gate logic with recorded samples and simulated AI playback.

## What Changes

- Add an offline speaker-verification prototype that enrolls a user voice profile from recorded WAV samples.
- Add a repeatable test harness that scores candidate audio against the enrolled profile.
- Generate AI/robot playback and mixed user+AI samples to test whether the gate accepts or rejects candidate input.
- Keep the extractor implementation swappable so a future ECAPA/WeSpeaker/SpeechBrain model can replace the lightweight prototype without changing the decision contract.

## Capabilities

### New Capabilities
- `speaker-verification-backend-prototype`: Offline enrollment, candidate scoring, and decision reporting for current-user voice verification.

### Modified Capabilities
- `voice-isolation-speaker-filtering`: Current-user verification gains an offline prototype path before production iOS integration.

## Impact

- Adds Python prototype scripts and tests under `tools/speaker_verification/`.
- Uses local samples under `tmp/voice_samples/`.
- Produces generated debug artifacts under `tmp/speaker_verification/`.
- Does not commit user voice samples or generated enrollment artifacts into source.
