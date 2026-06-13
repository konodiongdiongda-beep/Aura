import Foundation

public struct ChatRequestPayload: Encodable, Equatable {
    public let collectStepResults: Bool
    public let userName: String
    public let context: ChatRequestContext
    public let userID: Int
    public let cid: String
    public let content: String

    public init(content: String, turn: ChatTurnContext) {
        self.collectStepResults = false
        self.userName = turn.userName
        self.context = ChatRequestContext(turn: turn)
        self.userID = turn.userID
        self.cid = turn.cid
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case collectStepResults = "collect_step_results"
        case userName = "user_name"
        case context
        case userID = "user_id"
        case cid
        case content
    }
}

public struct ChatRequestContext: Encodable, Equatable {
    public let stream: Bool
    public let additionalProp1: [String: String]
    public let modelName: String
    public let userChatID: String
    public let botChatID: String
    public let files: [String]
    public let imageURLs: [String]
    public let voiceMode: Bool
    public let cidMD5: String
    public let secondTime: String
    public let requestID: String

    public init(turn: ChatTurnContext) {
        self.stream = true
        self.additionalProp1 = [:]
        self.modelName = "azure-gpt-4.1"
        self.userChatID = turn.userChatID
        self.botChatID = turn.botChatID
        self.files = []
        self.imageURLs = []
        self.voiceMode = true
        self.cidMD5 = turn.cidMD5
        self.secondTime = turn.secondTime
        self.requestID = turn.requestID
    }

    enum CodingKeys: String, CodingKey {
        case stream
        case additionalProp1
        case modelName = "model_name"
        case userChatID = "user_chat_id"
        case botChatID = "bot_chat_id"
        case files
        case imageURLs = "image_urls"
        case voiceMode = "voice_mode"
        case cidMD5 = "cid_md5"
        case secondTime = "second_time"
        case requestID = "request_id"
    }
}

struct ChatStreamEventDTO: Decodable {
    let type: String?
    let stepType: String?
    let stepOutput: StepOutput?
    let userChatID: String?
    let botChatID: String?
    let userMessageID: Int?
    let botMessageID: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case stepType = "step_type"
        case stepOutput = "step_output"
        case userChatID = "user_chat_id"
        case botChatID = "bot_chat_id"
        case userMessageID = "user_message_id"
        case botMessageID = "bot_message_id"
    }

    struct StepOutput: Decodable {
        let displayText: String?
        let text: String?
        let result: String?

        enum CodingKeys: String, CodingKey {
            case displayText = "display_text"
            case text
            case result
        }
    }
}

struct ChatFinalResultDTO: Decodable {
    let voiceText: String?
    let displayText: String?
    let intent: String?

    enum CodingKeys: String, CodingKey {
        case voiceText = "voice_text"
        case displayText = "display_text"
        case intent
    }
}
