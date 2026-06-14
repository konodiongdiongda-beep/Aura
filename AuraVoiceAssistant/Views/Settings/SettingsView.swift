import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        let text = viewModel.text
        VStack(spacing: 0) {
            AppHeaderView(title: text.settingsTitle, subtitle: text.configurationSubtitle, trailingIcon: "gearshape.fill")

            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // MARK: – User Profile Card
                    UserProfileCard(
                        username: viewModel.config.defaultUsername,
                        userID: viewModel.config.defaultUserID,
                        userLabel: text.userTitle,
                        idLabel: "ID"
                    )

                    // MARK: – Language Switcher Card
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

                    // MARK: – App Info Card
                    AppInfoCard(
                        versionLabel: text.settingsVersionLabel,
                        version: "1.0.0",
                        buildLabel: text.settingsBuildLabel,
                        build: "2026.06"
                    )
                }
                .padding(AppSpacing.screenMargin)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }
}

// MARK: – User Profile Card

struct UserProfileCard: View {
    var username: String
    var userID: Int
    var userLabel: String
    var idLabel: String

    @State private var avatarPulse: Bool = false

    var body: some View {
        GlassPanel(cornerRadius: 26, padding: 0) {
            VStack(spacing: 0) {
                // Top gradient accent bar
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondaryContainer, AppColors.primary.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 72)
                .overlay(alignment: .bottomLeading) {
                    // Decorative floating circles
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .offset(x: 28, y: 14)
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                        .offset(x: 110, y: -12)
                }
                .clipShape(TopRoundedRectangle(radius: 26))

                // Avatar + Info overlay
                VStack(spacing: AppSpacing.md) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondaryContainer],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: AppColors.primary.opacity(0.32), radius: 16, x: 0, y: 8)
                            .scaleEffect(avatarPulse ? 1.04 : 1.0)

                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .offset(y: -36)
                    .padding(.bottom, -28)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            avatarPulse = true
                        }
                    }

                    // Username
                    Text(username)
                        .font(AppTypography.headlineLG)
                        .foregroundStyle(AppColors.onSurface)

                    // User ID badge
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                        Text("\(idLabel) \(userID)")
                            .font(AppTypography.label)
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryFixed.opacity(0.55), in: Capsule())

                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 8, height: 8)
                        Text(userLabel)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.outline)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }
}

// MARK: – App Info Card

struct AppInfoCard: View {
    var versionLabel: String
    var version: String
    var buildLabel: String
    var build: String

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondaryContainer],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aura Voice")
                            .font(AppTypography.headlineMobile)
                            .foregroundStyle(AppColors.onSurface)
                        Text("AI Assistant")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.outline)
                    }
                    Spacer()
                }

                Divider()
                    .overlay(AppColors.surfaceContainerHigh)

                SettingsRow(label: versionLabel, value: version)
                SettingsRow(label: buildLabel, value: build)
            }
        }
    }
}

// MARK: – Language Segmented Control

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

// MARK: – Settings Card

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

// MARK: – Settings Row

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

// MARK: – Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewScaffold {
            SettingsView(viewModel: SettingsViewModel())
        }
        .previewDisplayName("Settings")
    }
}
