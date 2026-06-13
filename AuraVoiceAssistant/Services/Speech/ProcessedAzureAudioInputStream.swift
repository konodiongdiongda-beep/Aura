#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import AVFoundation
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

final class ProcessedAzureAudioInputStream: @unchecked Sendable {
    private let engine = AVAudioEngine()
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

    let audioConfiguration: SPXAudioConfiguration
    private(set) var voiceProcessingEnabled = false

    init(
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

        self.pushStream = pushStream
        self.audioConfiguration = audioConfiguration
        self.targetFormat = targetFormat
        self.onVoiceActivity = onVoiceActivity
        self.acousticEchoCanceller = acousticEchoCanceller
        self.voiceActivityEmitter = SustainedVoiceActivityEmitter(isPlaybackActive: isPlaybackActive)
        self.audioEvidenceBuffer = MicrophoneAudioEvidenceBuffer(
            sampleRate: 16_000,
            maxDuration: 5.0
        )
    }

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            voiceProcessingEnabled = true
        } catch {
            voiceProcessingEnabled = false
            NSLog("[ProcessedAzureAudioInputStream] voice processing unavailable: \(error.localizedDescription)")
        }

        let sourceFormat = inputNode.outputFormat(forBus: 0)
        inputFormat = sourceFormat
        converter = AVAudioConverter(from: sourceFormat, to: targetFormat)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: sourceFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            NSLog("[ProcessedAzureAudioInputStream] started app-owned PCM input voiceProcessing=\(voiceProcessingEnabled) sourceRate=\(sourceFormat.sampleRate)")
        } catch {
            inputNode.removeTap(onBus: 0)
            converter = nil
            throw VoiceCore.AppError.speechRecognitionFailed("Unable to start processed microphone input: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isRunning else {
            pushStream.close()
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        inputFormat = nil
        isRunning = false
        pushStream.close()
        print("[ProcessedAzureAudioInputStream] stopped app-owned PCM input")
        NSLog("[ProcessedAzureAudioInputStream] stopped app-owned PCM input")
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
        emitVoiceActivityIfNeeded(
            bufferDuration: TimeInterval(buffer.frameLength) / max(buffer.format.sampleRate, 1),
            inputLevel: inputLevel,
            audioEvidence: recentAudioEvidence(maxDuration: 1.2)
        )
    }

    private func write(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let channelData = buffer.int16ChannelData else { return }

        let byteCount = Int(buffer.frameLength) * Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let microphoneData = Data(bytes: channelData[0], count: byteCount)
        let data = acousticEchoCanceller?.processMicrophonePCM16(
            microphoneData,
            sampleRate: Int(buffer.format.sampleRate)
        ) ?? microphoneData
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
            let channelCount = max(1, Int(buffer.format.channelCount))
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = samples[frame]
                    sum += sample * sample
                }
            }
            let mean = sum / Float(frameLength * channelCount)
            return min(1, Double(sqrt(mean)))
        }

        if let channelData = buffer.int16ChannelData {
            var sum: Double = 0
            let channelCount = max(1, Int(buffer.format.channelCount))
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = Double(samples[frame]) / Double(Int16.max)
                    sum += sample * sample
                }
            }
            let mean = sum / Double(frameLength * channelCount)
            return min(1, sqrt(mean))
        }

        return 0
    }
}
#endif
