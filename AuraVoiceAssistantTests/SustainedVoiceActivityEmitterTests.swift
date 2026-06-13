import XCTest
@testable import AuraVoiceAssistant

final class SustainedVoiceActivityEmitterTests: XCTestCase {
    func testRequiresSustainedVoiceBeforeEmitting() {
        let emitter = SustainedVoiceActivityEmitter(
            configuration: SustainedVoiceActivityEmitterConfiguration(
                minimumLevel: 0.10,
                minimumDuration: 0.20,
                emitInterval: 0.12
            ),
            isPlaybackActive: { true }
        )

        let first = emitter.eventIfNeeded(
            inputLevel: 0.20,
            bufferDuration: 0.04,
            audioEvidence: nil,
            now: 10.00
        )
        let second = emitter.eventIfNeeded(
            inputLevel: 0.20,
            bufferDuration: 0.04,
            audioEvidence: nil,
            now: 10.21
        )

        XCTAssertNil(first)
        XCTAssertEqual(second?.isAIPlaybackActive, true)
        XCTAssertNotNil(second)
        XCTAssertEqual(second?.duration ?? 0, 0.25, accuracy: 0.0001)
    }

    func testLowLevelResetsSustainedVoiceWindow() {
        let emitter = SustainedVoiceActivityEmitter(
            configuration: SustainedVoiceActivityEmitterConfiguration(
                minimumLevel: 0.10,
                minimumDuration: 0.20,
                emitInterval: 0.12
            )
        )

        _ = emitter.eventIfNeeded(
            inputLevel: 0.20,
            bufferDuration: 0.04,
            audioEvidence: nil,
            now: 20.00
        )
        _ = emitter.eventIfNeeded(
            inputLevel: 0.01,
            bufferDuration: 0.04,
            audioEvidence: nil,
            now: 20.10
        )
        let afterReset = emitter.eventIfNeeded(
            inputLevel: 0.20,
            bufferDuration: 0.04,
            audioEvidence: nil,
            now: 20.21
        )

        XCTAssertNil(afterReset)
    }
}
