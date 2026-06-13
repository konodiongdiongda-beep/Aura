import Foundation

public struct SentenceSegmenter: Sendable {
    private var buffer = ""
    private var hasEmittedFirstSegment = false
    private let maxSegmentLength: Int
    private let firstSegmentMinLength: Int
    private let sentenceDelimiters: Set<Character> = ["。", "！", "？", "；", "\n"]
    private let softTrailingDelimiters: Set<Character> = ["，", "、", ",", " "]

    public init(maxSegmentLength: Int = 80, firstSegmentMinLength: Int = 0) {
        self.maxSegmentLength = max(1, maxSegmentLength)
        self.firstSegmentMinLength = max(0, firstSegmentMinLength)
    }

    public mutating func append(_ text: String) -> [String] {
        buffer.append(text)
        return drainCompletedSegments()
    }

    public mutating func flush() -> String? {
        let remainder = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeAll()
        hasEmittedFirstSegment = false
        return remainder.isEmpty ? nil : remainder
    }

    private mutating func drainCompletedSegments() -> [String] {
        var segments: [String] = []

        while let range = nextSegmentRange() {
            let segment = String(buffer[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(range)
            if !segment.isEmpty {
                segments.append(segment)
                hasEmittedFirstSegment = true
            }
        }

        return segments
    }

    private func nextSegmentRange() -> Range<String.Index>? {
        if let delimiterIndex = buffer.firstIndex(where: { sentenceDelimiters.contains($0) }) {
            return buffer.startIndex..<buffer.index(after: delimiterIndex)
        }

        if !hasEmittedFirstSegment,
           firstSegmentMinLength > 0,
           buffer.count >= firstSegmentMinLength,
           !endsWithSoftTrailingDelimiter(buffer) {
            let end = buffer.index(buffer.startIndex, offsetBy: firstSegmentMinLength)
            return buffer.startIndex..<end
        }

        guard buffer.count >= maxSegmentLength else {
            return nil
        }

        let end = buffer.index(buffer.startIndex, offsetBy: maxSegmentLength)
        return buffer.startIndex..<end
    }

    private func endsWithSoftTrailingDelimiter(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return true
        }
        return softTrailingDelimiters.contains(last)
    }
}
