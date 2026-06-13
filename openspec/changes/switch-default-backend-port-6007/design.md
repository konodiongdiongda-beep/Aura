## Design

Keep endpoint construction static and minimal. The only behavior change is the default port number. Existing environment and bundle overrides remain the highest priority, so production or local overrides can still point elsewhere without code changes.

## Verification

Add focused tests for default VoiceCore service endpoints and AppConfig mock endpoints so future port changes are explicit and visible.
