import Foundation

public final class ChatStreamParser {
    public private(set) var accumulatedDisplayText: String = ""

    private let activeBotChatID: String?
    private let decoder: JSONDecoder

    public init(activeBotChatID: String? = nil, decoder: JSONDecoder = .voiceCore) {
        self.activeBotChatID = activeBotChatID
        self.decoder = decoder
    }

    public func parseLine(_ line: String) throws -> [ChatStreamUpdate] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let event = try decoder.decode(ChatStreamEventDTO.self, from: Data(trimmed.utf8))
        if let activeBotChatID, let eventBotChatID = event.botChatID, eventBotChatID != activeBotChatID {
            return []
        }

        if event.type == "message_ids" {
            guard let userMessageID = event.userMessageID, let botMessageID = event.botMessageID else {
                return []
            }
            return [.messageIDs(userMessageID: userMessageID, botMessageID: botMessageID)]
        }

        switch event.stepType {
        case "final_token":
            guard let token = event.stepOutput?.displayText, !token.isEmpty else {
                return []
            }
            accumulatedDisplayText += token
            return [.assistantToken(token)]
        case "finish":
            let final = parseFinalResult(event.stepOutput?.result)
            return [
                .final(
                    displayText: final.displayText,
                    voiceText: final.voiceText,
                    intent: final.intent
                ),
                .completed
            ]
        default:
            return []
        }
    }

    public func parseLines(_ text: String) throws -> [ChatStreamUpdate] {
        try text.split(whereSeparator: \.isNewline).flatMap { try parseLine(String($0)) }
    }

    private func parseFinalResult(_ result: String?) -> (displayText: String, voiceText: String?, intent: String?) {
        guard
            let result,
            let data = result.data(using: .utf8),
            let decoded = try? decoder.decode(ChatFinalResultDTO.self, from: data)
        else {
            return (accumulatedDisplayText, accumulatedDisplayText.isEmpty ? nil : accumulatedDisplayText, nil)
        }

        let displayText = decoded.displayText?.isEmpty == false ? decoded.displayText! : accumulatedDisplayText
        let voiceText = decoded.voiceText?.isEmpty == false ? decoded.voiceText : (displayText.isEmpty ? nil : displayText)
        return (displayText, voiceText, decoded.intent)
    }
}
