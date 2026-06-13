## Context

`ContentView` owns the app tab selection and renders `BottomNavigationBar`. The voice home screen already starts calls through `VoiceCallViewModel.startCall()`, and the bottom center voice item should remain a navigation control instead of starting the call directly.

## Goals / Non-Goals

**Goals:**
- Keep the existing call-start flow on explicit controls inside the Voice screen.
- Make the bottom center voice item select the Voice screen without starting the call.
- Replace idle call entry microphone iconography with phone iconography.

**Non-Goals:**
- Change the in-call controls, mute behavior, speech pipeline, or backend call coordinator.
- Add new navigation destinations or persistence behavior.

## Decisions

- Keep `BottomNavigationBar` responsible only for tab selection. Voice calls remain owned by controls inside `VoiceRootView` / `VoiceHomeView`.
- Keep non-voice tabs as simple selection actions. History and Settings should not start or stop calls.
- Use SF Symbols phone icons for call entry and keep microphone symbols only for in-call microphone controls or speech-specific UI.

## Risks / Trade-offs

- Users need one extra tap to start a call from outside the Voice screen, but this avoids accidental call starts from navigation.
