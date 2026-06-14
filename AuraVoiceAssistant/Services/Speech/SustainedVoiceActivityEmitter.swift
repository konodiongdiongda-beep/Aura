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
    /// Energy level just before the current speech burst began. Captured on the
    /// last sub-threshold frame so onset sharpness = peak - thisFloor.
    private var preSpeechFloor: Double = 0
    private var onsetLevelAtStart: Double = 0
    private var lastLevel: Double = 0

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
            // Below threshold: this is the quiet floor speech will rise from.
            // Track it so the next burst can measure its onset jump.
            preSpeechFloor = level
            lastLevel = level
            voiceActivityStartedAt = nil
            return nil
        }

        if voiceActivityStartedAt == nil {
            voiceActivityStartedAt = now
            onsetLevelAtStart = preSpeechFloor
        }
        lastLevel = level

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
            audioEvidence: audioEvidence,
            onsetRate: max(0, level - onsetLevelAtStart)
        )
    }
}
#endif
