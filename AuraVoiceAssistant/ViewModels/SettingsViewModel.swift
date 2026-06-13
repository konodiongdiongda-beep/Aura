import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var config: AppConfig
    @Published private(set) var language: AppLanguage
    @Published private(set) var microphoneStatusText: String
    @Published private(set) var speakerEnrollmentStatusText: String
    @Published private(set) var speechServiceModeText: String
    @Published private(set) var speechRuntimeEnvironmentText: String
    @Published private(set) var speechStatusText: String

    init(
        config: AppConfig = .mock,
        language: AppLanguage = .english,
        microphoneStatusText: String = "Requested during calls",
        speakerEnrollmentStatusText: String = "Placeholder",
        speechServices: SpeechServiceBundle? = nil
    ) {
        self.config = config
        self.language = language
        self.microphoneStatusText = microphoneStatusText
        self.speakerEnrollmentStatusText = speakerEnrollmentStatusText
        let services = speechServices ?? SpeechServiceFactory.make(appConfig: config)
        self.speechServiceModeText = services.mode.displayName
        self.speechRuntimeEnvironmentText = services.environment.displayName
        self.speechStatusText = services.mode.statusText
    }

    var text: AppText {
        AppText.localized(language)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    var azureStatusText: String {
        config.isAzureSpeechReady ? text.azureConfigured : text.azureMissing
    }

    var userDisplayText: String {
        "\(config.defaultUsername) · user_id \(config.defaultUserID)"
    }

    var azureKeyPresenceText: String {
        config.azureSpeechKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text.missing : text.present
    }

    var azureRegionText: String {
        config.azureSpeechRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text.notSet : config.azureSpeechRegion
    }

    var preferredVoiceText: String {
        config.preferredVoiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text.notSet : config.preferredVoiceName
    }
}
