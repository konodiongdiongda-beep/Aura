## Why

Real voice calls still show the same short Chinese utterance as two user messages when Azure emits an unpunctuated partial followed by a punctuated final. Users also wait too long with only the generic thinking state when the chat backend does not produce an early token.

## What Changes

- Treat punctuation-only and spacing-only recognition revisions as the same user turn, including short Chinese utterances such as `嘿晚上好` and `嘿，晚上好。`.
- Keep sending one chat request for a single spoken utterance; do not create a second transcript bubble for final recognition that only formats the partial.
- Add a visible slow-response state when no assistant token arrives quickly after a user turn submission.
- End the pending turn with a clear timeout error if no assistant output arrives after the hard startup timeout, instead of leaving the call indefinitely in thinking.
- Preserve existing barge-in and genuine follow-up speech behavior.

## Capabilities

### New Capabilities
- `voice-turn-deduplication`: Covers single-turn normalization across partial/final recognition events.
- `voice-response-latency-feedback`: Covers user-visible feedback when assistant response startup is slow.

### Modified Capabilities

## Impact

- Affects `VoiceCore/Sources/VoiceCore/Services/VoiceCallCoordinator.swift`
- Affects `VoiceCore/Sources/VoiceCore/Models/AppError.swift`
- Affects `VoiceCore/Tests/VoiceCoreTests/VoiceCallCoordinatorTests.swift`
- May affect localized status detail text in the iOS call UI.
