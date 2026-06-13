import Foundation

public struct ConversationContext: Equatable {
    public let cid: String
    public let cidMD5: String
    public let userName: String
    public let userID: Int

    public init(cid: String, cidMD5: String, userName: String, userID: Int) {
        self.cid = cid
        self.cidMD5 = cidMD5
        self.userName = userName
        self.userID = userID
    }

    public init(cid: String, cidMD5: String, username: String, userID: Int) {
        self.init(cid: cid, cidMD5: cidMD5, userName: username, userID: userID)
    }

    public var username: String {
        userName
    }
}

public struct RequestContextMetadata: Equatable, Codable {
    public let cidMD5: String
    public let secondTime: String
    public let requestID: String

    public init(cidMD5: String, secondTime: String, requestID: String) {
        self.cidMD5 = cidMD5
        self.secondTime = secondTime
        self.requestID = requestID
    }

    enum CodingKeys: String, CodingKey {
        case cidMD5 = "cid_md5"
        case secondTime = "second_time"
        case requestID = "request_id"
    }
}

public struct ChatTurnContext: Equatable {
    public let cid: String
    public let cidMD5: String
    public let userName: String
    public let userID: Int
    public let userChatID: String
    public let botChatID: String
    public let secondTime: String
    public let requestID: String

    public init(
        cid: String,
        cidMD5: String,
        userName: String,
        userID: Int,
        userChatID: String,
        botChatID: String,
        secondTime: String,
        requestID: String
    ) {
        self.cid = cid
        self.cidMD5 = cidMD5
        self.userName = userName
        self.userID = userID
        self.userChatID = userChatID
        self.botChatID = botChatID
        self.secondTime = secondTime
        self.requestID = requestID
    }
}
