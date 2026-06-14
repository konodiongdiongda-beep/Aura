import XCTest
@testable import VoiceCore

final class TTSPlaybackQueueTests: XCTestCase {
    func testEmitsPlaybackEventsWhenSpeechStartsFinishesAndDrains() async throws {
        let synthesizer = RecordingSpeechSynthesizer()
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 0
        )
        let events = await queue.playbackEvents()

        await queue.enqueue("第一句。", isFinal: true)
        try await synthesizer.waitForSpokenCount(1)

        let observed = try await collectEvents(
            events,
            count: 3,
            timeout: 2
        )
        XCTAssertEqual(observed, [
            .started("第一句"),
            .finished("第一句"),
            .drained
        ])
    }

    func testCancelEmitsCancelledEvent() async throws {
        let synthesizer = RecordingSpeechSynthesizer(suspendUntilCancelled: true)
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 0
        )
        let events = await queue.playbackEvents()

        await queue.enqueue("第一句。第二句。", isFinal: false)
        try await synthesizer.waitForSpokenCount(1)
        await queue.cancel()

        let observed = try await collectEvents(
            events,
            count: 2,
            timeout: 2
        )
        XCTAssertEqual(observed, [
            .started("第一句"),
            .cancelled
        ])
    }

    func testSpeaksCompletedSegmentsInOrderAndFlushesFinalRemainder() async throws {
        let synthesizer = RecordingSpeechSynthesizer()
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 0
        )

        await queue.enqueue("第一句。第二", isFinal: false)
        await queue.enqueue("句", isFinal: true)
        try await synthesizer.waitForSpokenCount(2)

        let spokenTexts = await synthesizer.spokenTextsSnapshot()
        XCTAssertEqual(spokenTexts, ["第一句", "第二句"])
    }

    func testSpeaksShortFirstChunkBeforeSentencePunctuation() async throws {
        let synthesizer = RecordingSpeechSynthesizer()
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 5
        )

        await queue.enqueue("您好，今天", isFinal: false)
        try await synthesizer.waitForSpokenCount(1)

        let spokenTexts = await synthesizer.spokenTextsSnapshot()
        XCTAssertEqual(spokenTexts, ["您好 今天"])
    }

    func testDefaultQueueSpeaksVeryShortFirstChunkForLowerLatency() async throws {
        let synthesizer = RecordingSpeechSynthesizer()
        let queue = TTSPlaybackQueue(synthesizer: synthesizer)

        await queue.enqueue("好的我", isFinal: false)
        try await synthesizer.waitForSpokenCount(1)

        let spokenTexts = await synthesizer.spokenTextsSnapshot()
        XCTAssertEqual(spokenTexts, ["好的我"])
    }

    func testCancelStopsCurrentSpeechAndClearsQueuedSegments() async throws {
        let synthesizer = RecordingSpeechSynthesizer(suspendUntilCancelled: true)
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 0
        )

        await queue.enqueue("第一句。第二句。", isFinal: false)
        try await synthesizer.waitForSpokenCount(1)

        await queue.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)

        let spokenTexts = await synthesizer.spokenTextsSnapshot()
        let cancelCallCount = await synthesizer.cancelCallCountSnapshot()
        XCTAssertEqual(spokenTexts, ["第一句"])
        XCTAssertEqual(cancelCallCount, 1)
    }

    func testSanitizesPunctuationBeforeSpeaking() async throws {
        let synthesizer = RecordingSpeechSynthesizer()
        let queue = TTSPlaybackQueue(
            synthesizer: synthesizer,
            maxSegmentLength: 30,
            firstSegmentMinLength: 0
        )

        await queue.enqueue("好的，我来回答：AI 会继续。", isFinal: true)
        try await synthesizer.waitForSpokenCount(1)

        let spokenTexts = await synthesizer.spokenTextsSnapshot()
        XCTAssertEqual(spokenTexts, ["好的 我来回答 AI 会继续"])
    }
}

private func collectEvents(
    _ stream: AsyncStream<SpeechPlaybackEvent>,
    count: Int,
    timeout: TimeInterval
) async throws -> [SpeechPlaybackEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [SpeechPlaybackEvent] = []
    let deadline = Date().addingTimeInterval(timeout)
    while events.count < count {
        if Date() > deadline {
            XCTFail("Timed out waiting for \(count) playback events; got \(events)")
            return events
        }
        if let event = await iterator.next() {
            events.append(event)
        } else {
            break
        }
    }
    return events
}

private actor RecordingSpeechSynthesizer: SpeechSynthesizing {
    private(set) var spokenTexts: [String] = []
    private(set) var cancelCallCount = 0
    private let suspendUntilCancelled: Bool

    init(suspendUntilCancelled: Bool = false) {
        self.suspendUntilCancelled = suspendUntilCancelled
    }

    func speak(_ text: String) async throws {
        try await play(SpeechSynthesisOutput(audioData: Data(text.utf8), text: text))
    }

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        SpeechSynthesisOutput(audioData: Data(text.utf8), text: text)
    }

    func play(_ output: SpeechSynthesisOutput) async throws {
        spokenTexts.append(output.text)
        if suspendUntilCancelled {
            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
    }

    func cancel() async {
        cancelCallCount += 1
    }

    func spokenTextsSnapshot() -> [String] {
        spokenTexts
    }

    func cancelCallCountSnapshot() -> Int {
        cancelCallCount
    }

    func waitForSpokenCount(_ count: Int) async throws {
        let deadline = Date().addingTimeInterval(2)
        while spokenTexts.count < count {
            if Date() > deadline {
                XCTFail("Timed out waiting for \(count) spoken texts; got \(spokenTexts)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
