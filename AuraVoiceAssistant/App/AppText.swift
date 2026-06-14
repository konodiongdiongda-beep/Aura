import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Equatable {
    case english
    case chinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    var shortTitle: String {
        switch self {
        case .english:
            return "EN"
        case .chinese:
            return "中"
        }
    }
}

struct AppText: Equatable {
    let settingsTitle: String
    let configurationSubtitle: String
    let languageTitle: String
    let languageSubtitle: String
    let azureSpeechTitle: String
    let azureConfigured: String
    let azureMissing: String
    let azureKeyLabel: String
    let present: String
    let missing: String
    let regionLabel: String
    let notSet: String
    let voiceLabel: String
    let speechModeLabel: String
    let environmentLabel: String
    let statusLabel: String
    let userTitle: String
    let historyIdentityLabel: String
    let qaUser: String
    let speakerEnrollmentTitle: String
    let placeholder: String
    let stateLabel: String
    let phase1Placeholder: String
    let verificationLabel: String
    let notConnected: String
    let microphoneTitle: String
    let microphoneNotRequested: String
    let permissionLabel: String
    let microphoneRequestedByPhase3: String
    let settingsVersionLabel: String
    let settingsBuildLabel: String
    let historyTab: String
    let voiceTab: String
    let settingsTab: String
    let voiceIdleTitle: String
    let voiceIdleDetail: String
    let startCall: String
    let auraListening: String
    let microphoneMuted: String
    let checkingMicrophone: String
    let capturingThought: String
    let auraThinking: String
    let auraSpeaking: String
    let interruptionCaptured: String
    let callEnded: String
    let needsAttention: String
    let speakNaturally: String
    let microphoneAccessNotice: String
    let streamingPlaceholder: String
    let slowResponsePlaceholder: String
    let interruptNotice: String
    let staleAudioNotice: String
    let unmuteNotice: String
    let endedNotice: String
    let youLabel: String
    let systemLabel: String
    let mute: String
    let unmute: String
    let end: String
    let speaker: String
    let interrupt: String

    static func localized(_ language: AppLanguage) -> AppText {
        switch language {
        case .english:
            return AppText(
                settingsTitle: "Settings",
                configurationSubtitle: "Configuration",
                languageTitle: "Language",
                languageSubtitle: "Interface language",
                azureSpeechTitle: "Azure Speech",
                azureConfigured: "Configured",
                azureMissing: "Missing key or region",
                azureKeyLabel: "Key",
                present: "Present",
                missing: "Missing",
                regionLabel: "Region",
                notSet: "Not set",
                voiceLabel: "Voice",
                speechModeLabel: "Speech mode",
                environmentLabel: "Environment",
                statusLabel: "Status",
                userTitle: "User",
                historyIdentityLabel: "History identity",
                qaUser: "QA user",
                speakerEnrollmentTitle: "Speaker Enrollment",
                placeholder: "Placeholder",
                stateLabel: "State",
                phase1Placeholder: "Not enrolled",
                verificationLabel: "Verification",
                notConnected: "Not connected",
                microphoneTitle: "Microphone",
                microphoneNotRequested: "Requested during calls",
                permissionLabel: "Permission",
                microphoneRequestedByPhase3: "Requested by Phase 3 audio layer",
                settingsVersionLabel: "Version",
                settingsBuildLabel: "Build",
                historyTab: "History",
                voiceTab: "Voice",
                settingsTab: "Settings",
                voiceIdleTitle: "Hello, I'm Aura",
                voiceIdleDetail: "Tap to start a voice conversation with live transcript.",
                startCall: "Start Call",
                auraListening: "Aura is listening",
                microphoneMuted: "Microphone muted",
                checkingMicrophone: "Checking microphone",
                capturingThought: "Capturing your thought",
                auraThinking: "Aura is thinking",
                auraSpeaking: "Aura is speaking",
                interruptionCaptured: "Interruption captured",
                callEnded: "Call ended",
                needsAttention: "Needs attention",
                speakNaturally: "Speak naturally. Your words will appear in the transcript.",
                microphoneAccessNotice: "The app uses microphone access during voice calls.",
                streamingPlaceholder: "Preparing an answer.",
                slowResponsePlaceholder: "Still waiting for Aura's response.",
                interruptNotice: "You can interrupt while Aura is speaking.",
                staleAudioNotice: "Previous assistant audio is treated as stale in the UI.",
                unmuteNotice: "Unmute to resume speech capture.",
                endedNotice: "Review the transcript or start another call.",
                youLabel: "You",
                systemLabel: "System",
                mute: "Mute",
                unmute: "Unmute",
                end: "End",
                speaker: "Speaker",
                interrupt: "Interrupt"
            )
        case .chinese:
            return AppText(
                settingsTitle: "设置",
                configurationSubtitle: "配置",
                languageTitle: "语言",
                languageSubtitle: "界面语言",
                azureSpeechTitle: "Azure 语音",
                azureConfigured: "已配置",
                azureMissing: "缺少密钥或区域",
                azureKeyLabel: "密钥",
                present: "已提供",
                missing: "缺失",
                regionLabel: "区域",
                notSet: "未设置",
                voiceLabel: "语音",
                speechModeLabel: "语音模式",
                environmentLabel: "运行环境",
                statusLabel: "状态",
                userTitle: "用户",
                historyIdentityLabel: "历史身份",
                qaUser: "QA 用户",
                speakerEnrollmentTitle: "声纹录入",
                placeholder: "占位",
                stateLabel: "状态",
                phase1Placeholder: "未录入",
                verificationLabel: "验证",
                notConnected: "未连接",
                microphoneTitle: "麦克风",
                microphoneNotRequested: "通话中请求",
                permissionLabel: "权限",
                microphoneRequestedByPhase3: "由 Phase 3 音频层请求",
                settingsVersionLabel: "版本",
                settingsBuildLabel: "构建",
                historyTab: "历史",
                voiceTab: "语音",
                settingsTab: "设置",
                voiceIdleTitle: "你好，我是 Aura",
                voiceIdleDetail: "点击开始语音对话，并查看实时转写。",
                startCall: "开始通话",
                auraListening: "Aura 正在聆听",
                microphoneMuted: "麦克风已静音",
                checkingMicrophone: "正在检查麦克风",
                capturingThought: "正在捕捉你的想法",
                auraThinking: "Aura 正在思考",
                auraSpeaking: "Aura 正在说话",
                interruptionCaptured: "已捕捉打断",
                callEnded: "通话已结束",
                needsAttention: "需要处理",
                speakNaturally: "自然说话即可，你的话会显示在转写中。",
                microphoneAccessNotice: "App 会在语音通话中使用麦克风权限。",
                streamingPlaceholder: "正在准备回复。",
                slowResponsePlaceholder: "仍在等待 Aura 回复。",
                interruptNotice: "Aura 说话时也可以打断。",
                staleAudioNotice: "被打断的助手音频会在 UI 中标记为过期。",
                unmuteNotice: "取消静音以继续语音捕捉。",
                endedNotice: "查看转写或开始新的通话。",
                youLabel: "你",
                systemLabel: "系统",
                mute: "静音",
                unmute: "取消静音",
                end: "挂断",
                speaker: "扬声器",
                interrupt: "打断"
            )
        }
    }
}
