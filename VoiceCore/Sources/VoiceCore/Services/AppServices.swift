import Foundation

public struct VoiceCoreServiceConfiguration: Equatable {
    public static let defaultChatWebSocketURL = URL(string: "ws://43.98.164.20:6007/ws/chat")!
    public static let defaultHistoryListURL = URL(string: "http://43.98.164.20:6007/history/user/page")!
    public static let defaultHistoryMessagesURL = URL(string: "http://43.98.164.20:6007/history-with-alerts/")!

    public var chatWebSocketURL: URL
    public var historyListURL: URL
    public var historyMessagesURL: URL
    public var userName: String
    public var userID: Int
    public var useMocks: Bool

    public init(
        chatWebSocketURL: URL = Self.defaultChatWebSocketURL,
        historyListURL: URL = Self.defaultHistoryListURL,
        historyMessagesURL: URL = Self.defaultHistoryMessagesURL,
        userName: String = "test01",
        userID: Int = 35,
        useMocks: Bool = false
    ) {
        self.chatWebSocketURL = chatWebSocketURL
        self.historyListURL = historyListURL
        self.historyMessagesURL = historyMessagesURL
        self.userName = userName
        self.userID = userID
        self.useMocks = useMocks
    }
}

public struct AppServices {
    public let chatClient: any ChatClient
    public let historyClient: any HistoryClient
    public let idFactory: ConversationIDFactory

    public init(
        chatClient: any ChatClient,
        historyClient: any HistoryClient,
        idFactory: ConversationIDFactory
    ) {
        self.chatClient = chatClient
        self.historyClient = historyClient
        self.idFactory = idFactory
    }

    public static func make(configuration: VoiceCoreServiceConfiguration = VoiceCoreServiceConfiguration()) -> AppServices {
        let idFactory = ConversationIDFactory(
            userName: configuration.userName,
            userID: configuration.userID
        )

        if configuration.useMocks {
            return AppServices(
                chatClient: MockChatClient(),
                historyClient: MockHistoryClient(),
                idFactory: idFactory
            )
        }

        return AppServices(
            chatClient: ChatWebSocketClient(
                endpoint: configuration.chatWebSocketURL,
                idFactory: idFactory
            ),
            historyClient: HistoryService(
                conversationsEndpoint: configuration.historyListURL,
                messagesEndpoint: configuration.historyMessagesURL,
                idFactory: idFactory
            ),
            idFactory: idFactory
        )
    }

    public static func live(
        chatWebSocketURL: URL = VoiceCoreServiceConfiguration.defaultChatWebSocketURL,
        historyListURL: URL = VoiceCoreServiceConfiguration.defaultHistoryListURL,
        historyMessagesURL: URL = VoiceCoreServiceConfiguration.defaultHistoryMessagesURL,
        userName: String = "test01",
        userID: Int = 35
    ) -> AppServices {
        make(configuration: VoiceCoreServiceConfiguration(
            chatWebSocketURL: chatWebSocketURL,
            historyListURL: historyListURL,
            historyMessagesURL: historyMessagesURL,
            userName: userName,
            userID: userID,
            useMocks: false
        ))
    }

    public static func mock(userName: String = "test01", userID: Int = 35) -> AppServices {
        make(configuration: VoiceCoreServiceConfiguration(
            userName: userName,
            userID: userID,
            useMocks: true
        ))
    }
}
