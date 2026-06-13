#if os(iOS)
import Foundation
import VoiceCore

struct SustainedVoiceActivityEmitterConfiguration: Sendable {
    var minimumLevel: Double
    var minimumDuration: TimeInterval
    var emitInterval: TimeInterval

    init(
        minimumLevel: Double = 0.10,
        minimumDuration: TimeInterval = 0.20,
        emitInterval: TimeInterval = 0.12
    ) {
        self.minimumLevel = minimumLevel
        self.minimumDuration = minimumDuration
        self.emitInterval = emitInterval
    }
}

final class SustainedVoiceActivityEmitter: @unchecked Sendable {
    private let configuration: SustainedVoiceActivityEmitterConfiguration
    private let isPlaybackActive: @Sendable () -> Bool
    private var lastEmitTime: TimeInterval = 0
    private var voiceActivityStartedAt: TimeInterval?

    init(
        configuration: SustainedVoiceActivityEmitterConfiguration = SustainedVoiceActivityEmitterConfiguration(),
        isPlaybackActive: @escaping @Sendable () -> Bool = { false }
    ) {
        self.configuration = configuration
        self.isPlaybackActive = isPlaybackActive
    }

    func eventIfNeeded(
        inputLevel level: Double,
        bufferDuration: TimeInterval,
        audioEvidence: SpeechAudioEvidence?,
        now: TimeInterval = Date().timeIntervalSinceReferenceDate
    ) -> VoiceActivityEvent? {
        guard level >= configuration.minimumLevel else {
            voiceActivityStartedAt = nil
            return nil
        }

        if voiceActivityStartedAt == nil {
            voiceActivityStartedAt = now
        }

        let startTime = voiceActivityStartedAt ?? now
        let sustainedDuration = now - startTime
        guard sustainedDuration >= configuration.minimumDuration else { return nil }
        guard now - lastEmitTime >= configuration.emitInterval else { return nil }
        lastEmitTime = now

        return VoiceActivityEvent(
            inputLevel: level,
            duration: max(bufferDuration, sustainedDuration + bufferDuration),
            isAIPlaybackActive: isPlaybackActive(),
            source: .unknown,
            audioEvidence: audioEvidence
        )
    }
}
#endif
