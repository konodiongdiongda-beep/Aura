## Overview

The app currently models the keyboard Text Input screen as a normal `AppTab` case, so `BottomNavigationBar` renders it automatically through `AppTab.allCases`. The change separates all tab cases from user-facing bottom navigation items and removes the keyboard route from the `ContentView` switch.

## Decisions

- Keep `AppTab` focused on visible app destinations: history, voice, and settings.
- Remove the `.keyboard` case instead of only hiding it, because the request is to delete the page and its bottom-bar marker from the primary UI.
- Leave `DebugTextEntryView` source in place for now because this change only removes the page from main navigation; deleting the file can be handled separately if the project no longer needs the debug utility.

## Risks

- If any debug workflow still depends on launching Text Input through the bottom bar, it will no longer be accessible from the app UI.
- Previews or tests referencing `.keyboard` must be updated or removed.

## Validation

- Add a unit test proving visible tabs are only history, voice, and settings.
- Build or test the iOS app target to catch Swift compile issues.
