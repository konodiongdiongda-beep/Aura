## 1. Regression Coverage

- [x] 1.1 Add a coordinator test for `嘿晚上好` partial followed by `嘿，晚上好。` final.
- [x] 1.2 Add a coordinator test for visible slow-response feedback before the first assistant token.

## 2. Core Implementation

- [x] 2.1 Normalize punctuation/spacing when detecting duplicate current turns.
- [x] 2.2 Add a response-start watchdog and clear it when assistant output begins.
- [x] 2.3 Surface the slow-response detail in the iOS call view model.
- [x] 2.4 Add a hard assistant startup timeout so backend stalls do not leave the call indefinitely thinking.
- [x] 2.5 Clear submitted user partial text from the active transcript line and show timeout error detail in the call UI.

## 3. Verification

- [x] 3.1 Run focused `VoiceCore` coordinator tests.
- [x] 3.2 Run relevant app tests or document unrelated failures.
- [x] 3.3 Build, install, and launch the app on iOS Simulator.

## Verification Notes

- Focused `VoiceCore` coordinator tests passed for duplicate Chinese partial/final, slow-response status, hard response timeout, and clearing submitted active partial text.
- Full `VoiceCore` suite passed: 76 tests, 0 failures.
- Focused app tests passed: `AuraVoiceAssistantTests/VoiceCallViewModelTests/testThinkingStatusShowsSlowAssistantResponseDetail` and `testErrorStatusShowsSpecificErrorDetail`.
- Built, installed, and launched `com.aura.voiceassistant` on iPhone 17 Pro Simulator `04CD7E3E-93BA-472B-957F-0BBC54B03CBE`.
- Manual WebSocket probe with real content `嘿晚上好` connected to `ws://43.98.164.20:8007/ws/chat`, but received 0 messages within 20 seconds for both `voice_mode=false` and `voice_mode=true`; client-side timeout handling is required because the backend can currently accept the connection without streaming a first response.
