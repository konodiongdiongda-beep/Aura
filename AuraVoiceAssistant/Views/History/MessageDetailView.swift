import SwiftUI
import VoiceCore

struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MessageListViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            MeshBackground()
            VStack(spacing: 0) {
                AppHeaderView(
                    title: viewModel.conversation.title,
                    subtitle: viewModel.conversation.durationText ?? "Conversation",
                    trailingIcon: "ellipsis",
                    leadingIcon: "chevron.left"
                ) {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.messages.isEmpty {
                viewModel.loadFirstPage()
            }
        }
    }
}

struct MessageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MessageDetailView(viewModel: .preview())
            .previewDisplayName("Message Detail")
    }
}
