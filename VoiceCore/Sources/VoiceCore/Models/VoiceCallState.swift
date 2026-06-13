import Foundation

public struct VoiceCallStateSnapshot: Equatable {
    public let stateName: String
    public let elapsedSeconds: Int

    public init(stateName: String, elapsedSeconds: Int = 0) {
        self.stateName = stateName
        self.elapsedSeconds = elapsedSeconds
    }

    public init(stateLabel: String, elapsedSeconds: Int = 0) {
        self.init(stateName: stateLabel, elapsedSeconds: elapsedSeconds)
    }

    public var stateLabel: String {
        stateName
    }
}

public enum VoiceCallState: Equatable {
    case idle
    case requestingPermission
    case listening
    case recognizing(partialText: String)
    case thinking
    case speaking
    case interrupted
    case muted(previous: VoiceCallStateSnapshot)
    case ended
    case error(AppError)

    public var isActiveCall: Bool {
        switch self {
        case .idle, .ended, .error:
            return false
        case .requestingPermission, .listening, .recognizing, .thinking, .speaking, .interrupted, .muted:
            return true
        }
    }
}
