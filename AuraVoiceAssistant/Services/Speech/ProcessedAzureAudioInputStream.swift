#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import AVFoundation
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

final class ProcessedAzureAudioInputStream: @unchecked Sendable {
    private let sharedEngine: SharedVoiceAudioEngine
    private var engine: AVAudioEngine { sharedEngine.engine }
    private let pushStream: SPXPushAudioInputStream
    private let targetFormat: AVAudioFormat
    private let onVoiceActivity: @Sendable (VoiceActivityEvent) -> Void
    private let acousticEchoCanceller: (any AcousticEchoCancelling)?
    private let voiceActivityEmitter: SustainedVoiceActivityEmitter
    private let audioEvidenceBuffer: MicrophoneAudioEvidenceBuffer
    private let writeQueue = DispatchQueue(label: "com.aura.voiceassistant.azure.push-audio")
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var isRunning = false
    private let isPlaybackActive: @Sendable () -> Bool

    let audioConfiguration: SPXAudioConfiguration
    private(set) var voiceProcessingEnabled = false

    init(
        sharedEngine: SharedVoiceAudioEngine,
        onVoiceActivity: @escaping @Sendable (VoiceActivityEvent) -> Void = { _ in },
        acousticEchoCanceller: (any AcousticEchoCancelling)? = nil,
        isPlaybackActive: @escaping @Sendable () -> Bool = { false }
    ) throws {
        guard let streamFormat = SPXAudioStreamFormat(
            usingPCMWithSampleRate: 16_000,
            bitsPerSample: 16,
            channels: 1
        ) else {
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to create Azure PCM stream format.")
        }
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to create microphone conversion format.")
        }
        guard let pushStream = SPXPushAudioInputStream(audioFormat: streamFormat) else {
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to create Azure push audio stream.")
        }
        guard let audioConfiguration = SPXAudioConfiguration(streamInput: pushStream) else {
            pushStream.close()
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to create Azure stream audio configuration.")
        }

        self.sharedEngine = sharedEngine
        self.pushStream = pushStream
        self.audioConfiguration = audioConfiguration
        self.targetFormat = targetFormat
        self.onVoiceActivity = onVoiceActivity
        self.acousticEchoCanceller = acousticEchoCanceller
        self.isPlaybackActive = isPlaybackActive
        self.voiceActivityEmitter = SustainedVoiceActivityEmitter(isPlaybackActive: isPlaybackActive)
        self.audioEvidenceBuffer = MicrophoneAudioEvidenceBuffer(
            sampleRate: 16_000,
            maxDuration: 5.0
        )
    }

    func start() throws {
        guard !isRunning else { return }

        // The shared engine owns VPIO. Configure it (attaches the player node and
        // enables voice processing) before reading the input format — VPIO changes
        // the input node's reported format.
        try sharedEngine.configure()
        voiceProcessingEnabled = sharedEngine.voiceProcessingEnabled

        let inputNode = engine.inputNode
        engine.prepare()

        guard let sourceFormat = resolveValidInputFormat(on: inputNode) else {
            let reported = inputNode.outputFormat(forBus: 0)
            converter = nil
            inputFormat = nil
            throw VoiceCore.AppError.speechRecognitionFailed(
                "No usable microphone input is available on this device (input format \(reported.sampleRate) Hz, \(reported.channelCount) ch). Microphone capture requires a real device or a Simulator with host microphone access."
            )
        }
        inputFormat = sourceFormat
        converter = AVAudioConverter(from: sourceFormat, to: targetFormat)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: sourceFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }

        do {
            try sharedEngine.start()
            isRunning = true
            NSLog("[ProcessedAzureAudioInputStream] started shared-engine PCM input voiceProcessing=\(voiceProcessingEnabled) sourceRate=\(sourceFormat.sampleRate)")
        } catch {
            inputNode.removeTap(onBus: 0)
            converter = nil
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to start processed microphone input: \(error.localizedDescription)")
        }
    }

    /// Reads the input node's hardware format, briefly polling because the node
    /// can momentarily report a 0 Hz sample rate right after (re)configuration —
    /// especially on the iOS Simulator. Returns nil only if no valid format ever
    /// appears, so the caller can fail cleanly instead of crashing in installTap.
    private func resolveValidInputFormat(on inputNode: AVAudioInputNode) -> AVAudioFormat? {
        for attempt in 0..<10 {
            let format = inputNode.outputFormat(forBus: 0)
            if format.sampleRate > 0, format.channelCount > 0 {
                return format
            }
            if attempt < 9 {
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        return nil
    }

    func stop() {
        guard isRunning else {
            pushStream.close()
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        // Do NOT stop the shared engine here: TTS playback shares it and the
        // engine lifecycle is owned by the session, not by mic capture alone.
        converter = nil
        inputFormat = nil
        isRunning = false
        pushStream.close()
        NSLog("[ProcessedAzureAudioInputStream] stopped shared-engine PCM input")
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let inputLevel = inputLevel(for: buffer)

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 8)
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            NSLog("[ProcessedAzureAudioInputStream] conversion failed: \(conversionError.localizedDescription)")
            return
        }

        guard status == .haveData || status == .inputRanDry else { return }

        write(converted)

        writeQueue.async { [weak self] in
            guard let self else { return }
            if !self.isPlaybackActive() {
                AudioLevelMonitor.shared.currentLevel = inputLevel
            }
            self.emitVoiceActivityIfNeeded(
                bufferDuration: TimeInterval(buffer.frameLength) / max(buffer.format.sampleRate, 1),
                inputLevel: inputLevel,
                audioEvidence: self.recentAudioEvidence(maxDuration: 1.2)
            )
        }
    }

    private func write(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let channelData = buffer.int16ChannelData else { return }

        let byteCount = Int(buffer.frameLength) * Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let microphoneData = Data(bytes: channelData[0], count: byteCount)
        // When VPIO is active the hardware already cancels the assistant's voice.
        // Running the software Speex canceller on top would double-subtract and
        // distort speech, so only apply it as a fallback when VPIO is unavailable.
        let data: Data
        if voiceProcessingEnabled {
            data = microphoneData
        } else {
            data = acousticEchoCanceller?.processMicrophonePCM16(
                microphoneData,
                sampleRate: Int(buffer.format.sampleRate)
            ) ?? microphoneData
        }
        audioEvidenceBuffer.appendPCM16Mono(data)
        writeQueue.async { [pushStream] in
            pushStream.write(data)
        }
    }

    func recentAudioEvidence(maxDuration: TimeInterval = 2.5) -> SpeechAudioEvidence? {
        audioEvidenceBuffer.snapshot(maxDuration: maxDuration)
    }

    private func emitVoiceActivityIfNeeded(
        bufferDuration: TimeInterval,
        inputLevel level: Double,
        audioEvidence: SpeechAudioEvidence?
    ) {
        guard let event = voiceActivityEmitter.eventIfNeeded(
            inputLevel: level,
            bufferDuration: bufferDuration,
            audioEvidence: audioEvidence
        ) else { return }
        onVoiceActivity(event)
    }

    private func inputLevel(for buffer: AVAudioPCMBuffer) -> Double {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            var sum: Float = 0
            let stride = max(1, frameLength / 256)
            var i = 0
            while i < frameLength {
                let sample = channelData[0][i]
                sum += sample * sample
                i += stride
            }
            let mean = sum / Float(i / stride)
            return min(1, Double(sqrt(mean)))
        }

        if let channelData = buffer.int16ChannelData {
            var sum: Double = 0
            let stride = max(1, frameLength / 256)
            var i = 0
            while i < frameLength {
                let sample = Double(channelData[0][i]) / Double(Int16.max)
                sum += sample * sample
                i += stride
            }
            let mean = sum / Double(i / stride)
            return min(1, sqrt(mean))
        }

        return 0
    }
}
#endif
