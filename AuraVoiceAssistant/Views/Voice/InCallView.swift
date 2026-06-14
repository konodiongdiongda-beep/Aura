import SwiftUI
import VoiceCore

struct InCallView: View {
    @ObservedObject var viewModel: VoiceCallViewModel
    var text: AppText
    @Environment(\.appTopSafeAreaInset) private var topSafeAreaInset
    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 650
            let topPadding = Self.topContentPadding(topSafeAreaInset: topSafeAreaInset, compact: compact)
            let transcriptHeight = Self.transcriptHeight(
                for: proxy.size.height,
                topPadding: topPadding,
                compact: compact
            )

            VStack(spacing: compact ? AppSpacing.md : AppSpacing.lg) {
                VStack(spacing: compact ? AppSpacing.sm : AppSpacing.md) {
                    Text(viewModel.formattedElapsedTime)
                        .font(AppTypography.headlineXL.monospacedDigit())
                        .foregroundStyle(AppColors.primary)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -8)

                    VoiceWaveView(state: viewModel.state, audioLevel: viewModel.audioLevel, compact: compact)
                        .frame(maxWidth: 220)
                        .scaleEffect(hasAppeared ? 1 : 0.72)
                        .opacity(hasAppeared ? 1 : 0)

                    StatusPill(
                        text: viewModel.localizedStatusTitle(text),
                        detail: viewModel.localizedStatusDetail(text),
                        icon: statusIcon,
                        tint: statusTint
                    )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.top, topPadding)

                TranscriptPanel(viewModel: viewModel, text: text, maxHeight: transcriptHeight)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 24)

                Spacer(minLength: 0)

                Text("实际输出: \(viewModel.actualOutputDescription)")
                    .font(AppTypography.label)
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .opacity(hasAppeared ? 1 : 0)

                Text(viewModel.audioDiagnostic.isEmpty ? "诊断: —" : viewModel.audioDiagnostic)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .padding(.bottom, AppSpacing.xs)
                    .opacity(hasAppeared ? 1 : 0)

                InCallControls(viewModel: viewModel, text: text, compact: compact)
                    .padding(.bottom, compact ? AppSpacing.xs : AppSpacing.sm)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 28)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.06)) {
                hasAppeared = true
            }
        }
    }

    static func topContentPadding(topSafeAreaInset: CGFloat, compact: Bool) -> CGFloat {
        topSafeAreaInset + (compact ? AppSpacing.md : AppSpacing.lg)
    }

    static func transcriptHeight(for availableHeight: CGFloat, topPadding: CGFloat = AppSpacing.lg, compact: Bool) -> CGFloat {
        let reservedHeight: CGFloat = compact ? 190 : 232
        let baseTopPadding = compact ? AppSpacing.md : AppSpacing.lg
        let flexibleHeight = availableHeight - reservedHeight - max(0, topPadding - baseTopPadding)
        return max(compact ? 220 : 280, min(560, flexibleHeight))
    }

    private var statusIcon: String {
        switch viewModel.state {
        case .speaking:
            return "speaker.wave.2.fill"
        case .thinking:
            return "sparkles"
        case .interrupted:
            return "bolt.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "waveform"
        }
    }

    private var statusTint: Color {
        switch viewModel.state {
        case .error, .interrupted:
            return AppColors.error
        case .speaking:
            return AppColors.secondary
        default:
            return AppColors.primary
        }
    }
}

struct TranscriptPanel: View {
    @ObservedObject var viewModel: VoiceCallViewModel
    var text: AppText = .localized(.english)
    var maxHeight: CGFloat = 240
    private let bottomAnchorID = "transcript-bottom-anchor"

    var body: some View {
        GlassPanel(cornerRadius: 24, padding: AppSpacing.lg) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, text: text)
                        }

                        if viewModel.state == .thinking && viewModel.activeAssistantText.isEmpty {
                            ThinkingBubble()
                        }

                        if !viewModel.activeUserPartialText.isEmpty {
                            ActiveLine(label: text.youLabel, text: viewModel.activeUserPartialText, tint: AppColors.onSurfaceVariant)
                        }

                        if !viewModel.activeAssistantText.isEmpty {
                            ActiveLine(label: "Aura", text: viewModel.activeAssistantText, tint: AppColors.primary)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: maxHeight)
                .onAppear {
                    scrollToLatest(proxy, animated: false)
                }
                .onChange(of: latestTranscriptSignature) { _ in
                    scrollToLatest(proxy, animated: true)
                }
            }
        }
    }

    private var latestTranscriptSignature: String {
        [
            viewModel.messages.last?.id ?? "",
            viewModel.messages.last?.displayText ?? "",
            viewModel.activeUserPartialText,
            viewModel.activeAssistantText
        ].joined(separator: "|")
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                action()
            }
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
}

struct MessageBubble: View {
    var message: ChatMessage
    var text: AppText = .localized(.english)

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 44)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(roleLabel)
                    .font(AppTypography.label)
                    .foregroundStyle(roleTint.opacity(0.72))
                if message.role == .assistant {
                    if message.deliveryState == .streaming {
                        TypewriterText(text: message.displayText)
                    } else {
                        Text(message.displayText)
                            .font(AppTypography.aiResponse)
                            .foregroundStyle(AppColors.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(message.displayText)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppSpacing.md)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if message.role != .user {
                Spacer(minLength: 44)
            }
        }
    }

    private var roleTint: Color {
        message.role == .assistant ? AppColors.primary : AppColors.onSurfaceVariant
    }

    private var roleLabel: String {
        switch message.role {
        case .assistant:
            return "Aura"
        case .user:
            return text.youLabel
        case .system:
            return text.systemLabel
        }
    }

    private var background: Color {
        switch message.role {
        case .assistant:
            return .white.opacity(0.78)
        case .user:
            return AppColors.primaryFixed.opacity(0.8)
        case .system:
            return AppColors.surfaceContainerHigh.opacity(0.72)
        }
    }
}

struct ActiveLine: View {
    var label: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text("\(label):")
                .font(AppTypography.label)
                .foregroundStyle(tint.opacity(0.7))
            if label == "Aura" {
                TypewriterText(text: text)
            } else {
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(tint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.sm)
    }
}

struct InCallControls: View {
    @ObservedObject var viewModel: VoiceCallViewModel
    var text: AppText
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? AppSpacing.lg : AppSpacing.xl) {
            ControlButton(
                icon: viewModel.isMuted ? "mic.fill" : "mic.slash.fill",
                label: viewModel.isMuted ? text.unmute : text.mute,
                tint: viewModel.isMuted ? AppColors.primary : AppColors.onSurface
            ) {
                viewModel.toggleMute()
            }

            Button {
                viewModel.endCall()
            } label: {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: compact ? 64 : 76, height: compact ? 64 : 76)
                        .foregroundStyle(.white)
                        .background(AppColors.error, in: Circle())
                        .shadow(color: AppColors.error.opacity(0.28), radius: 16, x: 0, y: 10)
                    Text(text.end)
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.error)
                }
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(viewModel.availableSpeakerRoutes, id: \.self) { route in
                    Button(action: {
                        viewModel.setSpeakerRoute(route)
                    }) {
                        HStack {
                            Text(route.displayName)
                            if viewModel.currentSpeakerRoute == route {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: compact ? 52 : 58, height: compact ? 52 : 58)
                        .foregroundStyle(AppColors.primary)
                        .background(.white.opacity(0.66), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.58), lineWidth: 1))
                    Text(text.speaker)
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.outline)
                }
            }
        }
    }
}

struct ControlButton: View {
    var icon: String
    var label: String
    var tint: Color
    var size: CGFloat = 58
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: size, height: size)
                    .foregroundStyle(tint)
                    .background(.white.opacity(0.66), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.58), lineWidth: 1))
                Text(label)
                    .font(AppTypography.label)
                    .foregroundStyle(AppColors.outline)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TypewriterText: View {
    let text: String
    var speed: Double = 0.015
    @State private var displayedText: String = ""
    @State private var animationTask: Task<Void, Never>? = nil

    var body: some View {
        Text(displayedText)
            .font(AppTypography.aiResponse)
            .foregroundStyle(AppColors.primary)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                startTypewriter(to: text)
            }
            .onChange(of: text) { newValue in
                startTypewriter(to: newValue)
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }

    private func startTypewriter(to targetText: String) {
        animationTask?.cancel()
        
        guard !targetText.isEmpty else {
            displayedText = ""
            return
        }

        if targetText.hasPrefix(displayedText) {
            let startCount = displayedText.count
            let charactersToType = Array(targetText.dropFirst(startCount))
            
            animationTask = Task {
                for char in charactersToType {
                    if Task.isCancelled { break }
                    displayedText.append(char)
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
            }
        } else {
            displayedText = ""
            let charactersToType = Array(targetText)
            
            animationTask = Task {
                for char in charactersToType {
                    if Task.isCancelled { break }
                    displayedText.append(char)
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
            }
        }
    }
}

struct ThinkingBubble: View {
    @State private var dotOffset1: CGFloat = 0
    @State private var dotOffset2: CGFloat = 0
    @State private var dotOffset3: CGFloat = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Aura")
                    .font(AppTypography.label)
                    .foregroundStyle(AppColors.primary.opacity(0.72))
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffset1)
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffset2)
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffset3)
                }
                .frame(width: 44, height: 16)
                .onAppear {
                    animateDots()
                }
            }
            .padding(AppSpacing.md)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 44)
        }
    }

    private func animateDots() {
        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0)) {
            dotOffset1 = -6
        }
        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.15)) {
            dotOffset2 = -6
        }
        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.3)) {
            dotOffset3 = -6
        }
    }
}
