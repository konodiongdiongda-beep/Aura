import SwiftUI
import VoiceCore

struct HistoryListView: View {
    @ObservedObject var viewModel: HistoryListViewModel
    var onSelectConversation: ((Conversation) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(title: "History", subtitle: "Local records", trailingIcon: "line.3.horizontal.decrease.circle")

            VStack(spacing: AppSpacing.md) {
                SearchField(text: $viewModel.searchText)

                HStack {
                    Text("Recent Calls")
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.outline)
                    Spacer()
                    Text("\(viewModel.filteredConversations.count)")
                        .font(AppTypography.label)
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.horizontal, 4)

                if let errorMessage = viewModel.errorMessage {
                    GlassPanel {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.error)
                    }
                } else if viewModel.isLoading {
                    GlassPanel {
                        Label("Loading local history", systemImage: "clock")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                } else if viewModel.filteredConversations.isEmpty {
                    GlassPanel {
                        Label("No local conversations yet", systemImage: "text.bubble")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.onSurfaceVariant)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.filteredConversations) { conversation in
                                Button {
                                    Self.select(conversation, onSelectConversation: onSelectConversation)
                                } label: {
                                    HistoryRow(conversation: conversation)
                                }
                                .buttonStyle(.plain)
                                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .padding(AppSpacing.screenMargin)
        }
        .onAppear {
            if viewModel.conversations.isEmpty && viewModel.errorMessage == nil {
                viewModel.loadFirstPage()
            }
        }
    }

    static func select(
        _ conversation: Conversation,
        onSelectConversation: ((Conversation) -> Void)?
    ) {
        onSelectConversation?(conversation)
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.outline)
            TextField("Search through conversations", text: $text)
                .font(AppTypography.bodySmall)
                .textInputAutocapitalization(.never)
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(AppColors.outline)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(.white.opacity(0.66), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
    }
}

struct HistoryRow: View {
    var conversation: Conversation

    var body: some View {
        GlassPanel(cornerRadius: 20, padding: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Circle()
                    .fill(AppColors.primaryFixed)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(AppColors.primary)
                    }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(conversation.updatedAt.relativeHistoryText)
                            .font(AppTypography.label)
                            .foregroundStyle(AppColors.outline)
                        Spacer()
                        if let duration = conversation.durationText {
                            Text(duration)
                                .font(AppTypography.label)
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 3)
                                .background(AppColors.primaryFixed.opacity(0.7), in: Capsule())
                        }
                    }
                    Text(conversation.title)
                        .font(AppTypography.headlineMobile)
                        .foregroundStyle(AppColors.onSurface)
                        .lineLimit(1)
                    Text(conversation.preview)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.outline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

extension Date {
    var relativeHistoryText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

struct HistoryListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewScaffold {
                let viewModel = HistoryListViewModel.previewLoaded()
                viewModel.loadFirstPage()
                return HistoryListView(viewModel: viewModel)
            }
            .previewDisplayName("History Loaded")

            PreviewScaffold {
                let viewModel = HistoryListViewModel.previewError()
                viewModel.loadFirstPage()
                return HistoryListView(viewModel: viewModel)
            }
            .previewDisplayName("History Error")
        }
    }
}
