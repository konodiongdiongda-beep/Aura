## 1. Endpoint Configuration

- [x] 1.1 Add focused coverage for default VoiceCore and app endpoint ports.
- [x] 1.2 Change default chat and history endpoints from port 8007 to 6007.
- [x] 1.3 Update local debug xcconfig defaults and sample config to port 6007.

## 2. Verification

- [x] 2.1 Run focused endpoint/config tests.
- [x] 2.2 Run `VoiceCore` tests or the relevant subset.
- [x] 2.3 Build, install, and launch the app on Simulator.
- [x] 2.4 Validate the OpenSpec change.

## 3. Verification Notes

- Focused VoiceCore endpoint test passed.
- Focused app config endpoint test passed.
- Full `VoiceCore` test suite passed with 77 tests and 0 failures.
- Runtime/config source search found no remaining old debug port references in current app paths.
- Simulator build, install, and launch passed on iPhone 17 Pro simulator.
- `openspec validate switch-default-backend-port-6007 --strict` passed.
