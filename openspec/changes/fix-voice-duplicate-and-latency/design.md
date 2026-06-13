## Overview

The duplicate issue is caused by comparing raw recognition strings. Short Chinese partials and finals can differ only by punctuation or whitespace, which currently bypasses duplicate detection. The latency issue needs explicit coordinator state/metadata so the UI can distinguish normal short thinking from a backend response that is taking too long.

## Design

- Add normalized turn comparison that removes punctuation, whitespace, and case/diacritic differences before deciding whether a final recognition result duplicates the submitted current user turn.
- Reuse that normalized comparison in correction/merge paths so formatting-only finals can update the existing bubble if desired, without creating a second message or chat request.
- Add a response-start watchdog task started when a user turn is submitted and cancelled when the first assistant update arrives, the turn is invalidated, or the call ends.
- Add a separate hard startup timeout that turns a stalled pending response into a clear timeout error. This keeps the slow-response hint as a short-lived waiting state while preventing an indefinite `.thinking` state if the backend accepts the WebSocket connection but never streams a message.
- Expose slow-response information through `lastLatencyDebugText`; the app view model can use that to render a more explicit detail while remaining in `.thinking`.

## Risks

- Over-normalization can collapse deliberately repeated short phrases. Mitigation: only apply this duplicate path to the currently submitted turn before assistant response start, where a partial/final formatting revision is expected.
- A slow-response status does not make the backend faster. It prevents the user from seeing an ambiguous indefinite thinking state and gives us instrumentation for response startup latency.
- The hard timeout can end a legitimate but very slow backend response. Mitigation: set the default longer than the slow-response hint and only trigger it before any assistant token or final response has arrived.
