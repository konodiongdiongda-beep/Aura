#if os(iOS)
import AVFoundation
import Foundation

#if !targetEnvironment(simulator) && canImport(AuraAEC)
import AuraAEC
#endif

protocol AssistantAudioReferenceCapturing: Sendable {
    func appendPlaybackAudioData(_ data: Data)
    func resetPlaybackReference()
}

protocol AcousticEchoCancelling: AssistantAudioReferenceCapturing {
    func processMicrophonePCM16(_ data: Data, sampleRate: Int) -> Data
}

final class EchoReferenceAudioBus: @unchecked Sendable {
    private let lock = NSLock()
    private let maxBytes: Int
    private var data = Data()

    init(sampleRate: Int = 16_000, maxDuration: TimeInterval = 8) {
        self.maxBytes = max(1, Int(maxDuration * Double(sampleRate)) * 2)
    }

    func appendPCM16(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        if data.count > maxBytes {
            data.removeFirst(data.count - maxBytes)
        }
        lock.unlock()
    }

    func consume(byteCount requestedByteCount: Int) -> Data {
        let byteCount = max(0, requestedByteCount)
        guard byteCount > 0 else { return Data() }

        lock.lock()
        defer { lock.unlock() }

        if data.isEmpty {
            return Data(repeating: 0, count: byteCount)
        }

        let availableCount = min(byteCount, data.count)
        var output = Data(data.prefix(availableCount))
        data.removeFirst(availableCount)
        if output.count < byteCount {
            output.append(Data(repeating: 0, count: byteCount - output.count))
        }
        return output
    }

    func reset() {
        lock.lock()
        data.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}

final class ReferenceAcousticEchoCanceller: AcousticEchoCancelling, @unchecked Sendable {
    private let referenceBus: EchoReferenceAudioBus
    private let processor: any AcousticEchoProcessing
    private let referenceSampleRate: Int

    init(
        referenceBus: EchoReferenceAudioBus = EchoReferenceAudioBus(),
        processor: any AcousticEchoProcessing = PlatformAcousticEchoProcessor.make(),
        referenceSampleRate: Int = 16_000
    ) {
        self.referenceBus = referenceBus
        self.processor = processor
        self.referenceSampleRate = referenceSampleRate
    }

    func appendPlaybackAudioData(_ data: Data) {
        guard let pcm = AudioReferencePCMDecoder.decodePCM16Mono(
            fromAudioData: data,
            targetSampleRate: Double(referenceSampleRate)
        ) else { return }
        referenceBus.appendPCM16(pcm)
    }

    func appendFarEndPCM16(_ data: Data) {
        referenceBus.appendPCM16(data)
    }

    func processMicrophonePCM16(_ data: Data, sampleRate: Int) -> Data {
        guard !data.isEmpty, sampleRate == referenceSampleRate else { return data }
        let echo = referenceBus.consume(byteCount: data.count)
        guard echo.contains(where: { $0 != 0 }) else { return data }
        return processor.process(nearEndPCM16: data, farEndPCM16: echo, sampleRate: sampleRate)
    }

    func resetPlaybackReference() {
        referenceBus.reset()
        processor.reset()
    }
}

protocol AcousticEchoProcessing: Sendable {
    func process(nearEndPCM16: Data, farEndPCM16: Data, sampleRate: Int) -> Data
    func reset()
}

enum PlatformAcousticEchoProcessor {
    static func make() -> any AcousticEchoProcessing {
        #if !targetEnvironment(simulator) && canImport(AuraAEC)
        return SpeexAcousticEchoProcessor()
        #else
        return DebugSubtractiveEchoProcessor()
        #endif
    }
}

final class DebugSubtractiveEchoProcessor: AcousticEchoProcessing, @unchecked Sendable {
    private let attenuation: Float

    init(attenuation: Float = 0.8) {
        self.attenuation = attenuation
    }

    func process(nearEndPCM16: Data, farEndPCM16: Data, sampleRate: Int) -> Data {
        let sampleCount = min(nearEndPCM16.count, farEndPCM16.count) / 2
        guard sampleCount > 0 else { return nearEndPCM16 }

        var output = Data(count: sampleCount * 2)
        nearEndPCM16.withUnsafeBytes { nearRawBuffer in
            farEndPCM16.withUnsafeBytes { farRawBuffer in
                output.withUnsafeMutableBytes { outRawBuffer in
                    guard let nearSamples = nearRawBuffer.bindMemory(to: Int16.self).baseAddress,
                          let farSamples = farRawBuffer.bindMemory(to: Int16.self).baseAddress,
                          let outSamples = outRawBuffer.bindMemory(to: Int16.self).baseAddress else {
                        return
                    }
                    for index in 0..<sampleCount {
                        let value = Float(nearSamples[index]) - Float(farSamples[index]) * attenuation
                        outSamples[index] = Int16(clamping: Int(value.rounded()))
                    }
                }
            }
        }
        if nearEndPCM16.count > output.count {
            output.append(nearEndPCM16.suffix(nearEndPCM16.count - output.count))
        }
        return output
    }

    func reset() {}
}

#if !targetEnvironment(simulator) && canImport(AuraAEC)
final class SpeexAcousticEchoProcessor: AcousticEchoProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private let frameSize = 160
    private let filterLength = 1_600
    private let sampleRate = 16_000
    private var handle: OpaquePointer?

    init() {
        handle = AecNew(UInt(frameSize), Int32(filterLength), UInt32(sampleRate), true)
    }

    deinit {
        if let handle {
            AecDestroy(handle)
        }
    }

    func process(nearEndPCM16: Data, farEndPCM16: Data, sampleRate: Int) -> Data {
        guard sampleRate == self.sampleRate else { return nearEndPCM16 }
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return nearEndPCM16 }

        let totalSamples = nearEndPCM16.count / 2
        guard totalSamples > 0 else { return nearEndPCM16 }

        var output = Data(count: totalSamples * 2)
        nearEndPCM16.withUnsafeBytes { nearRawBuffer in
            farEndPCM16.withUnsafeBytes { farRawBuffer in
                output.withUnsafeMutableBytes { outRawBuffer in
                    guard let nearSamples = nearRawBuffer.bindMemory(to: Int16.self).baseAddress,
                          let farSamples = farRawBuffer.bindMemory(to: Int16.self).baseAddress,
                          let outSamples = outRawBuffer.bindMemory(to: Int16.self).baseAddress else {
                        return
                    }

                    var offset = 0
                    while offset < totalSamples {
                        let count = min(frameSize, totalSamples - offset)
                        if count == frameSize {
                            AecCancelEcho(
                                handle,
                                nearSamples.advanced(by: offset),
                                farSamples.advanced(by: offset),
                                outSamples.advanced(by: offset),
                                UInt(count)
                            )
                        } else {
                            var nearFrame = [Int16](repeating: 0, count: frameSize)
                            var farFrame = [Int16](repeating: 0, count: frameSize)
                            var outFrame = [Int16](repeating: 0, count: frameSize)
                            for index in 0..<count {
                                nearFrame[index] = nearSamples[offset + index]
                                farFrame[index] = farSamples[offset + index]
                            }
                            nearFrame.withUnsafeBufferPointer { nearPointer in
                                farFrame.withUnsafeBufferPointer { farPointer in
                                    outFrame.withUnsafeMutableBufferPointer { outPointer in
                                        AecCancelEcho(
                                            handle,
                                            nearPointer.baseAddress,
                                            farPointer.baseAddress,
                                            outPointer.baseAddress,
                                            UInt(frameSize)
                                        )
                                    }
                                }
                            }
                            for index in 0..<count {
                                outSamples[offset + index] = outFrame[index]
                            }
                        }
                        offset += count
                    }
                }
            }
        }
        return output
    }

    func reset() {
        lock.lock()
        if let handle {
            AecDestroy(handle)
        }
        handle = AecNew(UInt(frameSize), Int32(filterLength), UInt32(sampleRate), true)
        lock.unlock()
    }
}
#endif

enum AudioReferencePCMDecoder {
    static func decodePCM16Mono(fromAudioData data: Data, targetSampleRate: Double = 16_000) -> Data? {
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("audio")
        do {
            try data.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            let file = try AVAudioFile(forReading: url)
            guard let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: sourceBuffer)
            return convertToPCM16Mono(sourceBuffer, targetSampleRate: targetSampleRate)
        } catch {
            return nil
        }
    }

    static func convertToPCM16Mono(_ buffer: AVAudioPCMBuffer, targetSampleRate: Double = 16_000) -> Data? {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else { return nil }

        guard buffer.format != targetFormat else {
            return data(fromPCM16Buffer: buffer)
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return nil }
        let ratio = targetSampleRate / max(buffer.format.sampleRate, 1)
        let capacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 8)
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }

        var didProvideInput = false
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, status == .haveData || status == .inputRanDry else { return nil }
        return data(fromPCM16Buffer: converted)
    }

    private static func data(fromPCM16Buffer buffer: AVAudioPCMBuffer) -> Data? {
        guard buffer.frameLength > 0, let channelData = buffer.int16ChannelData else { return nil }
        let byteCount = Int(buffer.frameLength) * Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        return Data(bytes: channelData[0], count: byteCount)
    }
}
#endif
