import Foundation
import VoiceCore

actor HeuristicSpeakerEvidenceProvider: UserTurnSpeakerEvidenceProviding {
    private let requiredEnrollmentSamples: Int
    private let acceptThreshold: Double
    private let uncertainMargin: Double
    private var enrollmentEmbeddings: [[Double]] = []
    private var profileEmbedding: [Double]?

    init(
        requiredEnrollmentSamples: Int = 2,
        acceptThreshold: Double = 0.82,
        uncertainMargin: Double = 0.08
    ) {
        self.requiredEnrollmentSamples = requiredEnrollmentSamples
        self.acceptThreshold = acceptThreshold
        self.uncertainMargin = uncertainMargin
    }

    func evidence(for request: UserTurnSpeakerEvidenceRequest) async -> UserTurnSpeakerEvidence? {
        let audio = request.audio
        guard let embedding = Self.extractEmbedding(from: audio) else {
            return UserTurnSpeakerEvidence(match: .unavailable, profileID: "adaptive-speaker-v1")
        }

        guard let profileEmbedding else {
            guard request.allowsEnrollment,
                  !request.isAssistantPlaybackActive,
                  !request.isInterruptedInput else {
                return UserTurnSpeakerEvidence(
                    match: .uncertain,
                    threshold: acceptThreshold,
                    margin: uncertainMargin,
                    profileID: "adaptive-speaker-v1-unenrolled"
                )
            }
            enrollmentEmbeddings.append(embedding)
            refreshProfileIfReady()
            return UserTurnSpeakerEvidence(
                match: .verifiedCurrentUser,
                score: 1.0,
                threshold: acceptThreshold,
                margin: uncertainMargin,
                profileID: "adaptive-speaker-v1-enrolling"
            )
        }

        let score = Self.cosineSimilarity(profileEmbedding, embedding)
        let match: UserTurnSpeakerMatch
        if score >= acceptThreshold {
            match = .verifiedCurrentUser
        } else if score >= acceptThreshold - uncertainMargin {
            match = .uncertain
        } else {
            match = .otherSpeaker
        }

        return UserTurnSpeakerEvidence(
            match: match,
            score: score,
            threshold: acceptThreshold,
            margin: uncertainMargin,
            profileID: "adaptive-speaker-v1"
        )
    }

    private func refreshProfileIfReady() {
        guard enrollmentEmbeddings.count >= requiredEnrollmentSamples else { return }
        profileEmbedding = Self.centroid(enrollmentEmbeddings)
    }

    private static func extractEmbedding(from audio: SpeechAudioEvidence) -> [Double]? {
        let samples = pcmSamples(from: audio.pcm16MonoData)
        guard samples.count >= max(256, audio.sampleRate / 4) else { return nil }

        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
        let zcr = zeroCrossingRate(samples)
        let bands = [120.0, 180.0, 240.0, 320.0, 430.0, 560.0, 720.0, 950.0, 1_300.0, 1_800.0, 2_500.0, 3_400.0]
        let powers = bands.map { goertzelPower(samples: samples, sampleRate: audio.sampleRate, frequency: $0) }
        let totalPower = max(powers.reduce(0, +), 1e-12)
        var features = powers.map { log1p($0 / totalPower * 1_000) }
        features.append(log1p(rms * 100))
        features.append(zcr)
        return normalized(features)
    }

    private static func pcmSamples(from data: Data) -> [Double] {
        var samples: [Double] = []
        samples.reserveCapacity(data.count / 2)
        var index = data.startIndex
        while index + 1 < data.endIndex {
            let low = UInt16(data[index])
            let high = UInt16(data[index + 1]) << 8
            let value = Int16(bitPattern: high | low)
            samples.append(Double(value) / Double(Int16.max))
            index += 2
        }
        return samples
    }

    private static func zeroCrossingRate(_ samples: [Double]) -> Double {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        for index in 1..<samples.count {
            if (samples[index - 1] < 0 && samples[index] >= 0) ||
                (samples[index - 1] >= 0 && samples[index] < 0) {
                crossings += 1
            }
        }
        return Double(crossings) / Double(samples.count - 1)
    }

    private static func goertzelPower(samples: [Double], sampleRate: Int, frequency: Double) -> Double {
        let normalizedFrequency = frequency / Double(sampleRate)
        let coefficient = 2 * cos(2 * Double.pi * normalizedFrequency)
        var previous = 0.0
        var previous2 = 0.0
        for sample in samples {
            let current = sample + coefficient * previous - previous2
            previous2 = previous
            previous = current
        }
        return previous2 * previous2 + previous * previous - coefficient * previous * previous2
    }

    private static func centroid(_ embeddings: [[Double]]) -> [Double]? {
        guard let first = embeddings.first else { return nil }
        var sum = Array(repeating: 0.0, count: first.count)
        for embedding in embeddings where embedding.count == sum.count {
            for index in embedding.indices {
                sum[index] += embedding[index]
            }
        }
        let count = max(Double(embeddings.count), 1)
        return normalized(sum.map { $0 / count })
    }

    private static func normalized(_ values: [Double]) -> [Double] {
        let norm = sqrt(values.reduce(0) { $0 + $1 * $1 })
        guard norm > 1e-9 else { return values }
        return values.map { $0 / norm }
    }

    private static func cosineSimilarity(_ left: [Double], _ right: [Double]) -> Double {
        guard left.count == right.count else { return 0 }
        let dot = zip(left, right).reduce(0) { $0 + $1.0 * $1.1 }
        let leftNorm = sqrt(left.reduce(0) { $0 + $1 * $1 })
        let rightNorm = sqrt(right.reduce(0) { $0 + $1 * $1 })
        guard leftNorm > 1e-9, rightNorm > 1e-9 else { return 0 }
        return dot / (leftNorm * rightNorm)
    }
}
