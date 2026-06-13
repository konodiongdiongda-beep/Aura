import Foundation

public actor TTSPlaybackQueue: SpeechPlaybackControlling {
    private let synthesizer: SpeechSynthesizing
    private var segmenter: SentenceSegmenter
    private var pendingSegments: [String] = []
    private var workerTask: Task<Void, Never>?
    private var generation = UUID()
    private var playbackEventContinuations: [AsyncStream<SpeechPlaybackEvent>.Continuation] = []

    public init(synthesizer: SpeechSynthesizing, maxSegmentLength: Int = 80, firstSegmentMinLength: Int = 3) {
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
            pendingSegments.append(contentsOf: segmenter.append(text))
        }
        if isFinal, let remainder = segmenter.flush() {
            pendingSegments.append(remainder)
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
        while !Task.isCancelled {
            guard generation == expectedGeneration else { break }
            guard !pendingSegments.isEmpty else { break }

            let segment = pendingSegments.removeFirst()
            let speechText = SpeechTextSanitizer.sanitizedForSpeech(segment)
            guard !speechText.isEmpty else { continue }
            do {
                emit(.started(speechText))
                try await synthesizer.speak(speechText)
                emit(.finished(speechText))
            } catch is CancellationError {
                break
            } catch {
                continue
            }
        }

        if generation == expectedGeneration {
            workerTask = nil
            if !pendingSegments.isEmpty {
                startWorkerIfNeeded()
            } else {
                emit(.drained)
            }
        }
    }

    private func addPlaybackEventContinuation(_ continuation: AsyncStream<SpeechPlaybackEvent>.Continuation) {
        playbackEventContinuations.append(continuation)
    }

    private func emit(_ event: SpeechPlaybackEvent) {
        playbackEventContinuations.forEach { $0.yield(event) }
    }
}
