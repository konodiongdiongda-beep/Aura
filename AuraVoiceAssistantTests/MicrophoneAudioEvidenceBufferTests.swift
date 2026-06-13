import XCTest
@testable import AuraVoiceAssistant

final class MicrophoneAudioEvidenceBufferTests: XCTestCase {
    func testEmptySnapshotReturnsNilInsteadOfCrashing() {
        let buffer = MicrophoneAudioEvidenceBuffer(sampleRate: 16_000, maxDuration: 5)

        let snapshot = buffer.snapshot(maxDuration: 2.5)

        XCTAssertNil(snapshot)
    }

    func testSnapshotReturnsMostRecentPCMWindow() {
        let buffer = MicrophoneAudioEvidenceBuffer(sampleRate: 2, maxDuration: 2)

        buffer.appendPCM16Mono(pcmData([1, 2, 3, 4, 5]))
        let snapshot = buffer.snapshot(maxDuration: 1)

        XCTAssertEqual(snapshot?.pcm16MonoData, pcmData([4, 5]))
        XCTAssertEqual(snapshot?.sampleRate, 2)
        XCTAssertEqual(snapshot?.duration, 1)
    }
}

private func pcmData(_ samples: [Int16]) -> Data {
    var samples = samples
    return Data(bytes: &samples, count: samples.count * MemoryLayout<Int16>.size)
}
