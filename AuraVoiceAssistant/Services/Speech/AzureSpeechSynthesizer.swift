#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

actor AzureSpeechSynthesizer: SpeechSynthesizing {
    private let configuration: AzureSpeechConfiguration
    private var dataSynthesizer: SPXSpeechSynthesizer?

    init(configuration: AzureSpeechConfiguration) {
        self.configuration = configuration
    }

    /// Not used: playback goes through the shared engine's player node, not
    /// Azure's native `defaultSpeakerOutput`. The wrapping
    /// `ControlledAudioSpeechSynthesizer` always calls `synthesize()` instead.
    func speak(_ text: String) async throws {
        throw VoiceCore.AppError.speechSynthesisFailed("AzureSpeechSynthesizer.speak is unsupported; use synthesize().")
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
        _ = try? dataSynthesizer?.stopSpeaking()
        dataSynthesizer = nil
    }

    private func cachedDataSynthesizer() throws -> SPXSpeechSynthesizer {
        if let dataSynthesizer {
            return dataSynthesizer
        }
        let synthesizer = try makeSynthesizer()
        dataSynthesizer = synthesizer
        return synthesizer
    }

    private func makeSynthesizer() throws -> SPXSpeechSynthesizer {
        let config = try configuration.validated()
        let speechConfig = try SPXSpeechConfiguration(subscription: config.subscriptionKey, region: config.region)
        speechConfig.speechSynthesisVoiceName = config.preferredVoiceName
        // No audio configuration → Azure renders to a data buffer instead of its
        // own speaker output, so we can play it through the shared engine.
        return try SPXSpeechSynthesizer(speechConfiguration: speechConfig, audioConfiguration: nil)
    }
}
#endif

