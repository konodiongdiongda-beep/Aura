## Overview

The fix keeps history detail presentation owned by `ContentView` while making the row selection surface explicit in `HistoryListView`.

## Design

- Add a small testable helper on `HistoryListView` for selecting a conversation so the row-to-detail contract can be covered without full SwiftUI UI automation.
- Keep `ContentView`'s `selectedHistoryConversation` overlay presentation and `MessageDetailView` dismissal path unchanged.
- Ensure the history row label exposes a full-width rectangular hit-test area matching the visible card.
- Ensure `GlassPanel`'s decorative stroke overlay does not participate in hit testing, because history rows are rendered inside that shared panel and wrapped by a `Button`.

## Risks

- SwiftUI hit testing is hard to unit test directly; the implementation should combine a testable selection helper with direct coverage that decorative overlays remain outside the hit-test path.
- The change should not make search fields or future row controls accidentally route to details.
