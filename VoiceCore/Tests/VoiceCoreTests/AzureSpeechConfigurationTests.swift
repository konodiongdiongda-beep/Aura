import XCTest
@testable import VoiceCore

final class AzureSpeechConfigurationTests: XCTestCase {
    func testValidatesMissingKeyOrRegionAsAppError() {
        XCTAssertThrowsError(try AzureSpeechConfiguration(
            subscriptionKey: " ",
            region: "southeastasia",
            preferredVoiceName: "zh-CN-XiaoxiaoNeural"
        ).validated()) { error in
            XCTAssertEqual(error as? AppError, .missingAzureSpeechConfig)
        }

        XCTAssertThrowsError(try AzureSpeechConfiguration(
            subscriptionKey: "abc",
            region: "",
            preferredVoiceName: "zh-CN-XiaoxiaoNeural"
        ).validated()) { error in
            XCTAssertEqual(error as? AppError, .missingAzureSpeechConfig)
        }
    }

    func testTrimsConfigAndDefaultsRecognitionLanguage() throws {
        let config = try AzureSpeechConfiguration(
            subscriptionKey: " key ",
            region: " southeastasia ",
            preferredVoiceName: " zh-CN-XiaoxiaoNeural "
        ).validated()

        XCTAssertEqual(config.subscriptionKey, "key")
        XCTAssertEqual(config.region, "southeastasia")
        XCTAssertEqual(config.recognitionLanguage, "zh-CN")
        XCTAssertEqual(config.preferredVoiceName, "zh-CN-XiaoxiaoNeural")
    }
}
