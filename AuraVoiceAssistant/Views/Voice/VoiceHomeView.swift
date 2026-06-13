import SwiftUI
import VoiceCore

struct VoiceHomeView: View {
    @ObservedObject var viewModel: VoiceCallViewModel
    var text: AppText
    @State private var isPrimed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 42) {
                Spacer(minLength: 36)

                VoiceOrbView(state: viewModel.state)
                    .scaleEffect(isPrimed ? 1 : 0.94)
                    .opacity(isPrimed ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.78), value: isPrimed)

                VStack(spacing: AppSpacing.sm) {
                    Text(viewModel.localizedStatusTitle(text))
                        .font(AppTypography.headlineLG)
                        .foregroundStyle(AppColors.onSurface)
                    Text(viewModel.localizedStatusDetail(text))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                Button {
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.86, blendDuration: 0.18)) {
                        viewModel.startCall()
                    }
                } label: {
                    Label(text.startCall, systemImage: "phone.fill")
                        .font(AppTypography.headlineMobile)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.lg)
                        .background(AppColors.primary, in: Capsule())
                        .shadow(color: AppColors.primary.opacity(0.26), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 12)
            }
            .padding(AppSpacing.screenMargin)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            isPrimed = true
        }
    }
}

struct VoiceOrbView: View {
    var state: VoiceCallState

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(AppColors.primary.opacity(0.14 - Double(index) * 0.035), lineWidth: 5)
                    .frame(width: 210 + CGFloat(index * 40), height: 210 + CGFloat(index * 40))
            }

            Circle()
                .fill(.white.opacity(0.68))
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 194, height: 194)
                .shadow(color: AppColors.primary.opacity(0.22), radius: 32, x: 0, y: 18)

            Circle()
                .fill(LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 154, height: 154)

            Image(systemName: Self.symbolName(for: state))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 292, height: 292)
    }

    static func symbolName(for state: VoiceCallState) -> String {
        state.isActiveCall ? "waveform" : "phone.fill"
    }
}
