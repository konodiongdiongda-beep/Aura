import Foundation

public struct SpeechEchoDetector: Sendable {
    public var similarityThreshold: Double
    public var minimumEchoCharacterCount: Int

    public init(similarityThreshold: Double = 0.65, minimumEchoCharacterCount: Int = 6) {
        self.similarityThreshold = similarityThreshold
        self.minimumEchoCharacterCount = minimumEchoCharacterCount
    }

    public func isLikelyEcho(recognizedText: String, assistantText: String) -> Bool {
        let recognized = normalized(recognizedText)
        let assistant = normalized(assistantText)
        guard recognized.count >= minimumEchoCharacterCount, assistant.count >= minimumEchoCharacterCount else { return false }

        if assistant.contains(recognized) || recognized.contains(assistant) {
            return true
        }

        let recognizedTokens = Set(tokenize(recognizedText))
        let assistantTokens = Set(tokenize(assistantText))
        guard !recognizedTokens.isEmpty, !assistantTokens.isEmpty else { return false }

        let overlap = recognizedTokens.intersection(assistantTokens).count
        let denominator = min(recognizedTokens.count, assistantTokens.count)
        return Double(overlap) / Double(denominator) >= similarityThreshold
    }

    public func removingEcho(
        from recognizedText: String,
        assistantText: String
    ) -> (text: String?, didRemoveEcho: Bool) {
        let sanitizedRecognized = sanitized(recognizedText)
        guard !containsASCIIWord(sanitizedRecognized) else {
            return (sanitizedRecognized, false)
        }
        let recognized = normalized(sanitizedRecognized)
        let assistant = normalized(assistantText)
        guard recognized.count >= minimumEchoCharacterCount, assistant.count >= minimumEchoCharacterCount else {
            return (sanitizedRecognized, false)
        }

        let match = longestCommonSubstring(in: recognized, and: assistant)
        let matchLength = recognized.distance(from: match.recognizedRange.lowerBound, to: match.recognizedRange.upperBound)
        guard matchLength >= minimumEchoCharacterCount else {
            return (sanitizedRecognized, false)
        }

        let recognizedCoverage = Double(matchLength) / Double(max(recognized.count, 1))
        let assistantCoverage = Double(matchLength) / Double(max(assistant.count, 1))
        guard recognizedCoverage >= similarityThreshold || assistantCoverage >= 0.45 else {
            return (sanitizedRecognized, false)
        }

        let matchStartOffset = recognized.distance(from: recognized.startIndex, to: match.recognizedRange.lowerBound)
        guard matchStartOffset > 0 else {
            return (nil, true)
        }

        let safeOffset = min(matchStartOffset, sanitizedRecognized.count)
        let prefixEnd = sanitizedRecognized.index(sanitizedRecognized.startIndex, offsetBy: safeOffset)
        let prefix = String(sanitizedRecognized[..<prefixEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (prefix.isEmpty ? nil : prefix, true)
    }

    private func normalized(_ text: String) -> String {
        sanitized(text)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "你", with: "您")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitized(_ text: String) -> String {
        SpeechTextSanitizer.sanitizedForSpeech(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ text: String) -> [String] {
        let cleaned = sanitized(text).lowercased()
        let words = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        let hasAlphabeticWord = words.contains { word in
            word.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.isASCII }
        }
        if hasAlphabeticWord {
            return words.filter { $0.count >= 3 }
        }
        return normalized(cleaned).map { String($0) }
    }

    private func containsASCIIWord(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.isASCII }
    }

    private func longestCommonSubstring(
        in recognized: String,
        and assistant: String
    ) -> (recognizedRange: Range<String.Index>, assistantRange: Range<String.Index>) {
        let recognizedCharacters = Array(recognized)
        let assistantCharacters = Array(assistant)
        guard !recognizedCharacters.isEmpty, !assistantCharacters.isEmpty else {
            return (recognized.startIndex..<recognized.startIndex, assistant.startIndex..<assistant.startIndex)
        }

        var lengths = Array(repeating: Array(repeating: 0, count: assistantCharacters.count + 1), count: recognizedCharacters.count + 1)
        var bestLength = 0
        var bestRecognizedEnd = 0
        var bestAssistantEnd = 0

        for recognizedIndex in 1...recognizedCharacters.count {
            for assistantIndex in 1...assistantCharacters.count {
                if recognizedCharacters[recognizedIndex - 1] == assistantCharacters[assistantIndex - 1] {
                    lengths[recognizedIndex][assistantIndex] = lengths[recognizedIndex - 1][assistantIndex - 1] + 1
                    if lengths[recognizedIndex][assistantIndex] > bestLength {
                        bestLength = lengths[recognizedIndex][assistantIndex]
                        bestRecognizedEnd = recognizedIndex
                        bestAssistantEnd = assistantIndex
                    }
                }
            }
        }

        let recognizedStartOffset = max(0, bestRecognizedEnd - bestLength)
        let assistantStartOffset = max(0, bestAssistantEnd - bestLength)
        let recognizedStart = recognized.index(recognized.startIndex, offsetBy: recognizedStartOffset)
        let recognizedEnd = recognized.index(recognized.startIndex, offsetBy: bestRecognizedEnd)
        let assistantStart = assistant.index(assistant.startIndex, offsetBy: assistantStartOffset)
        let assistantEnd = assistant.index(assistant.startIndex, offsetBy: bestAssistantEnd)
        return (recognizedStart..<recognizedEnd, assistantStart..<assistantEnd)
    }
}
