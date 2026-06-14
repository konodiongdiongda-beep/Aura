#if os(iOS)
import AVFoundation
import Foundation
import VoiceCore

actor AudioSessionManager: AudioSessionManaging {
    private let session: AVAudioSession
    private(set) var isSpeakerEnabled: Bool
    private let allowsA2DP: Bool
    private(set) var currentRoute: SpeakerRoute = .speaker
    private(set) var availableRoutes: [SpeakerRoute] = []
    private let debugShowAllRoutes: Bool

    init(
        session: AVAudioSession = .sharedInstance(),
        speakerEnabled: Bool = true,
        allowsA2DP: Bool = true,
        debugShowAllRoutes: Bool = false
    ) {
        self.session = session
        self.isSpeakerEnabled = speakerEnabled
        self.allowsA2DP = allowsA2DP
        self.currentRoute = speakerEnabled ? .speaker : .receiver
        self.debugShowAllRoutes = debugShowAllRoutes

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleRouteChange() }
        }
    }

    func startCall() async throws {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        if allowsA2DP {
            options.insert(.allowBluetoothA2DP)
        }

        // .videoChat (not .voiceChat): both enable VPIO echo cancellation, but
        // .voiceChat optimizes for a handset held to the ear and heavily
        // attenuates speaker output (sounds far too quiet on speakerphone).
        // .videoChat is tuned for hands-free / speaker output and plays back at
        // a normal, loud level while keeping echo cancellation.
        let mode: AVAudioSession.Mode = .videoChat

        try session.setCategory(.playAndRecord, mode: mode, options: options)
        if #available(iOS 18.2, *), session.isEchoCancelledInputAvailable {
            try? session.setPrefersEchoCancelledInput(true)
        }
        if #available(iOS 17.2, *) {
            try? session.setSupportsMultichannelContent(false)
        }
        try session.setActive(true, options: [])

        updateAvailableRoutes()
        print("[AudioSessionManager] startCall() - availableRoutes: \(availableRoutes.map { $0.displayName }), debugShowAllRoutes=\(debugShowAllRoutes)")
        try applyRoute(isSpeakerEnabled ? .speaker : .receiver)
    }

    /// The real hardware output port(s) the system is currently using, read
    /// straight from AVAudioSession. This is the ground truth — independent of
    /// the route WE think we set — so the UI can show what's actually happening.
    var actualOutputDescription: String {
        let outputs = session.currentRoute.outputs
        if outputs.isEmpty { return "无输出" }
        return outputs.map { output in
            switch output.portType {
            case .builtInSpeaker: return "扬声器"
            case .builtInReceiver: return "听筒"
            case .bluetoothHFP: return "蓝牙(HFP) \(output.portName)"
            case .bluetoothA2DP: return "蓝牙(A2DP) \(output.portName)"
            case .headphones: return "耳机"
            default: return output.portName
            }
        }.joined(separator: ", ")
    }

    func endCall() async {
        try? session.overrideOutputAudioPort(.none)
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func setSpeakerEnabled(_ enabled: Bool) async throws {
        isSpeakerEnabled = enabled
        try applyRoute(enabled ? .speaker : .receiver)
    }

    func setRoute(_ route: SpeakerRoute) async throws {
        try applyRoute(route)
    }

    private func applyRoute(_ route: SpeakerRoute) throws {
        switch route {
        case .speaker:
            // Force the built-in mic as input so Bluetooth doesn't pull audio
            // back to the headset, then override output to the loudspeaker.
            try preferBuiltInInput()
            try session.overrideOutputAudioPort(.speaker)

        case .receiver:
            // Earpiece: built-in mic input + no output override. With
            // .defaultToSpeaker removed, .none now genuinely routes to the
            // receiver instead of the loudspeaker.
            try preferBuiltInInput()
            try session.overrideOutputAudioPort(.none)

        case .bluetoothHFP, .bluetoothA2DP:
            // Bluetooth input/output are coupled: selecting the Bluetooth
            // input port is what actually moves playback onto the headset.
            try session.overrideOutputAudioPort(.none)
            try preferBluetoothInput()
        }

        print("[AudioSessionManager] applyRoute(\(route.displayName)) - outputs: \(session.currentRoute.outputs.map { $0.portName })")

        currentRoute = route
        isSpeakerEnabled = (route == .speaker)
    }

    private func preferBuiltInInput() throws {
        guard let inputs = session.availableInputs else { return }
        if let builtIn = inputs.first(where: { $0.portType == .builtInMic }) {
            NSLog("[AUDIO-ROUTE] setPreferredInput(builtInMic) - was input=\(session.currentRoute.inputs.map { $0.portName })")
            try session.setPreferredInput(builtIn)
        }
    }

    private func preferBluetoothInput() throws {
        guard let inputs = session.availableInputs else { return }
        let bluetooth = inputs.first { input in
            input.portType == .bluetoothHFP || input.portType == .bluetoothLE
        }
        if let bluetooth {
            try session.setPreferredInput(bluetooth)
        }
    }

    private func updateAvailableRoutes() {
        var routes: [SpeakerRoute] = [.speaker, .receiver]

        if debugShowAllRoutes {
            routes.append(.bluetoothHFP)
            if allowsA2DP {
                routes.append(.bluetoothA2DP)
            }
        } else {
            let currentOutputs = session.currentRoute.outputs
            let bluetoothOutputs = currentOutputs.filter { output in
                output.portType == .bluetoothHFP || output.portType == .bluetoothA2DP
            }

            for output in bluetoothOutputs {
                if output.portType == .bluetoothHFP {
                    routes.append(.bluetoothHFP)
                } else if output.portType == .bluetoothA2DP && allowsA2DP {
                    routes.append(.bluetoothA2DP)
                }
            }
        }

        availableRoutes = routes
    }

    private func handleRouteChange() {
        updateAvailableRoutes()
        let currentOutputs = session.currentRoute.outputs
        let hasBluetoothDevice = currentOutputs.contains { output in
            output.portType == .bluetoothHFP || output.portType == .bluetoothA2DP
        }

        if !hasBluetoothDevice && (currentRoute == .bluetoothHFP || currentRoute == .bluetoothA2DP) {
            do {
                try applyRoute(.receiver)
            } catch {
                print("[AudioSessionManager] Failed to fallback to receiver: \(error)")
            }
        }
    }
}
#endif
