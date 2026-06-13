import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        let text = viewModel.text
        VStack(spacing: 0) {
            AppHeaderView(title: text.settingsTitle, subtitle: text.configurationSubtitle, trailingIcon: "gearshape.fill")

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    SettingsCard(
                        title: text.languageTitle,
                        subtitle: text.languageSubtitle,
                        icon: "globe.asia.australia.fill",
                        tint: AppColors.primary
                    ) {
                        LanguageSegmentedControl(
                            selection: viewModel.language,
                            onSelect: viewModel.setLanguage
                        )
                    }

                    SettingsCard(
                        title: text.azureSpeechTitle,
                        subtitle: viewModel.azureStatusText,
                        icon: "waveform.badge.mic",
                        tint: viewModel.speechServiceModeText == "Azure" ? AppColors.success : AppColors.error
                    ) {
                        SettingsRow(label: text.azureKeyLabel, value: viewModel.azureKeyPresenceText)
                        SettingsRow(label: text.regionLabel, value: viewModel.azureRegionText)
                        SettingsRow(label: text.voiceLabel, value: viewModel.preferredVoiceText)
                        SettingsRow(label: text.speechModeLabel, value: viewModel.speechServiceModeText)
                        SettingsRow(label: text.environmentLabel, value: viewModel.speechRuntimeEnvironmentText)
                        SettingsRow(label: text.statusLabel, value: viewModel.speechStatusText)
                    }

                    SettingsCard(
                        title: text.userTitle,
                        subtitle: viewModel.userDisplayText,
                        icon: "person.crop.circle.fill",
                        tint: AppColors.primary
                    ) {
                        SettingsRow(label: text.historyIdentityLabel, value: text.qaUser)
                    }

                    SettingsCard(
                        title: text.speakerEnrollmentTitle,
                        subtitle: viewModel.speakerEnrollmentStatusText,
                        icon: "person.wave.2.fill",
                        tint: AppColors.secondary
                    ) {
                        SettingsRow(label: text.stateLabel, value: text.phase1Placeholder)
                        SettingsRow(label: text.verificationLabel, value: text.notConnected)
                    }

                    SettingsCard(
                        title: text.microphoneTitle,
                        subtitle: viewModel.microphoneStatusText,
                        icon: "mic.circle.fill",
                        tint: AppColors.tertiary
                    ) {
                        SettingsRow(label: text.permissionLabel, value: text.microphoneRequestedByPhase3)
                    }
                }
                .padding(AppSpacing.screenMargin)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }
}

struct LanguageSegmentedControl: View {
    var selection: AppLanguage
    var onSelect: (AppLanguage) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        onSelect(language)
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Text(language.shortTitle)
                            .font(AppTypography.label)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(selection == language ? .white : AppColors.primary)
                            .background(selection == language ? AppColors.primary : AppColors.primaryFixed.opacity(0.8), in: Circle())
                        Text(language.title)
                            .font(AppTypography.bodySmall.weight(.semibold))
                            .foregroundStyle(selection == language ? AppColors.onSurface : AppColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.sm)
                    .background(selection == language ? .white.opacity(0.72) : AppColors.surfaceContainerLow.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selection == language ? AppColors.primary.opacity(0.22) : .white.opacity(0.45), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.title)
            }
        }
        .padding(AppSpacing.xs)
        .background(AppColors.surfaceContainerLow.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SettingsCard<Content: View>: View {
    var title: String
    var subtitle: String
    var icon: String
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppTypography.headlineMobile)
                            .foregroundStyle(AppColors.onSurface)
                        Text(subtitle)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(tint)
                    }
                    Spacer()
                }
                content
            }
        }
    }
}

struct SettingsRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall.weight(.semibold))
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewScaffold {
            SettingsView(viewModel: SettingsViewModel())
        }
        .previewDisplayName("Settings")
    }
}
