import XCTest
@testable import VoiceCore

final class ChatStreamParserTests: XCTestCase {
    func testParsesFinalTokenDisplayTextAndAccumulatesVisibleText() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-1")

        let first = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"display_text":"我是","index":0},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)
        let second = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"display_text":"助手","index":1},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        XCTAssertEqual(first, [.assistantToken("我是")])
        XCTAssertEqual(second, [.assistantToken("助手")])
        XCTAssertEqual(parser.accumulatedDisplayText, "我是助手")
    }

    func testIgnoresFinalResultJSONTextFragmentsWhenDisplayTextIsMissing() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-1")

        let updates = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"text":"\\"intent\\":\\"chat\\"","index":0},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        XCTAssertEqual(updates, [])
        XCTAssertEqual(parser.accumulatedDisplayText, "")
    }

    func testParsesFinishResultAndFallsBackVoiceTextToDisplayText() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-1")

        let updates = try parser.parseLine("""
        {"agent_name":"system_agent","step_type":"finish","step_output":{"status":"completed","result":"{\\"voice_text\\":\\"\\",\\"display_text\\":\\"最终回答\\",\\"cards\\":[],\\"intent\\":\\"chat\\"}"},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        XCTAssertEqual(updates, [
            .final(displayText: "最终回答", voiceText: "最终回答", intent: "chat"),
            .completed
        ])
    }

    func testParsesMessageIDsAndIgnoresStaleBotStream() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-2")

        let stale = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"display_text":"旧消息","index":0},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)
        let ids = try parser.parseLine("""
        {"type":"message_ids","user_message_id":1480,"bot_message_id":1481,"user_chat_id":"USER-CHAT-2","bot_chat_id":"BOT-CHAT-2"}
        """)

        XCTAssertEqual(stale, [])
        XCTAssertEqual(ids, [.messageIDs(userMessageID: 1480, botMessageID: 1481)])
        XCTAssertEqual(parser.accumulatedDisplayText, "")
    }

    func testFinishFallsBackToAccumulatedDisplayTextWhenResultJSONIsInvalid() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-1")
        _ = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"display_text":"已累积文本","index":0},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        let updates = try parser.parseLine("""
        {"agent_name":"system_agent","step_type":"finish","step_output":{"status":"completed","result":"not-json"},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        XCTAssertEqual(updates, [
            .final(displayText: "已累积文本", voiceText: "已累积文本", intent: nil),
            .completed
        ])
    }

    func testIgnoresAttemptCompletionJSONTailAfterDisplayTextTokens() throws {
        let parser = ChatStreamParser(activeBotChatID: "BOT-CHAT-1")
        _ = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"display_text":"您好。","index":0},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        let updates = try parser.parseLine("""
        {"agent_name":"chat_agent","step_type":"final_token","step_output":{"text":"isplay_text\\":\\"您好。\\",\\"cards\\":[],\\"intent\\":\\"chat\\"}","index":48},"user_chat_id":"USER-CHAT-1","bot_chat_id":"BOT-CHAT-1"}
        """)

        XCTAssertEqual(updates, [])
        XCTAssertEqual(parser.accumulatedDisplayText, "您好。")
    }
}
