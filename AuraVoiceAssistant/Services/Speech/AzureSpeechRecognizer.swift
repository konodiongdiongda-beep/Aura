#if os(iOS) && canImport(MicrosoftCognitiveServicesSpeech)
import AVFoundation
import Foundation
import MicrosoftCognitiveServicesSpeech
import VoiceCore

actor AzureSpeechRecognizer: SpeechRecognizing {
    private let configuration: AzureSpeechConfiguration
    private let acousticEchoCanceller: (any AcousticEchoCancelling)?
    private var recognizer: SPXSpeechRecognizer?
    private var processedAudioInput: ProcessedAzureAudioInputStream?
    private var continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation?
    private var isRunning = false
    /// Written by the Coordinator on MainActor; read synchronously from the audio tap closure.
    nonisolated(unsafe) var isPlaybackActive = false

    init(
        configuration: AzureSpeechConfiguration,
        acousticEchoCanceller: (any AcousticEchoCancelling)? = nil
    ) {
        self.configuration = configuration
        self.acousticEchoCanceller = acousticEchoCanceller
    }

    func events() async -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func start() async throws {
        NSLog("[AzureSpeechRecognizer] start() called")
        let config = try configuration.validated()
        NSLog("[AzureSpeechRecognizer] configuration validated successfully")
        
        NSLog("[AzureSpeechRecognizer] requesting microphone permission...")
        let granted = await requestMicrophonePermissionIfNeeded()
        NSLog("[AzureSpeechRecognizer] microphone permission request result: \(granted)")
        guard granted else { 
            NSLog("[AzureSpeechRecognizer] microphone permission denied, throwing error")
            throw VoiceCore.AppError.microphonePermissionDenied 
        }

        NSLog("[AzureSpeechRecognizer] creating SPXSpeechConfiguration...")
        let speechConfig = try SPXSpeechConfiguration(subscription: config.subscriptionKey, region: config.region)
        speechConfig.speechRecognitionLanguage = config.recognitionLanguage
        speechConfig.setPropertyTo("Time", by: SPXPropertyId.speechSegmentationStrategy)
        speechConfig.setPropertyTo("800", by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        speechConfig.setPropertyTo("20000", by: SPXPropertyId.speechSegmentationMaximumTimeMs)
        NSLog("[AzureSpeechRecognizer] SPXSpeechConfiguration created successfully")

        NSLog("[AzureSpeechRecognizer] creating ProcessedAzureAudioInputStream...")
        let processedAudioInput = try ProcessedAzureAudioInputStream(
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
            NSLog("[AzureSpeechRecognizer] canceled: \(message)")
            Task {
                await self?.continuation?.finish(throwing: VoiceCore.AppError.speechRecognitionCanceled(message))
            }
        }
        recognizer.addSessionStartedEventHandler { _, _ in
            NSLog("[AzureSpeechRecognizer] session started")
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

    func stop() async {
        guard isRunning else {
            continuation?.finish()
            return
        }

        try? recognizer?.stopContinuousRecognition()
        processedAudioInput?.stop()
        isRunning = false
        recognizer = nil
        processedAudioInput = nil
        continuation?.finish()
    }

    func cancel() async {
        try? recognizer?.stopContinuousRecognition()
        processedAudioInput?.stop()
        isRunning = false
        recognizer = nil
        processedAudioInput = nil
        continuation?.finish(throwing: CancellationError())
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
