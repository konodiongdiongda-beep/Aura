import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.aura.voicecore", category: "TTSPlaybackQueue")

public actor TTSPlaybackQueue: SpeechPlaybackControlling {
    private let synthesizer: SpeechSynthesizing
    private var segmenter: SentenceSegmenter
    private var pendingSegments: [String] = []
    private var workerTask: Task<Void, Never>?
    private var generation = UUID()
    private var playbackEventContinuations: [AsyncStream<SpeechPlaybackEvent>.Continuation] = []

    public init(synthesizer: SpeechSynthesizing, maxSegmentLength: Int = 40, firstSegmentMinLength: Int = 2) {
        self.synthesizer = synthesizer
        self.segmenter = SentenceSegmenter(
            maxSegmentLength: maxSegmentLength,
            firstSegmentMinLength: firstSegmentMinLength
        )
    }

    public func playbackEvents() async -> AsyncStream<SpeechPlaybackEvent> {
        AsyncStream { continuation in
            self.addPlaybackEventContinuation(continuation)
        }
    }

    public func enqueue(_ text: String, isFinal: Bool = false) {
        if !text.isEmpty {
            let newSegments = segmenter.append(text)
            pendingSegments.append(contentsOf: newSegments)
            let msg = "Enqueued \(text.count) chars → \(newSegments.count) segments. Total pending: \(self.pendingSegments.count)"
            logger.debug("\(msg, privacy: .public)")
            LogCapture.shared.log(msg)
        }
        if isFinal, let remainder = segmenter.flush() {
            pendingSegments.append(remainder)
            let msg = "Final flush remainder: \(remainder.count) chars. Total pending now: \(self.pendingSegments.count)"
            logger.debug("\(msg, privacy: .public)")
            LogCapture.shared.log(msg)
        }
        startWorkerIfNeeded()
    }

    public func clear() {
        pendingSegments.removeAll()
        _ = segmenter.flush()
    }

    public func cancel() async {
        generation = UUID()
        pendingSegments.removeAll()
        _ = segmenter.flush()
        workerTask?.cancel()
        workerTask = nil
        await synthesizer.cancel()
        emit(.cancelled)
    }

    private func startWorkerIfNeeded() {
        guard workerTask == nil else { return }

        let currentGeneration = generation
        workerTask = Task { [weak self] in
            guard let self else { return }
            await self.drain(generation: currentGeneration)
        }
    }

    private func drain(generation expectedGeneration: UUID) async {
        let startMsg = "Drain worker started. Gen: \(expectedGeneration.uuidString)"
        logger.info("\(startMsg, privacy: .public)")
        LogCapture.shared.log(startMsg, level: "INFO")

        var processedCount = 0
        var errorCount = 0
        // Audio for the NEXT segment is synthesized while the CURRENT one plays,
        // so segment boundaries no longer insert a synthesis round-trip of
        // silence (the cause of the "好的，我收到。了" stutter).
        var prefetchText: String?
        var prefetchTask: Task<SpeechSynthesisOutput, Error>?

        defer { prefetchTask?.cancel() }

        while !Task.isCancelled {
            guard generation == expectedGeneration else {
                let msg = "Generation mismatch. Current: \(self.generation.uuidString)"
                logger.warning("\(msg, privacy: .public)")
                LogCapture.shared.log(msg, level: "WARNING")
                break
            }

            let currentText: String
            let currentTask: Task<SpeechSynthesisOutput, Error>
            if let prefetchText, let prefetchTask {
                currentText = prefetchText
                currentTask = prefetchTask
            } else {
                guard let text = nextSpeechText() else { break }
                currentText = text
                currentTask = synthesisTask(for: text)
            }

            if let nextText = nextSpeechText() {
                prefetchText = nextText
                prefetchTask = synthesisTask(for: nextText)
            } else {
                prefetchText = nil
                prefetchTask = nil
            }

            do {
                let preview = String(currentText.prefix(40))
                let startSynthMsg = "Synthesis START: '\(preview)...' (length: \(currentText.count))"
                logger.info("\(startSynthMsg, privacy: .public)")
                LogCapture.shared.log(startSynthMsg, level: "INFO")

                let output = try await currentTask.value
                guard generation == expectedGeneration, !Task.isCancelled else {
                    prefetchTask?.cancel()
                    break
                }

                emit(.started(currentText))
                try await synthesizer.play(output)
                emit(.finished(currentText))
                processedCount += 1

                let endSynthMsg = "Synthesis DONE: '\(preview)...' | Processed: \(processedCount), Remaining: \(self.pendingSegments.count)"
                logger.info("\(endSynthMsg, privacy: .public)")
                LogCapture.shared.log(endSynthMsg, level: "INFO")
            } catch is CancellationError {
                let msg = "Synthesis cancelled"
                logger.warning("\(msg, privacy: .public)")
                LogCapture.shared.log(msg, level: "WARNING")
                break
            } catch {
                errorCount += 1
                let msg = "Synthesis failed: \(error). Continuing to next segment."
                logger.error("\(msg, privacy: .public)")
                LogCapture.shared.log(msg, level: "ERROR")
                continue
            }
        }

        if generation == expectedGeneration {
            workerTask = nil
            let endMsg = "Drain ended. Processed: \(processedCount), Errors: \(errorCount), Pending: \(self.pendingSegments.count)"
            logger.info("\(endMsg, privacy: .public)")
            LogCapture.shared.log(endMsg, level: "INFO")
            if !pendingSegments.isEmpty {
                startWorkerIfNeeded()
            } else {
                emit(.drained)
            }
        }
    }

    /// Pops queued segments until one yields non-empty speech text after
    /// sanitization, returning nil when the queue is exhausted.
    private func nextSpeechText() -> String? {
        while !pendingSegments.isEmpty {
            let segment = pendingSegments.removeFirst()
            let speechText = SpeechTextSanitizer.sanitizedForSpeech(segment)
            if !speechText.isEmpty {
                return speechText
            }
            let msg = "Skipped empty segment after sanitization"
            logger.debug("\(msg, privacy: .public)")
            LogCapture.shared.log(msg, level: "DEBUG")
        }
        return nil
    }

    private func synthesisTask(for text: String) -> Task<SpeechSynthesisOutput, Error> {
        Task { [synthesizer] in
            try await synthesizer.synthesize(text)
        }
    }

    private func addPlaybackEventContinuation(_ continuation: AsyncStream<SpeechPlaybackEvent>.Continuation) {
        playbackEventContinuations.append(continuation)
    }

    private func emit(_ event: SpeechPlaybackEvent) {
        playbackEventContinuations.forEach { $0.yield(event) }
    }
}
