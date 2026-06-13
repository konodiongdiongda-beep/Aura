#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

actor AzureSpeechSynthesizer: SpeechSynthesizing {
    private let configuration: AzureSpeechConfiguration
    private var speakerSynthesizer: SPXSpeechSynthesizer?
    private var dataSynthesizer: SPXSpeechSynthesizer?

    init(configuration: AzureSpeechConfiguration) {
        self.configuration = configuration
    }

    func speak(_ text: String) async throws {
        let synthesizer = try cachedSpeakerSynthesizer()

        let result = try await Task.detached(priority: .userInitiated) {
            try synthesizer.speakText(text)
        }.value
        guard result.reason == SPXResultReason.synthesizingAudioCompleted else {
            throw VoiceCore.AppError.speechSynthesisFailed("Azure Speech synthesis did not complete.")
        }
    }

    func synthesize(_ text: String) async throws -> SpeechSynthesisOutput {
        let synthesizer = try cachedDataSynthesizer()

        let result = try await Task.detached(priority: .userInitiated) {
            try synthesizer.speakText(text)
        }.value
        guard result.reason == SPXResultReason.synthesizingAudioCompleted else {
            throw VoiceCore.AppError.speechSynthesisFailed("Azure Speech synthesis did not complete.")
        }

        return SpeechSynthesisOutput(audioData: result.audioData ?? Data(), text: text)
    }

    func cancel() async {
        _ = try? speakerSynthesizer?.stopSpeaking()
        _ = try? dataSynthesizer?.stopSpeaking()
        speakerSynthesizer = nil
        dataSynthesizer = nil
    }

    private func cachedSpeakerSynthesizer() throws -> SPXSpeechSynthesizer {
        if let speakerSynthesizer {
            return speakerSynthesizer
        }
        let synthesizer = try makeSynthesizer(playToDefaultSpeaker: true)
        speakerSynthesizer = synthesizer
        return synthesizer
    }

    private func cachedDataSynthesizer() throws -> SPXSpeechSynthesizer {
        if let dataSynthesizer {
            return dataSynthesizer
        }
        let synthesizer = try makeSynthesizer(playToDefaultSpeaker: false)
        dataSynthesizer = synthesizer
        return synthesizer
    }

    private func makeSynthesizer(playToDefaultSpeaker: Bool) throws -> SPXSpeechSynthesizer {
        let config = try configuration.validated()
        let speechConfig = try SPXSpeechConfiguration(subscription: config.subscriptionKey, region: config.region)
        speechConfig.speechSynthesisVoiceName = config.preferredVoiceName

        let audioConfig = playToDefaultSpeaker ? try SPXAudioConfiguration(defaultSpeakerOutput: ()) : nil
        return try SPXSpeechSynthesizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
    }
}
#endif
