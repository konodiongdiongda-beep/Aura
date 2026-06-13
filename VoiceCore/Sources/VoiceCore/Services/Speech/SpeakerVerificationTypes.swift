import Foundation

/// Pure speaker-verification types for the CAM++ voiceprint, ported from the
/// Talk_now Python backend (`voiceprint/server.py`). The actual embedding model
/// is injected via `SpeakerEmbedding` so the verification logic in
/// `SpeakerVerificationEngine` is fully unit-testable without any ONNX / C
/// dependency.
///
/// Cosine score >= `threshold` (default 0.35, the CAM++ zh-cn operating point)
/// means "same speaker".
public protocol SpeakerEmbedding: Sendable {
    /// Compute one embedding for the given 16 kHz mono samples. May be raw
    /// (un-normalized); the engine L2-normalizes before use. Returns nil if the
    /// model could not produce an embedding.
    func embed(samples: [Float]) -> [Float]?
    var dimension: Int { get }
}

public struct SpeakerVerificationResult: Equatable, Sendable {
    public var isPrimarySpeaker: Bool?
    public var score: Double
    public var threshold: Double
    public var windows: Int
    public var reason: String?

    public init(
        isPrimarySpeaker: Bool?,
        score: Double,
        threshold: Double,
        windows: Int,
        reason: String? = nil
    ) {
        self.isPrimarySpeaker = isPrimarySpeaker
        self.score = score
        self.threshold = threshold
        self.windows = windows
        self.reason = reason
    }
}

public struct SpeakerEnrollmentResult: Equatable, Sendable {
    public var ok: Bool
    public var samples: Int
    public var voicedSeconds: Double
    public var neededSeconds: Double
    public var error: String?

    public init(
        ok: Bool,
        samples: Int,
        voicedSeconds: Double,
        neededSeconds: Double,
        error: String? = nil
    ) {
        self.ok = ok
        self.samples = samples
        self.voicedSeconds = voicedSeconds
        self.neededSeconds = neededSeconds
        self.error = error
    }
}

public struct SpeakerVerificationConfiguration: Sendable {
    public var threshold: Double
    public var targetSampleRate: Int
    public var minimumEnrollVoicedSeconds: Double
    public var windowSeconds: Double
    public var windowStepSeconds: Double

    public init(
        threshold: Double = 0.35,
        targetSampleRate: Int = 16_000,
        minimumEnrollVoicedSeconds: Double = 0.8,
        windowSeconds: Double = 1.5,
        windowStepSeconds: Double = 0.5
    ) {
        self.threshold = threshold
        self.targetSampleRate = targetSampleRate
        self.minimumEnrollVoicedSeconds = minimumEnrollVoicedSeconds
        self.windowSeconds = windowSeconds
        self.windowStepSeconds = windowStepSeconds
    }
}
