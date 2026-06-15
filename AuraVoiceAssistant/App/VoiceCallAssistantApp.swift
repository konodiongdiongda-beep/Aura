import SwiftUI
import AVFoundation

@main
struct VoiceCallAssistantApp: App {
    @State private var appReady = false

    var body: some Scene {
        WindowGroup {
            if appReady {
                ContentView()
            } else {
                Color.clear
                    .onAppear {
                        requestMicrophonePermissionIfNeeded()
                        appReady = true
                    }
            }
        }
    }

    private func requestMicrophonePermissionIfNeeded() {
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                NSLog("[VoiceCallAssistantApp] Microphone permission: \(granted)")
            }
        }
    }
}
