## Why

The speaker isolation chain now supports evidence, but the app runtime still defaults to a no-op speaker evidence provider. This means live microphone finals can carry no speaker decision, so bystander rejection only exists in tests/replay unless a real provider is wired.

## What Changes

- Add an app-side adaptive prototype speaker evidence provider that computes lightweight embeddings from recent 16 kHz PCM.
- Let the provider enroll early accepted speech into a current-user profile and classify later finals as verified current user, other speaker, or uncertain.
- Wire Azure speech recognition to use the adaptive provider by default.
- Add focused tests for enrollment, current-user acceptance, bystander rejection, and uncertain handling.

## Capabilities

### New Capabilities
- `adaptive-speaker-evidence-provider`: Runtime prototype provider that turns live PCM evidence into speaker decisions.

### Modified Capabilities

## Impact

- Affected code: app speech services and tests.
- No third-party ML dependency is introduced.
- The provider is a runtime prototype, not a production biometric model; the existing evidence provider protocol remains the replacement point for ONNX/CoreML.
