## Architecture Standard

Use a layered pipeline. Do not solve assistant echo by muting the speaker.

1. **Route/session layer**
   - Owns `AVAudioSession` category/mode/options.
   - Uses call-style routing: `playAndRecord`, `voiceChat`, speaker output, Bluetooth HFP support, and echo-cancelled input preference where supported.

2. **Capture voice-processing layer**
   - Owns `AVAudioEngine.inputNode.setVoiceProcessingEnabled(true)`.
   - This is the first line of echo reduction because it is closest to hardware and route state.

3. **Far-end reference layer**
   - Captures assistant playback audio and supplies it as far-end reference to the optional echo processor.
   - This follows the common AEC model used by WebRTC-style audio processing: near-end microphone audio is processed with a far-end render/reference stream.
   - Debug processors must be named as debug/test fallbacks, not as production AEC.

4. **Microphone evidence layer**
   - Converts captured audio to PCM16 mono for Azure.
   - Maintains a rolling PCM evidence window for speaker classification.
   - Emits sustained voice-activity events; it does not decide chat submission.

5. **Speaker-evidence layer**
   - Classifies recent audio evidence as current user, other speaker, uncertain, or unavailable.
   - The current implementation is a heuristic provider, not a biometric speaker-recognition system.
   - It must not enroll during assistant playback or interrupted-input windows.

6. **Turn-policy layer**
   - Lives in `VoiceCore`.
   - `VoiceCallCoordinator` remains the final authority for barge-in, stale stream cancellation, ASR revision deduplication, and text echo fallback.
   - Playback-window recognition is evaluated echo-first. Meaningful non-echo user text can start barge-in when audio evidence is unavailable or late; assistant echo, background rejection, and too-short partials remain blocked.

## External Basis

- Apple exposes `AVAudioIONode.setVoiceProcessingEnabled(_:)` for enabling I/O node voice processing.
- Apple exposes `AVAudioSession.setPrefersEchoCancelledInput(_:)` for preferring echo-cancelled input when available.
- WebRTC AudioProcessing models echo cancellation around capture-side processing plus render/far-end audio provided to the processor.

These support the current direction: platform voice processing first, optional far-end reference processing second, and business-layer speaker/text gates last.

## Code Decisions

- Extract sustained VAD/event state from `ProcessedAzureAudioInputStream`.
- Extract rolling microphone evidence buffering from `ProcessedAzureAudioInputStream`.
- Keep Azure push-stream writing inside `ProcessedAzureAudioInputStream`, because it is the Azure adapter.
- Rename `SubtractiveAcousticEchoProcessor` to `DebugSubtractiveEchoProcessor`.
- Rename `AdaptiveSpeakerEvidenceProvider` to `HeuristicSpeakerEvidenceProvider`.
- Keep compatibility behavior unchanged in `SpeechServiceFactory`: Azure mode still uses permissive submission gating plus explicit speaker evidence for playback/barge-in decisions.

## Risks

- Renaming internal types requires regenerating the Xcode project.
- Simulator cannot prove acoustic cancellation, only policy and wiring.
- The heuristic speaker provider can still produce false positives/negatives in real acoustic environments; production speaker verification remains out of scope.
