import Foundation

public enum AppError: LocalizedError, Equatable {
    case missingAzureSpeechConfig
    case microphonePermissionDenied
    case networkUnavailable
    case speechRecognitionCanceled(String)
    case speechRecognitionFailed(String)
    case speechSynthesisFailed(String)
    case websocketDisconnected
    case chatResponseTimedOut
    case responseParsingFailed
    case backendRejected(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .missingAzureSpeechConfig:
            return "Azure Speech configuration is missing."
        case .microphonePermissionDenied:
            return "Microphone permission was denied."
        case .networkUnavailable:
            return "The network is unavailable."
        case let .speechRecognitionCanceled(message):
            return "Speech recognition was canceled: \(message)"
        case let .speechRecognitionFailed(message):
            return "Speech recognition failed: \(message)"
        case let .speechSynthesisFailed(message):
            return "Speech synthesis failed: \(message)"
        case .websocketDisconnected:
            return "The chat WebSocket disconnected."
        case .chatResponseTimedOut:
            return "The chat backend response timed out."
        case .responseParsingFailed:
            return "The response could not be parsed."
        case let .backendRejected(message):
            return message
        case let .unknown(message):
            return message
        }
    }
}
