import Foundation
import VoiceCore

enum SpeechRuntimeEnvironment: Equatable {
    case simulator
    case device

    static var current: SpeechRuntimeEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        return .device
        #endif
    }

    var displayName: String {
        switch self {
        case .simulator:
            return "Simulator"
        case .device:
            return "Device"
        }
    }
}

enum SpeechServicePreference: String, Equatable {
    case auto
    case mock
    case azure

    init(rawConfigValue: String) {
        switch rawConfigValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "azure", "real":
            self = .azure
        case "mock", "simulator":
            self = .mock
        default:
            self = .auto
        }
    }
}

enum SpeechServiceMode: Equatable {
    case mock(reason: String)
    case azure

    var displayName: String {
        switch self {
        case .mock:
            return "Mock"
        case .azure:
            return "Azure"
        }
    }

    var statusText: String {
        switch self {
        case let .mock(reason):
            return reason
        case .azure:
            return "Azure Speech configured"
        }
    }
}

struct SpeechServiceBundle {
    let recognizer: any SpeechRecognizing
    let synthesizer: any SpeechSynthesizing
    let audioSession: any AudioSessionManaging
    let submissionGate: any UserTurnSubmissionGating
    let speakerEvidenceProvider: any UserTurnSpeakerEvidenceProviding
    let mode: SpeechServiceMode
    let environment: SpeechRuntimeEnvironment
}

enum SpeechServiceFactory {
    static func make(
        appConfig: AppConfig,
        preference: SpeechServicePreference? = nil,
        environment: SpeechRuntimeEnvironment = .current
    ) -> SpeechServiceBundle {
        let requestedPreference = preference ?? SpeechServicePreference(rawConfigValue: appConfig.azureSpeechMode)
        let speechConfig = appConfig.azureSpeechConfiguration

        do {
            _ = try speechConfig.validated()
        } catch {
            return makeMockBundle(
                environment: environment,
                reason: missingConfigurationReason(environment: environment)
            )
        }

        switch requestedPreference {
        case .mock:
            return makeMockBundle(
                environment: environment,
                reason: "Mock speech mode selected"
            )
        case .auto where environment == .simulator:
            return makeMockBundle(
                environment: environment,
                reason: "Simulator default, using mock speech"
            )
        case .auto, .azure:
            return makeAzureBundleOrFallback(
                configuration: speechConfig,
                environment: environment
            )
        }
    }

    private static func makeMockBundle(
        environment: SpeechRuntimeEnvironment,
        reason: String
    ) -> SpeechServiceBundle {
        SpeechServiceBundle(
            recognizer: MockSpeechRecognizer(),
            synthesizer: MockSpeechSynthesizer(),
            audioSession: MockAudioSessionManager(),
            submissionGate: SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false),
            speakerEvidenceProvider: NoopUserTurnSpeakerEvidenceProvider(),
            mode: .mock(reason: reason),
            environment: environment
        )
    }

    private static func missingConfigurationReason(environment: SpeechRuntimeEnvironment) -> String {
        switch environment {
        case .simulator:
            return "Azure Speech missing, using simulator mock"
        case .device:
            return "Azure Speech missing, using mock"
        }
    }

    private static func makeAzureBundleOrFallback(
        configuration: AzureSpeechConfiguration,
        environment: SpeechRuntimeEnvironment
    ) -> SpeechServiceBundle {
        #if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
        let azureSynthesizer = AzureSpeechSynthesizer(configuration: configuration)
        let speakerEvidenceProvider = makeSpeakerEvidenceProvider()
        let acousticEchoCanceller = ReferenceAcousticEchoCanceller()
        return SpeechServiceBundle(
            recognizer: AzureSpeechRecognizer(
                configuration: configuration,
                acousticEchoCanceller: acousticEchoCanceller
            ),
            synthesizer: ControlledAudioSpeechSynthesizer(
                upstream: azureSynthesizer,
                referenceCapture: acousticEchoCanceller
            ),
            audioSession: AudioSessionManager(),
            submissionGate: SpeakerProfileUserTurnSubmissionGate(requiresVerifiedSpeaker: false),
            speakerEvidenceProvider: speakerEvidenceProvider,
            mode: .azure,
            environment: environment
        )
        #else
        return makeMockBundle(
            environment: environment,
            reason: "Azure Speech SDK unavailable, using simulator mock"
        )
        #endif
    }

    /// Prefer the real CAM++ voiceprint (sherpa-onnx + bundled 192-dim model).
    /// Falls back to the heuristic provider only if the model/SDK can't load, so
    /// gating still functions (less accurately) rather than disappearing.
    private static func makeSpeakerEvidenceProvider() -> any UserTurnSpeakerEvidenceProviding {
        #if os(iOS)
        if let engine = SpeakerVerificationModelLoader.makeEngine() {
            return SpeakerVerificationEvidenceProvider(engine: engine)
        }
        print("[SpeechServiceFactory] CAM++ voiceprint unavailable, falling back to heuristic provider")
        #endif
        return HeuristicSpeakerEvidenceProvider()
    }
}
