import VoiceCore

extension AppConfig {
    var azureSpeechConfiguration: AzureSpeechConfiguration {
        AzureSpeechConfiguration(
            subscriptionKey: azureSpeechKey,
            region: azureSpeechRegion,
            preferredVoiceName: preferredVoiceName
        )
    }

    var voiceCoreServiceConfiguration: VoiceCoreServiceConfiguration {
        VoiceCoreServiceConfiguration(
            chatWebSocketURL: chatWebSocketURL ?? VoiceCoreServiceConfiguration.defaultChatWebSocketURL,
            historyListURL: historyListURL ?? VoiceCoreServiceConfiguration.defaultHistoryListURL,
            historyMessagesURL: historyMessagesURL ?? VoiceCoreServiceConfiguration.defaultHistoryMessagesURL,
            userName: defaultUsername,
            userID: defaultUserID,
            useMocks: false
        )
    }

    func makeVoiceCoreServices(useMocks: Bool = false) -> VoiceCore.AppServices {
        var configuration = voiceCoreServiceConfiguration
        configuration.useMocks = useMocks
        return VoiceCore.AppServices.make(configuration: configuration)
    }
}
