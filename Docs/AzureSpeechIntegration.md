# Azure Speech Integration

## Dependency

The app uses XcodeGen plus CocoaPods:

- `project.yml` includes the local `VoiceCore` Swift package and includes `AuraVoiceAssistant/Services/Speech/**` in the app target.
- `Podfile` records the Azure Speech iOS SDK dependency:

```ruby
pod 'MicrosoftCognitiveServicesSpeech-iOS'
```

After changing `project.yml`, regenerate the project and reinstall pods:

```sh
xcodegen generate
pod install
```

Open and build with `AuraVoiceAssistant.xcworkspace`, not the `.xcodeproj`, so the pod target is available.

## Required Permissions

`AuraVoiceAssistant/App/Info.plist` already includes:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

## Local Configuration

Do not hard-code Azure secrets in Swift source. Copy:

```text
AuraVoiceAssistant/App/LocalConfig.sample.xcconfig
```

to:

```text
AuraVoiceAssistant/App/LocalConfig.xcconfig
```

Set local values there. The app target uses checked-in `Debug.xcconfig` and `Release.xcconfig` wrappers that include CocoaPods settings first, then optionally include `LocalConfig.xcconfig`. `AppConfig.load()` reads these Info.plist build setting values, and also supports environment variables with the same names:

- `AZURE_SPEECH_KEY`
- `AZURE_SPEECH_REGION`
- `AZURE_SPEECH_VOICE_NAME`
- `AZURE_SPEECH_MODE`
- `CHAT_WEBSOCKET_URL`
- `HISTORY_LIST_URL`
- `HISTORY_MESSAGES_URL`
- `DEFAULT_USERNAME`
- `DEFAULT_USER_ID`

Use `southeastasia` for the Azure region when testing with the provided local credentials. Keep the actual key out of committed files.

If `AZURE_SPEECH_KEY` or `AZURE_SPEECH_REGION` is missing or blank, `AzureSpeechConfiguration.validated()` throws `VoiceCore.AppError.missingAzureSpeechConfig`.

`AZURE_SPEECH_MODE` defaults to `auto`:

- `auto`: the simulator uses mock speech services by default; a device uses Azure when key and region are present.
- `mock`: force `MockSpeechRecognizer`, `MockSpeechSynthesizer`, and `MockAudioSessionManager`.
- `azure`: try the Azure SDK path when key and region are present. If the SDK is unavailable to that build, the factory falls back to mock and surfaces a status reason.

## Service Wiring

Shared contracts live in `VoiceCore`:

- `SpeechRecognizing`
- `SpeechSynthesizing`
- `AudioSessionManaging`
- `SpeechPlaybackControlling`
- `AzureSpeechConfiguration`
- `SentenceSegmenter`
- `TTSPlaybackQueue`
- mock speech/audio services

iOS-only implementations live under `AuraVoiceAssistant/Services/Speech`:

- `AudioSessionManager`
- `AzureSpeechRecognizer`
- `AzureSpeechSynthesizer`
- `SpeechServiceFactory`

The app constructs speech services through `SpeechServiceFactory`, which keeps simulator and missing-configuration paths non-crashing:

```swift
let appConfig = AppConfig.load()
let services = SpeechServiceFactory.make(appConfig: appConfig)

let recognizer = services.recognizer
let synthesizer = services.synthesizer
let audioSession = services.audioSession
let playbackQueue = TTSPlaybackQueue(synthesizer: synthesizer)
```

If key or region is missing, `AzureSpeechConfiguration.validated()` throws `VoiceCore.AppError.missingAzureSpeechConfig`.
In simulator mock mode, the UI does not call `validated()` directly, so the app remains runnable and Settings shows the mock fallback reason.

## Simulator Coverage

The iOS simulator can verify:

- The app target compiles with `MicrosoftCognitiveServicesSpeech-iOS`.
- `AzureSpeechRecognizer`, `AzureSpeechSynthesizer`, and `AudioSessionManager` are included in the app target.
- Missing key or region falls back to mock speech services instead of crashing.
- Settings shows key presence without revealing the key, region, voice name, current speech mode, and runtime environment.
- The Debug Input tab has a `模拟用户说话` button that emits `SpeechRecognitionEvent.final(...)` into `VoiceCallViewModel` and drives the mock conversation path for Phase 4 integration.
- Unit tests for `VoiceCore` speech protocols, `SentenceSegmenter`, `TTSPlaybackQueue`, config validation, and app integration pass.

The simulator can also run one real Azure-backed voice conversation when `AZURE_SPEECH_MODE = azure` and key/region are configured. That uses the Mac microphone and speaker through Simulator and is valid for integration smoke testing.

The simulator cannot fully validate:

- iPhone hardware microphone capture quality.
- Azure continuous recognition from device microphone.
- Speaker output routing, Bluetooth routing, or `.voiceChat` echo cancellation.
- Barge-in behavior under real acoustic feedback.

To test the simulator mock path:

1. Open `AuraVoiceAssistant.xcworkspace` and run an iPhone simulator.
2. Leave `AZURE_SPEECH_KEY` and/or `AZURE_SPEECH_REGION` blank, or use `AZURE_SPEECH_MODE = auto`.
3. Open Settings and confirm speech mode is `Mock`, environment is `Simulator`, and the status says `Azure Speech missing, using simulator mock` when key or region is blank.
4. Open Debug Input, enter text, and tap `模拟用户说话`. The view model records a final speech event and appends the mock user/assistant turn.

Real Azure initialization on simulator is opt-in with `AZURE_SPEECH_MODE = azure` plus key and region. Simulator microphone recognition is still not a substitute for true-device STT validation.

To test one real Simulator conversation:

1. Copy `AuraVoiceAssistant/App/LocalConfig.sample.xcconfig` to `AuraVoiceAssistant/App/LocalConfig.xcconfig`.
2. Fill `AZURE_SPEECH_KEY`, keep `AZURE_SPEECH_REGION = southeastasia` unless your Azure resource uses another region, and keep `AZURE_SPEECH_MODE = azure`.
3. Run `xcodegen generate && pod install`.
4. Open `AuraVoiceAssistant.xcworkspace`, select an iPhone simulator, and run the app.
5. Open Settings and confirm key is present, region is set, speech mode is `Azure`, and environment is `Simulator`.
6. Start a voice call, allow microphone access, and speak into the Mac microphone.

## True-Device Test Steps

1. Run `xcodegen generate` and `pod install`, then open `AuraVoiceAssistant.xcworkspace`.
2. Select a physical iPhone target. Simulator audio behavior is not sufficient for validation.
3. Configure `LocalConfig.xcconfig` with Azure key, `southeastasia`, and a Chinese neural voice such as `zh-CN-XiaoxiaoNeural`.
4. Start a call through the coordinator once Phase 4 wiring is available.
5. Confirm microphone permission prompt appears and is accepted.
6. Verify continuous recognition emits partial and final Chinese transcripts.
7. Send AI text fragments into `TTSPlaybackQueue` and confirm sentence-level playback.
8. Trigger user interruption and confirm `cancel()` stops current speech and clears queued segments.
9. End the call and verify the audio session deactivates.

## Verification Commands

```sh
swift test
xcodebuild test -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

## Current Verification Status

- `VoiceCore` unit tests pass on macOS.
- App tests pass on iPhone 17 simulator through `AuraVoiceAssistant.xcworkspace` after `xcodegen generate` and `pod install`.
- The workspace build links the Pods target and `MicrosoftCognitiveServicesSpeech-iOS`, and `AuraVoiceAssistant/Services/Speech/**` compiles into the app target.
- Physical-device runtime validation of microphone recognition, Azure TTS playback, Bluetooth routing, and acoustic barge-in is not yet verified in this workspace run. That still requires a connected iPhone, local Azure key/region config, signing, and microphone permission.
