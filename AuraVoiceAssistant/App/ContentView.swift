import SwiftUI
import VoiceCore

struct ContentView: View {
    private static let conversationStore = LocalConversationStore()

    @StateObject private var voiceViewModel = VoiceCallViewModel(historyStore: ContentView.conversationStore)
    @StateObject private var historyViewModel = HistoryListViewModel(store: ContentView.conversationStore)
    @StateObject private var settingsViewModel = SettingsViewModel(config: AppConfig.load())
    @State private var selectedTab: AppTab = .voice
    @State private var selectedHistoryConversation: Conversation?
    @State private var messageListViewModel: MessageListViewModel?
    static let bottomNavigationHeight: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            let reservedBottom = Self.bottomNavigationHeight + proxy.safeAreaInsets.bottom
            let topInset = max(proxy.safeAreaInsets.top, UIApplication.shared.appKeyWindowSafeAreaInsets.top)

            ZStack(alignment: .bottom) {
                MeshBackground()

                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .history:
                            HistoryListView(viewModel: historyViewModel) { conversation in
                                messageListViewModel = historyViewModel.makeMessageListViewModel(for: conversation)
                                selectedHistoryConversation = conversation
                            }
                        case .voice:
                            VoiceRootView(viewModel: voiceViewModel, text: settingsViewModel.text)
                        case .settings:
                            SettingsView(viewModel: settingsViewModel)
                        }
                    }
                    .frame(
                        width: proxy.size.width,
                        height: max(0, proxy.size.height - reservedBottom),
                        alignment: .top
                    )
                    .environment(\.appTopSafeAreaInset, topInset)

                    Spacer(minLength: reservedBottom)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                BottomNavigationBar(
                    selectedTab: $selectedTab,
                    bottomInset: proxy.safeAreaInsets.bottom,
                    barHeight: Self.bottomNavigationHeight,
                    text: settingsViewModel.text
                )
                .zIndex(2)

                if selectedHistoryConversation != nil, let messageListViewModel {
                    MessageDetailView(
                        viewModel: messageListViewModel
                    ) {
                        self.selectedHistoryConversation = nil
                        self.messageListViewModel = nil
                    }
                    .environment(\.appTopSafeAreaInset, topInset)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(3)
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: selectedHistoryConversation?.id)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

enum AppTab: String, CaseIterable {
    case history
    case voice
    case settings

    var icon: String {
        switch self {
        case .history:
            return "clock.arrow.circlepath"
        case .voice:
            return "phone.fill"
        case .settings:
            return "person.crop.circle"
        }
    }

    func accessibilityLabel(_ text: AppText) -> String {
        switch self {
        case .history:
            return text.historyTab
        case .voice:
            return text.voiceTab
        case .settings:
            return text.settingsTab
        }
    }
}

struct BottomNavigationBar: View {
    static let primaryItemSize: CGFloat = 42
    static let secondaryItemSize: CGFloat = 36

    @Binding var selectedTab: AppTab
    var bottomInset: CGFloat = 0
    var barHeight: CGFloat = ContentView.bottomNavigationHeight
    var text: AppText

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: tab == .voice ? 21 : 19, weight: .semibold))
                        .frame(
                            width: tab == .voice ? Self.primaryItemSize : Self.secondaryItemSize,
                            height: tab == .voice ? Self.primaryItemSize : Self.secondaryItemSize
                        )
                        .foregroundStyle(selectedTab == tab ? .white : AppColors.onSurfaceVariant.opacity(0.72))
                        .background(
                            selectedTab == tab ? AppColors.primary : AppColors.primaryContainer.opacity(0),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel(text))
                if tab != AppTab.allCases.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: barHeight, alignment: .center)
        .padding(.bottom, bottomInset)
        .background(.white.opacity(0.72))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(height: 1)
        }
        .clipShape(TopRoundedRectangle(radius: 20))
        .shadow(color: AppColors.primary.opacity(0.10), radius: 22, x: 0, y: -8)
    }

    static func shouldStartCall(whenSelecting tab: AppTab) -> Bool {
        false
    }
}

private extension UIApplication {
    var appKeyWindowSafeAreaInsets: UIEdgeInsets {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
}

struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
