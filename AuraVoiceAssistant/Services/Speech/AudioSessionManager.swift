#if os(iOS)
import AVFoundation
import Foundation
import VoiceCore

actor AudioSessionManager: AudioSessionManaging {
    private let session: AVAudioSession
    private(set) var isSpeakerEnabled: Bool
    private let allowsA2DP: Bool

    init(
        session: AVAudioSession = .sharedInstance(),
        speakerEnabled: Bool = true,
        allowsA2DP: Bool = true
    ) {
        self.session = session
        self.isSpeakerEnabled = speakerEnabled
        self.allowsA2DP = allowsA2DP
    }

    func startCall() async throws {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        if allowsA2DP {
            options.insert(.allowBluetoothA2DP)
        }

        let mode: AVAudioSession.Mode = .voiceChat

        try session.setCategory(.playAndRecord, mode: mode, options: options)
        if #available(iOS 18.2, *), session.isEchoCancelledInputAvailable {
            try? session.setPrefersEchoCancelledInput(true)
        }
        try session.setActive(true, options: [])
        try applySpeakerRoute()
    }

    func endCall() async {
        try? session.overrideOutputAudioPort(.none)
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func setSpeakerEnabled(_ enabled: Bool) async throws {
        isSpeakerEnabled = enabled
        try applySpeakerRoute()
    }

    private func applySpeakerRoute() throws {
        try session.overrideOutputAudioPort(isSpeakerEnabled ? .speaker : .none)
    }
}
#endif
