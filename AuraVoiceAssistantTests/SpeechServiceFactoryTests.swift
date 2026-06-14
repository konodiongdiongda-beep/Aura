import XCTest
import VoiceCore
@testable import AuraVoiceAssistant

final class SpeechServiceFactoryTests: XCTestCase {
    func testMissingAzureConfigUsesMockBundle() {
        let bundle = SpeechServiceFactory.make(
            appConfig: .mock,
            environment: .simulator
        )

        XCTAssertEqual(bundle.mode.displayName, "Mock")
        XCTAssertEqual(bundle.mode.statusText, "Azure Speech missing, using simulator mock")
        XCTAssertEqual(bundle.environment, .simulator)
        XCTAssertTrue(bundle.recognizer is MockSpeechRecognizer)
        XCTAssertTrue(bundle.synthesizer is MockSpeechSynthesizer)
        XCTAssertTrue(bundle.audioSession is MockAudioSessionManager)
        XCTAssertTrue(bundle.submissionGate is PlaybackAwareUserTurnSubmissionGate)
    }

    func testMockAppConfigUsesDebugPort6007() {
        XCTAssertEqual(AppConfig.mock.chatWebSocketURL?.port, 6007)
        XCTAssertEqual(AppConfig.mock.historyListURL?.port, 6007)
        XCTAssertEqual(AppConfig.mock.historyMessagesURL?.port, 6007)
    }

    func testSimulatorAutoModeUsesMockEvenWhenConfigured() {
        var config = AppConfig.mock
        config.azureSpeechKey = "test-key"
        config.azureSpeechRegion = "southeastasia"

        let bundle = SpeechServiceFactory.make(
            appConfig: config,
            preference: .auto,
            environment: .simulator
        )

        XCTAssertEqual(bundle.mode.displayName, "Mock")
        XCTAssertEqual(bundle.mode.statusText, "Simulator default, using mock speech")
        XCTAssertTrue(bundle.recognizer is MockSpeechRecognizer)
        XCTAssertTrue(bundle.submissionGate is PlaybackAwareUserTurnSubmissionGate)
    }

    func testSimulatorAzureModeUsesConfiguredAzureTTS() {
        var config = AppConfig.mock
        config.azureSpeechKey = "test-key"
        config.azureSpeechRegion = "southeastasia"

        let bundle = SpeechServiceFactory.make(
            appConfig: config,
            preference: .azure,
            environment: .simulator
        )

        XCTAssertEqual(bundle.mode.displayName, "Azure")
        XCTAssertTrue(bundle.submissionGate is PlaybackAwareUserTurnSubmissionGate)
        #if canImport(MicrosoftCognitiveServicesSpeech)
        XCTAssertTrue(bundle.synthesizer is ControlledAudioSpeechSynthesizer)
        #endif
    }
}
