import SwiftUI

struct VoiceRootView: View {
    @ObservedObject var viewModel: VoiceCallViewModel
    var text: AppText

    var body: some View {
        VStack(spacing: 0) {
            if Self.shouldShowTopHeader(for: viewModel) {
                AppHeaderView(subtitle: "Online")
                    .transition(.opacity.combined(with: .offset(y: -18)))
            }

            ZStack {
                if viewModel.shouldShowCallScreen {
                    InCallView(viewModel: viewModel, text: text)
                        .transition(.callEntry)
                        .zIndex(1)
                } else {
                    VoiceHomeView(viewModel: viewModel, text: text)
                        .transition(.homeExit)
                        .zIndex(0)
                }
            }
            .animation(.smoothCallTransition, value: viewModel.shouldShowCallScreen)
        }
    }

    static func shouldShowTopHeader(for viewModel: VoiceCallViewModel) -> Bool {
        !viewModel.shouldShowCallScreen
    }
}

private extension Animation {
    static let smoothCallTransition = Animation.spring(response: 0.58, dampingFraction: 0.86, blendDuration: 0.18)
}

private extension AnyTransition {
    static let callEntry = AnyTransition.asymmetric(
        insertion: .opacity
            .combined(with: .scale(scale: 0.88, anchor: .center))
            .combined(with: .offset(y: 34)),
        removal: .opacity
            .combined(with: .scale(scale: 1.03, anchor: .center))
            .combined(with: .offset(y: -18))
    )

    static let homeExit = AnyTransition.asymmetric(
        insertion: .opacity
            .combined(with: .scale(scale: 0.96, anchor: .center))
            .combined(with: .offset(y: -18)),
        removal: .opacity
            .combined(with: .scale(scale: 0.82, anchor: .center))
            .combined(with: .offset(y: -46))
    )
}

struct VoiceRootView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.idle), text: .localized(.english))
        }
            .previewDisplayName("Idle")

        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.listening), text: .localized(.english))
        }
            .previewDisplayName("Listening")

        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.thinking), text: .localized(.english))
        }
            .previewDisplayName("Thinking")

        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.speaking), text: .localized(.english))
        }
            .previewDisplayName("Speaking")

        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.interrupted), text: .localized(.english))
        }
            .previewDisplayName("Interrupted")

        PreviewScaffold {
            VoiceRootView(viewModel: .preview(.error(.missingAzureSpeechConfig)), text: .localized(.english))
        }
            .previewDisplayName("Error")
        }
    }
}
