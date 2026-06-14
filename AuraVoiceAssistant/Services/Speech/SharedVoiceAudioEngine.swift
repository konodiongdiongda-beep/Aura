#if os(iOS)
import AVFoundation
import Foundation

/// A single `AVAudioEngine` shared by microphone capture and TTS playback.
///
/// Why this exists: hardware echo cancellation (VPIO) can only subtract audio
/// that is played through the *same* engine's output. Our old design captured
/// the mic on one engine and played TTS through a separate `AVAudioPlayer`, so
/// VPIO had no far-end reference and the assistant recorded its own voice.
/// Routing both ends through one engine lets VPIO cancel the echo in hardware
/// and plays TTS back at normal loudness instead of the attenuated call path.
final class SharedVoiceAudioEngine: @unchecked Sendable {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    private let lock = NSLock()
    private var configured = false
    private var started = false
    private var configChangeObserver: NSObjectProtocol?
    private var playerConnectedFormat: AVAudioFormat?
    private(set) var voiceProcessingEnabled = false

    var inputNode: AVAudioInputNode { engine.inputNode }

    /// Attaches the player node and enables voice processing. Must run before
    /// `start()` because the player node has to be attached while the engine is
    /// stopped, and VPIO changes the input node's format.
    ///
    /// The player→mixer connection is deferred to `prepareForPlayback(format:)`:
    /// `AVAudioPlayerNode.scheduleBuffer` requires the buffer's format to match
    /// the connection format. TTS buffers are 16/24 kHz Int16, not the mixer's
    /// 48 kHz float, so connecting here with the mixer format would make the
    /// first scheduleBuffer throw an Objective-C exception → SIGABRT.
    func configure() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !configured else { return }

        // Enabling voice processing on the input node enables the shared VPIO
        // I/O unit for BOTH capture and render, so the engine cancels whatever
        // the player node emits. Calling it on the output node too can throw, so
        // we only set it on the input node.
        do {
            try engine.inputNode.setVoiceProcessingEnabled(true)
            voiceProcessingEnabled = true
        } catch {
            voiceProcessingEnabled = false
            NSLog("[SharedVoiceAudioEngine] voice processing unavailable: \(error.localizedDescription)")
        }

        engine.attach(playerNode)
        // Touch the main mixer so the output chain exists before start.
        _ = engine.mainMixerNode
        engine.prepare()
        configured = true
        observeConfigurationChanges()
    }

    /// Connects the player node to the mixer using `format` — the exact format of
    /// the TTS buffer about to be scheduled. Reconnects only when the format
    /// changes (typically once, since a voice keeps a constant sample rate).
    func prepareForPlayback(format: AVAudioFormat) {
        lock.lock()
        defer { lock.unlock() }
        guard playerConnectedFormat != format else { return }

        if playerConnectedFormat != nil {
            playerNode.stop()
            engine.disconnectNodeOutput(playerNode)
        }
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        playerConnectedFormat = format
        NSLog("[SharedVoiceAudioEngine] player connected at \(format.sampleRate)Hz ch=\(format.channelCount)")
    }

    /// A route/format change (e.g. switching the output to the speaker after VPIO
    /// has reset it to the receiver, or a Bluetooth device connecting) posts
    /// `AVAudioEngineConfigurationChange` and STOPS the engine's rendering. Apple
    /// requires the app to restart the engine afterwards. Without this, the mic
    /// tap stops receiving buffers permanently — which is exactly the "no audio
    /// input" symptom. The installed tap survives the restart, so capture resumes
    /// automatically once the engine is running again.
    private func observeConfigurationChanges() {
        guard configChangeObserver == nil else { return }
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            // Hop to a background queue so we never run the restart while a caller
            // (configure/start) still holds `lock` on the posting thread, which
            // would deadlock when the notification is delivered synchronously.
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleConfigurationChange()
            }
        }
    }

    private func handleConfigurationChange() {
        lock.lock()
        defer { lock.unlock() }
        // Only restart if we believe the engine should be running. If it already
        // is (the system may have recovered on its own), restarting is harmless.
        guard started else { return }
        if engine.isRunning {
            NSLog("[SharedVoiceAudioEngine] config change; engine still running, no restart needed")
            return
        }
        do {
            engine.prepare()
            try engine.start()
            NSLog("[SharedVoiceAudioEngine] restarted after configuration change")
        } catch {
            started = false
            NSLog("[SharedVoiceAudioEngine] restart after config change FAILED: \(error.localizedDescription)")
        }
    }

    func start() throws {
        try configure()
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        engine.prepare()
        try engine.start()
        started = true
        NSLog("[SharedVoiceAudioEngine] started voiceProcessing=\(voiceProcessingEnabled)")
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        playerNode.stop()
        engine.stop()
        started = false
        NSLog("[SharedVoiceAudioEngine] stopped")
    }

    /// Tears the engine all the way back to its pre-`configure()` state so the
    /// NEXT call reinitializes byte-for-byte like the first one did.
    ///
    /// Why this is required on hangup: `configure()` and `start()` are guarded by
    /// `configured`/`started`, and `AudioSessionManager.endCall()` deactivates the
    /// shared `AVAudioSession`. If we only stopped the engine (or didn't stop it at
    /// all), the next `startCall()` would hit those guards, skip re-enabling VPIO
    /// and restarting on the freshly reactivated session, and run on a stale engine
    /// — which is the "second call is broken" symptom. Detaching the player node and
    /// clearing every flag forces a clean rebuild.
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        if started {
            playerNode.stop()
            engine.stop()
            started = false
        }
        guard configured else { return }

        if playerConnectedFormat != nil {
            engine.disconnectNodeOutput(playerNode)
            playerConnectedFormat = nil
        }
        engine.detach(playerNode)

        configured = false
        voiceProcessingEnabled = false
        NSLog("[SharedVoiceAudioEngine] reset to pre-configure state")
    }

    var isStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    deinit {
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
        }
    }
}
#endif
