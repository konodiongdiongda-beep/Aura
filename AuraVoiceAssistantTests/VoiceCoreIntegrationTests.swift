import XCTest
import VoiceCore
@testable import AuraVoiceAssistant

@MainActor
final class VoiceCoreIntegrationTests: XCTestCase {
    func testMockConversationUsesVoiceCoreDomainModel() {
        let conversation: VoiceCore.Conversation = MockData.conversations[0]

        XCTAssertEqual(conversation.title, "Daily Schedule Planning")
    }

    func testVoiceViewModelUsesVoiceCoreCallState() {
        let state: VoiceCore.VoiceCallState = VoiceCallViewModel.preview(.listening).state

        XCTAssertEqual(state, .listening)
    }

    func testMainNavigationExcludesKeyboardTextInputTab() {
        let tabIdentifiers = AppTab.allCases.map(\.rawValue)

        XCTAssertEqual(tabIdentifiers, ["history", "voice", "settings"])
        XCTAssertFalse(tabIdentifiers.contains("keyboard"))
    }
}
