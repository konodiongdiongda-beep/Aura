import Foundation
import XCTest
import VoiceCore
@testable import AuraVoiceAssistant

final class AcousticEchoCancellerTests: XCTestCase {
    func testControlledSynthesizerFeedsTTSAudioToReferenceBeforePlayback() async throws {
        let audioData = wavData(samples: [1_000, -1_000, 500, -500])
        let upstream = FakeSpeechSynthesizer(output: SpeechSynthesisOutput(audioData: audioData, text: "hello"))
        let speaker = RecordingAudioDataPlayer()
        let referenceCapture = RecordingReferenceCapture()
        let synthesizer = ControlledAudioSpeechSynthesizer(
            upstream: upstream,
            referenceCapture: referenceCapture,
            speaker: speaker
        )

        try await synthesizer.speak("hello")

        XCTAssertEqual(referenceCapture.audioData, [audioData])
        XCTAssertEqual(speaker.playedData, [audioData])
    }

    func testAudioReferenceDecoderDecodesWavToPCM16Mono() throws {
        let audioData = wavData(samples: [1_000, -1_000, 500, -500])

        let pcm = AudioReferencePCMDecoder.decodePCM16Mono(fromAudioData: audioData)

        XCTAssertEqual(pcm, pcmData([1_000, -1_000, 500, -500]))
    }

    func testReferenceCancellerProcessesMicrophonePCMWithReference() {
        let canceller = ReferenceAcousticEchoCanceller(
            processor: DebugSubtractiveEchoProcessor(attenuation: 1),
            referenceSampleRate: 16_000
        )
        canceller.appendFarEndPCM16(pcmData([100, 200, -100, -200]))
        let microphone = pcmData([150, 100, -50, -300])

        let processed = canceller.processMicrophonePCM16(microphone, sampleRate: 16_000)

        XCTAssertEqual(processed, pcmData([50, -100, 50, -100]))
    }

    func testReferenceCancellerPreservesMicrophonePCMWithoutReference() {
        let canceller = ReferenceAcousticEchoCanceller(
            processor: DebugSubtractiveEchoProcessor(attenuation: 1),
            referenceSampleRate: 16_000
        )
        let microphone = pcmData([150, 100, -50, -300])

        let processed = canceller.processMicrophonePCM16(microphone, sampleRate: 16_000)

        XCTAssertEqual(processed, microphone)
    }
}

private final class RecordingReferenceCapture: AssistantAudioReferenceCapturing, @unchecked Sendable {
    private(set) var audioData: [Data] = []

    func appendPlaybackAudioData(_ data: Data) {
        audioData.append(data)
    }

    func resetPlaybackReference() {
        audioData.removeAll()
    }
}

private actor FakeSpeechSynthesizer: SpeechSynthesizing {
    private let output: SpeechSynthesisOutput

    init(output: SpeechSynthesisOutput) {
        self.output = output
    }

    func speak(_ text: String) async throws {}

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        output
    }

    func cancel() async {}
}

private final class RecordingAudioDataPlayer: AudioDataPlaying, @unchecked Sendable {
    private(set) var playedData: [Data] = []

    func play(_ data: Data) async throws {
        playedData.append(data)
    }

    func cancel() {}
}

private func pcmData(_ samples: [Int16]) -> Data {
    var samples = samples
    return Data(bytes: &samples, count: samples.count * MemoryLayout<Int16>.size)
}

private func wavData(samples: [Int16], sampleRate: Int = 16_000) -> Data {
    let pcm = pcmData(samples)
    let byteRate = sampleRate * 2
    let blockAlign: UInt16 = 2
    let bitsPerSample: UInt16 = 16
    let chunkSize = UInt32(36 + pcm.count)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.append(littleEndian: chunkSize)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.append(littleEndian: UInt32(16))
    data.append(littleEndian: UInt16(1))
    data.append(littleEndian: UInt16(1))
    data.append(littleEndian: UInt32(sampleRate))
    data.append(littleEndian: UInt32(byteRate))
    data.append(littleEndian: blockAlign)
    data.append(littleEndian: bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.append(littleEndian: UInt32(pcm.count))
    data.append(pcm)
    return data
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
