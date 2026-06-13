import Foundation

public enum SpeechTextSanitizer {
    public static func sanitizedForSpeech(_ text: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(CharacterSet(charactersIn: "，。！？；：、“”‘’（）【】《》…—～·"))

        let scalars = text.unicodeScalars.map { scalar -> String in
            punctuation.contains(scalar) ? " " : String(scalar)
        }

        return scalars
            .joined()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }
}
