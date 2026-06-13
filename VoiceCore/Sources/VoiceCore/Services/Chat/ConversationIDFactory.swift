import CryptoKit
import Foundation

public protocol ConversationIDProviding {
    func makeConversationContext() -> ConversationContext
}

public final class ConversationIDFactory {
    private let userName: String
    private let userID: Int
    private let timeZone: TimeZone
    private let uuidProvider: () -> String
    private let dateProvider: () -> Date

    public init(
        userName: String = "test01",
        userID: Int = 35,
        timeZone: TimeZone = .current,
        uuidProvider: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.userName = userName
        self.userID = userID
        self.timeZone = timeZone
        self.uuidProvider = uuidProvider
        self.dateProvider = dateProvider
    }

    public func makeConversationContext() -> ConversationContext {
        makeConversationContext(cid: uuidProvider())
    }

    public func makeConversationContext(cid: String) -> ConversationContext {
        ConversationContext(
            cid: cid,
            cidMD5: Self.cidMD5(for: cid),
            userName: userName,
            userID: userID
        )
    }

    public func makeRequestContext(for conversation: ConversationContext) -> RequestContextMetadata {
        let secondTime = formattedSecondTime()
        return RequestContextMetadata(
            cidMD5: conversation.cidMD5,
            secondTime: secondTime,
            requestID: "\(conversation.userName)_\(conversation.cidMD5)_\(secondTime)"
        )
    }

    public func makeTurnContext(for conversation: ConversationContext) -> ChatTurnContext {
        let requestContext = makeRequestContext(for: conversation)
        return ChatTurnContext(
            cid: conversation.cid,
            cidMD5: conversation.cidMD5,
            userName: conversation.userName,
            userID: conversation.userID,
            userChatID: uuidProvider(),
            botChatID: uuidProvider(),
            secondTime: requestContext.secondTime,
            requestID: requestContext.requestID
        )
    }

    public static func cidMD5(for cid: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(cid.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().lowercased().prefix(16).description
    }

    private func formattedSecondTime() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: dateProvider())
    }
}

extension ConversationIDFactory: ConversationIDProviding {}
