#if os(iOS)
import Foundation
import VoiceCore

#if canImport(sherpa_onnx)
import sherpa_onnx

/// Real CAM++ speaker-embedding model backed by sherpa-onnx. Loads the
/// 3D-Speaker CAM++ zh-cn 192-dim ONNX model (the same model + library version,
/// 1.13.x, used by the Talk_now Python backend) and produces one embedding per
/// audio buffer. Conforms to VoiceCore's `SpeakerEmbedding` so it drops straight
/// into `SpeakerVerificationEngine`.
///
/// Thread-safety: the underlying extractor is used behind a lock; each
/// `embed(samples:)` creates its own stream, so concurrent calls are safe.
final class SherpaSpeakerEmbeddingModel: SpeakerEmbedding, @unchecked Sendable {
    private let extractor: OpaquePointer
    private let lock = NSLock()
    let dimension: Int

    /// - Parameter modelPath: absolute path to `campplus_zh_cn_common.onnx`.
    init?(modelPath: String, numThreads: Int = 1) {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("[SherpaSpeakerEmbeddingModel] model not found at \(modelPath)")
            return nil
        }
        var created: OpaquePointer?
        modelPath.withCString { modelC in
            "cpu".withCString { providerC in
                var config = SherpaOnnxSpeakerEmbeddingExtractorConfig(
                    model: modelC,
                    num_threads: Int32(numThreads),
                    debug: 0,
                    provider: providerC
                )
                created = SherpaOnnxCreateSpeakerEmbeddingExtractor(&config)
            }
        }
        guard let created else {
            print("[SherpaSpeakerEmbeddingModel] failed to create extractor")
            return nil
        }
        self.extractor = created
        self.dimension = Int(SherpaOnnxSpeakerEmbeddingExtractorDim(created))
    }

    deinit {
        SherpaOnnxDestroySpeakerEmbeddingExtractor(extractor)
    }

    func embed(samples: [Float]) -> [Float]? {
        guard !samples.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }

        guard let stream = SherpaOnnxSpeakerEmbeddingExtractorCreateStream(extractor) else {
            return nil
        }
        defer { SherpaOnnxDestroyOnlineStream(stream) }

        samples.withUnsafeBufferPointer { buf in
            SherpaOnnxOnlineStreamAcceptWaveform(stream, 16_000, buf.baseAddress, Int32(buf.count))
        }
        SherpaOnnxOnlineStreamInputFinished(stream)

        guard SherpaOnnxSpeakerEmbeddingExtractorIsReady(extractor, stream) == 1 else {
            return nil
        }
        guard let ptr = SherpaOnnxSpeakerEmbeddingExtractorComputeEmbedding(extractor, stream) else {
            return nil
        }
        defer { SherpaOnnxSpeakerEmbeddingExtractorDestroyEmbedding(ptr) }
        return [Float](UnsafeBufferPointer(start: ptr, count: dimension))
    }
}
#endif

/// Resolves the bundled CAM++ model path and builds the verification engine.
/// Returns nil when the sherpa-onnx SDK or the model resource is unavailable, so
/// callers can fall back to the no-op evidence provider.
enum SpeakerVerificationModelLoader {
    static let modelResourceName = "campplus_zh_cn_common"

    static func makeEngine() -> SpeakerVerificationEngine? {
        #if canImport(sherpa_onnx)
        guard let path = Bundle.main.path(forResource: modelResourceName, ofType: "onnx") else {
            print("[SpeakerVerificationModelLoader] \(modelResourceName).onnx not in bundle")
            return nil
        }
        guard let model = SherpaSpeakerEmbeddingModel(modelPath: path) else { return nil }
        return SpeakerVerificationEngine(model: model)
        #else
        return nil
        #endif
    }
}
#endif
