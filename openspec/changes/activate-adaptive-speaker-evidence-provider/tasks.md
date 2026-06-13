## 1. Provider

- [x] 1.1 Add adaptive speaker evidence provider implementation in the app speech services.
- [x] 1.2 Add tests for enrollment, verified match, other speaker rejection, and uncertain decisions.

## 2. Runtime Wiring

- [x] 2.1 Wire Azure speech recognition to use the adaptive provider by default.
- [x] 2.2 Keep mock/simulator fallback behavior stable.

## 3. Validation

- [x] 3.1 Run `swift test --package-path VoiceCore`.
- [x] 3.2 Run iOS workspace tests.
- [x] 3.3 Run `openspec validate activate-adaptive-speaker-evidence-provider --strict`.
- [x] 3.4 Launch the updated app in iPhone 17 Simulator.
