import SwiftUI

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: AppColors.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct StatusPill: View {
    var text: String
    var detail: String? = nil
    var icon: String
    var tint: Color = AppColors.primary

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(AppTypography.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(AppTypography.label)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(AppTypography.label)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: 320)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
