import SwiftUI
import AVFoundation

@main
struct VoiceCallAssistantApp: App {
    init() {
        #if os(iOS)
        requestMicrophonePermissionIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func requestMicrophonePermissionIfNeeded() {
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
}
