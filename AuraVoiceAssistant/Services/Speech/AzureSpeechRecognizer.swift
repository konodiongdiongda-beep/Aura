#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import AVFoundation
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

actor AzureSpeechRecognizer: SpeechRecognizing {
    private let configuration: AzureSpeechConfiguration
    private let acousticEchoCanceller: (any AcousticEchoCancelling)?
    private let sharedEngine: SharedVoiceAudioEngine
    private var recognizer: SPXSpeechRecognizer?
    private var processedAudioInput: ProcessedAzureAudioInputStream?
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    private var isRunning = false
    /// Set while we are intentionally tearing the session down (stop/cancel), so a
    /// resulting cancellation is NOT mistaken for a transient failure to retry.
    private var isStopping = false
    /// Set while paused (e.g., app backgrounded) but still in an active call.
    private var isPaused = false
    /// Cold-start connections to Azure occasionally fail on the very first launch
    /// ("Connection failed (no connection to the service)"). That is transient, so
    /// we rebuild the session a few times before surfacing a fatal error.
    private var restartAttempts = 0
    private let maxRestartAttempts = 3
    /// Written by the Coordinator on MainActor; read synchronously from the audio tap closure.
    nonisolated(unsafe) var isPlaybackActive = false

    init(
        configuration: AzureSpeechConfiguration,
        sharedEngine: SharedVoiceAudioEngine,
        acousticEchoCanceller: (any AcousticEchoCancelling)? = nil
    ) {
        self.configuration = configuration
        self.sharedEngine = sharedEngine
        self.acousticEchoCanceller = acousticEchoCanceller
    }

    func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func start() async throws {
        NSLog("[AzureSpeechRecognizer] start() called")
        let granted = await requestMicrophonePermissionIfNeeded()
        NSLog("[AzureSpeechRecognizer] microphone permission request result: \(granted)")
        guard granted else {
            NSLog("[AzureSpeechRecognizer] microphone permission denied, throwing error")
            throw VoiceCore.AppError.microphonePermissionDenied
        }

        isStopping = false
        restartAttempts = 0
        try establishSession()
    }

    /// Builds (or rebuilds) the Azure recognizer + audio pipeline and starts
    /// continuous recognition. Separated from `start()` so a transient cold-start
    /// cancellation can rebuild the session in place without tearing down the
    /// event stream the coordinator is already consuming.
    private func establishSession() throws {
        let config = try configuration.validated()
        NSLog("[AzureSpeechRecognizer] configuration validated successfully")

        NSLog("[AzureSpeechRecognizer] creating SPXSpeechConfiguration...")
        let speechConfig = try SPXSpeechConfiguration(subscription: config.subscriptionKey, region: config.region)
        speechConfig.speechRecognitionLanguage = config.recognitionLanguage
        speechConfig.setPropertyTo("Time", by: SPXPropertyId.speechSegmentationStrategy)
        speechConfig.setPropertyTo("800", by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        speechConfig.setPropertyTo("20000", by: SPXPropertyId.speechSegmentationMaximumTimeMs)
        NSLog("[AzureSpeechRecognizer] SPXSpeechConfiguration created successfully")

        NSLog("[AzureSpeechRecognizer] creating ProcessedAzureAudioInputStream...")
        let processedAudioInput = try ProcessedAzureAudioInputStream(
            sharedEngine: sharedEngine,
            onVoiceActivity: { [weak self] event in
                Task {
                    await self?.continuation?.yield(.voiceActivity(event))
                }
            },
            acousticEchoCanceller: acousticEchoCanceller,
            isPlaybackActive: { [weak self] in self?.isPlaybackActive ?? false }
        )
        NSLog("[AzureSpeechRecognizer] ProcessedAzureAudioInputStream created successfully")

        let audioConfig = processedAudioInput.audioConfiguration
        NSLog("[AzureSpeechRecognizer] creating SPXSpeechRecognizer...")
        let recognizer = try SPXSpeechRecognizer(
            speechConfiguration: speechConfig,
            audioConfiguration: audioConfig
        )
        NSLog("[AzureSpeechRecognizer] SPXSpeechRecognizer created successfully")

        recognizer.addRecognizingEventHandler { [weak self] _, event in
            guard let text = event.result.text, !text.isEmpty else { return }
            NSLog("[AzureSpeechRecognizer] recognizing partial length=\(text.count)")
            Task { await self?.continuation?.yield(.partial(text)) }
        }
        recognizer.addRecognizedEventHandler { [weak self] _, event in
            guard let text = event.result.text, !text.isEmpty else { return }
            NSLog("[AzureSpeechRecognizer] recognized final length=\(text.count)")
            let audioEvidence = processedAudioInput.recentAudioEvidence()
            Task { await self?.emitFinal(text, audioEvidence: audioEvidence) }
        }
        recognizer.addCanceledEventHandler { [weak self] _, event in
            let details = try? SPXCancellationDetails(fromCanceledRecognitionResult: event.result)
            let message = details?.errorDetails ?? "Azure Speech recognition canceled."
            let code = details?.errorCode ?? .noError
            NSLog("[AzureSpeechRecognizer] canceled: \(message) code=\(code.rawValue)")
            Task { await self?.handleCancellation(message: message, code: code) }
        }
        recognizer.addSessionStartedEventHandler { [weak self] _, _ in
            NSLog("[AzureSpeechRecognizer] session started")
            Task { await self?.resetRestartAttempts() }
        }
        recognizer.addSessionStoppedEventHandler { _, _ in
            NSLog("[AzureSpeechRecognizer] session stopped")
        }

        do {
            try processedAudioInput.start()
            try recognizer.startContinuousRecognition()
            NSLog("[AzureSpeechRecognizer] continuous recognition started input=app-owned-pcm voiceProcessing=\(processedAudioInput.voiceProcessingEnabled)")
        } catch {
            processedAudioInput.stop()
            NSLog("[AzureSpeechRecognizer] failed to start: \(error.localizedDescription)")
            throw VoiceCore.AppError.speechRecognitionFailed(error.localizedDescription)
        }

        self.recognizer = recognizer
        self.processedAudioInput = processedAudioInput
        isRunning = true
    }

    /// Azure cancels the session on transient cold-start connectivity blips (most
    /// often on the very first launch, before the WebSocket is warm). Rather than
    /// surfacing those as a fatal error to the user, rebuild the session a few
    /// times. Only give up — and propagate the error — once retries are exhausted
    /// or the failure is clearly not a connectivity blip.
    private func handleCancellation(message: String, code: SPXCancellationErrorCode) {
        guard !isStopping else { return }

        if isTransientConnectionFailure(code: code, message: message),
           restartAttempts < maxRestartAttempts {
            restartAttempts += 1
            NSLog("[AzureSpeechRecognizer] transient cancellation; rebuilding session (attempt \(restartAttempts)/\(maxRestartAttempts))")
            tearDownSession()
            do {
                try establishSession()
            } catch {
                NSLog("[AzureSpeechRecognizer] session rebuild failed: \(error.localizedDescription)")
                continuation?.finish(throwing: VoiceCore.AppError.speechRecognitionCanceled(message))
            }
            return
        }

        NSLog("[AzureSpeechRecognizer] cancellation is fatal; surfacing error")
        tearDownSession()
        continuation?.finish(throwing: VoiceCore.AppError.speechRecognitionCanceled(message))
    }

    private func isTransientConnectionFailure(code: SPXCancellationErrorCode, message: String) -> Bool {
        switch code {
        case .connectionFailure, .serviceTimeout, .serviceUnavailable:
            return true
        default:
            let lowered = message.lowercased()
            return lowered.contains("connection failed")
                || lowered.contains("no connection to the service")
                || lowered.contains("timeout")
        }
    }

    private func resetRestartAttempts() {
        restartAttempts = 0
    }

    /// Tears down the recognizer + audio pipeline WITHOUT finishing the event
    /// stream, so a session can be rebuilt in place during a transient retry.
    private func tearDownSession() {
        try? recognizer?.stopContinuousRecognition()
        processedAudioInput?.stop()
        recognizer = nil
        processedAudioInput = nil
        isRunning = false
    }

    func stop() async {
        isStopping = true
        guard isRunning else {
            // Even if capture never started, the engine may have been configured
            // (or started for TTS playback). Reset it so the next call rebuilds
            // cleanly against the freshly reactivated audio session.
            sharedEngine.reset()
            continuation?.finish()
            return
        }

        tearDownSession()
        // Hangup: fully reset the shared engine. tearDownSession only removes the
        // mic tap (engine is shared with TTS), so without this the engine keeps
        // started/configured == true and the next startCall skips re-init.
        sharedEngine.reset()
        continuation?.finish()
    }

    func cancel() async {
        isStopping = true
        tearDownSession()
        sharedEngine.reset()
        continuation?.finish(throwing: CancellationError())
    }

    func pauseRecognition() async {
        guard isRunning && !isPaused else { return }
        isPaused = true
        tearDownSession()
        // Don't reset the engine or finish continuation — we're just paused, not stopping.
    }

    func resumeRecognition() async throws {
        guard isPaused else { return }
        isPaused = false
        isStopping = false
        restartAttempts = 0
        try establishSession()
    }

    private func emitFinal(_ text: String, audioEvidence: SpeechAudioEvidence?) async {
        if let audioEvidence {
            continuation?.yield(.finalWithAudioEvidence(text, audioEvidence))
        } else {
            continuation?.yield(.final(text))
        }
    }

    func notifyPlaybackStateChanged(_ isActive: Bool) async {
        isPlaybackActive = isActive
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        #if targetEnvironment(simulator)
        NSLog("[AzureSpeechRecognizer] running in simulator, bypassing microphone permission request and returning true")
        return true
        #else
        let status = AVAudioSession.sharedInstance().recordPermission
        NSLog("[AzureSpeechRecognizer] current recordPermission status: \(status.rawValue)")
        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
        #endif
    }
}
#endif
