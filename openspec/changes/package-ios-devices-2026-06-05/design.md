## Design

Use Xcode archive/export for a physical iOS device build. Prefer existing automatic signing when it can produce a provisioning profile for `com.aura.voiceassistant`; otherwise stop with the exact signing blocker rather than modifying bundle identifiers or embedding an unrelated profile.

## Verification

Validate the OpenSpec change, then run archive/export commands and inspect their exit status and generated artifacts.
