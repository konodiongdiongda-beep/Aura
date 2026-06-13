import SwiftUI

struct AppHeaderView: View {
    @Environment(\.appTopSafeAreaInset) private var topSafeAreaInset

    var title: String = "Aura AI"
    var subtitle: String = "Online"
    var trailingIcon: String = "gearshape"
    var showsPulse: Bool = true
    var leadingIcon: String?
    var leadingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            leadingView

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.headlineMobile)
                    .foregroundStyle(AppColors.onSurface)
                HStack(spacing: 6) {
                    Circle()
                        .fill(showsPulse ? AppColors.success : AppColors.outline)
                        .frame(width: 8, height: 8)
                    Text(subtitle)
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.outline)
                }
            }

            Spacer()

            Image(systemName: trailingIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.onSurfaceVariant)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.56), in: Circle())
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.top, topSafeAreaInset + AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(.white.opacity(0.62))
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(height: 1)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder
    private var leadingView: some View {
        if let leadingIcon, let leadingAction {
            Button(action: leadingAction) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppColors.primary, AppColors.secondaryContainer],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .shadow(color: AppColors.primary.opacity(0.28), radius: 14, x: 0, y: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct AppTopSafeAreaInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var appTopSafeAreaInset: CGFloat {
        get { self[AppTopSafeAreaInsetKey.self] }
        set { self[AppTopSafeAreaInsetKey.self] = newValue }
    }
}
