import XCTest
@testable import VoiceCore

final class SentenceSegmenterTests: XCTestCase {
    func testEmitsCompleteChinesePunctuationSegmentsAndKeepsRemainder() {
        var segmenter = SentenceSegmenter(maxSegmentLength: 20)

        let first = segmenter.append("你好，我是")
        let second = segmenter.append("语音助手。还没")

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, ["你好，我是语音助手。"])
        XCTAssertEqual(segmenter.flush(), "还没")
    }

    func testDoesNotSplitShortChunksOnCommasOrListPunctuation() {
        var segmenter = SentenceSegmenter(maxSegmentLength: 30)

        let first = segmenter.append("可以查行情、")
        let second = segmenter.append("跟进新闻，")
        let third = segmenter.append("也能聊天。")

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, [])
        XCTAssertEqual(third, ["可以查行情、跟进新闻，也能聊天。"])
    }

    func testEmitsShortFirstChunkBeforeSentencePunctuation() {
        var segmenter = SentenceSegmenter(maxSegmentLength: 30, firstSegmentMinLength: 5)

        let first = segmenter.append("您好，今天")
        let second = segmenter.append("想聊哪只标的？")

        XCTAssertEqual(first, ["您好，今天"])
        XCTAssertEqual(second, ["想聊哪只标的？"])
    }

    func testFlushReturnsNilForWhitespaceOnlyRemainder() {
        var segmenter = SentenceSegmenter(maxSegmentLength: 20)

        XCTAssertEqual(segmenter.append("   \n"), [])
        XCTAssertNil(segmenter.flush())
    }

    func testSplitsLongTextAtReasonableLengthWithoutWaitingForPunctuation() {
        var segmenter = SentenceSegmenter(maxSegmentLength: 6)

        let segments = segmenter.append("一二三四五六七八")

        XCTAssertEqual(segments, ["一二三四五六"])
        XCTAssertEqual(segmenter.flush(), "七八")
    }
}
