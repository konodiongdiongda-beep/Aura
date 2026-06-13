import XCTest
@testable import VoiceCore

final class ConversationIDFactoryTests: XCTestCase {
    func testCreatesConversationContextWithCIDMD5AndRequestMetadata() {
        var uuids = [
            "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "USER-CHAT-1",
            "BOT-CHAT-1"
        ]
        let date = Date(timeIntervalSince1970: 1_779_197_512)
        let factory = ConversationIDFactory(
            userName: "test01",
            userID: 35,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!,
            uuidProvider: { uuids.removeFirst() },
            dateProvider: { date }
        )

        let conversation = factory.makeConversationContext()
        let turn = factory.makeTurnContext(for: conversation)

        XCTAssertEqual(conversation.cid, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        XCTAssertEqual(conversation.cidMD5, "7affc68fcf21a36a")
        XCTAssertEqual(turn.secondTime, "20260519213152")
        XCTAssertEqual(turn.requestID, "test01_7affc68fcf21a36a_20260519213152")
        XCTAssertEqual(turn.userChatID, "USER-CHAT-1")
        XCTAssertEqual(turn.botChatID, "BOT-CHAT-1")
    }

    func testCreatesNewChatIDsForEveryTurnInSameConversation() {
        var uuids = [
            "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "USER-CHAT-1",
            "BOT-CHAT-1",
            "USER-CHAT-2",
            "BOT-CHAT-2"
        ]
        let factory = ConversationIDFactory(
            userName: "test01",
            userID: 35,
            uuidProvider: { uuids.removeFirst() },
            dateProvider: { Date(timeIntervalSince1970: 0) }
        )

        let conversation = factory.makeConversationContext()
        let firstTurn = factory.makeTurnContext(for: conversation)
        let secondTurn = factory.makeTurnContext(for: conversation)

        XCTAssertEqual(firstTurn.userChatID, "USER-CHAT-1")
        XCTAssertEqual(firstTurn.botChatID, "BOT-CHAT-1")
        XCTAssertEqual(secondTurn.userChatID, "USER-CHAT-2")
        XCTAssertEqual(secondTurn.botChatID, "BOT-CHAT-2")
        XCTAssertEqual(firstTurn.requestID, secondTurn.requestID)
    }

    func testBuildsDocumentedChatPayloadShape() throws {
        let turn = ChatTurnContext(
            cid: "CID-1",
            cidMD5: "abc123def4567890",
            userName: "test01",
            userID: 35,
            userChatID: "USER-CHAT-1",
            botChatID: "BOT-CHAT-1",
            secondTime: "20260519213152",
            requestID: "test01_abc123def4567890_20260519213152"
        )

        let payload = ChatRequestPayload(content: "你是谁", turn: turn)
        let data = try JSONEncoder.voiceCore.encode(payload)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let context = object?["context"] as? [String: Any]

        XCTAssertEqual(object?["collect_step_results"] as? Bool, false)
        XCTAssertEqual(object?["user_name"] as? String, "test01")
        XCTAssertEqual(object?["user_id"] as? Int, 35)
        XCTAssertEqual(object?["cid"] as? String, "CID-1")
        XCTAssertEqual(object?["content"] as? String, "你是谁")
        XCTAssertEqual(context?["stream"] as? Bool, true)
        XCTAssertEqual(context?["model_name"] as? String, "azure-gpt-4.1")
        XCTAssertEqual(context?["voice_mode"] as? Bool, true)
        XCTAssertEqual(context?["cid_md5"] as? String, "abc123def4567890")
        XCTAssertEqual(context?["user_chat_id"] as? String, "USER-CHAT-1")
        XCTAssertEqual(context?["bot_chat_id"] as? String, "BOT-CHAT-1")
        XCTAssertEqual(context?["request_id"] as? String, "test01_abc123def4567890_20260519213152")
    }
}
