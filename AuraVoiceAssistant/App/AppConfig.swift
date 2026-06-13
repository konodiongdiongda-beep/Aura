import Foundation

struct AppConfig: Equatable {
    var chatWebSocketURL: URL?
    var historyListURL: URL?
    var historyMessagesURL: URL?
    var azureSpeechKey: String
    var azureSpeechRegion: String
    var preferredVoiceName: String
    var azureSpeechMode: String
    var defaultUsername: String
    var defaultUserID: Int

    var isAzureSpeechReady: Bool {
        !azureSpeechKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !azureSpeechRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfig {
        AppConfig(
            chatWebSocketURL: urlValue("CHAT_WEBSOCKET_URL", bundle: bundle, environment: environment) ?? mock.chatWebSocketURL,
            historyListURL: urlValue("HISTORY_LIST_URL", bundle: bundle, environment: environment) ?? mock.historyListURL,
            historyMessagesURL: urlValue("HISTORY_MESSAGES_URL", bundle: bundle, environment: environment) ?? mock.historyMessagesURL,
            azureSpeechKey: stringValue("AZURE_SPEECH_KEY", bundle: bundle, environment: environment),
            azureSpeechRegion: stringValue("AZURE_SPEECH_REGION", bundle: bundle, environment: environment),
            preferredVoiceName: stringValue("AZURE_SPEECH_VOICE_NAME", bundle: bundle, environment: environment, defaultValue: mock.preferredVoiceName),
            azureSpeechMode: stringValue("AZURE_SPEECH_MODE", bundle: bundle, environment: environment, defaultValue: mock.azureSpeechMode),
            defaultUsername: stringValue("DEFAULT_USERNAME", bundle: bundle, environment: environment, defaultValue: mock.defaultUsername),
            defaultUserID: Int(stringValue("DEFAULT_USER_ID", bundle: bundle, environment: environment, defaultValue: "\(mock.defaultUserID)")) ?? mock.defaultUserID
        )
    }

    static let mock = AppConfig(
        chatWebSocketURL: URL(string: "ws://43.98.164.20:6007/ws/chat"),
        historyListURL: URL(string: "http://43.98.164.20:6007/history/user/page"),
        historyMessagesURL: URL(string: "http://43.98.164.20:6007/history-with-alerts/"),
        azureSpeechKey: "",
        azureSpeechRegion: "",
        preferredVoiceName: "zh-CN-XiaoxiaoNeural",
        azureSpeechMode: "auto",
        defaultUsername: "test01",
        defaultUserID: 35
    )

    private static func stringValue(
        _ key: String,
        bundle: Bundle,
        environment: [String: String],
        defaultValue: String = ""
    ) -> String {
        if let value = environment[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        if let value = bundle.object(forInfoDictionaryKey: key) as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !value.hasPrefix("$(") {
            return value
        }
        return defaultValue
    }

    private static func urlValue(
        _ key: String,
        bundle: Bundle,
        environment: [String: String]
    ) -> URL? {
        let value = stringValue(key, bundle: bundle, environment: environment)
        return value.isEmpty ? nil : URL(string: value)
    }
}
