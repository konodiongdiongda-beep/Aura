## 1. Standards

- [x] 1.1 Add OpenSpec requirements for layered realtime audio processing.
- [x] 1.2 Add design notes documenting Apple voice processing, far-end reference AEC, heuristic speaker evidence, and turn-policy boundaries.

## 2. Implementation

- [x] 2.1 Extract rolling PCM evidence buffering from `ProcessedAzureAudioInputStream`.
- [x] 2.2 Extract sustained voice-activity emission from `ProcessedAzureAudioInputStream`.
- [x] 2.3 Rename/debug-label non-production fallback echo processing.
- [x] 2.4 Rename app-side adaptive speaker evidence as heuristic speaker evidence.

## 3. Tests

- [x] 3.1 Add focused tests for extracted audio evidence buffering.
- [x] 3.2 Update existing AEC and speaker-evidence tests for the new names without changing behavior.

## 4. Verification

- [x] 4.1 Run app unit tests that cover speech services.
- [x] 4.2 Run full `swift test --package-path VoiceCore`.
- [x] 4.3 Run strict OpenSpec validation for this change.
- [x] 4.4 Regenerate/build the iOS workspace.
