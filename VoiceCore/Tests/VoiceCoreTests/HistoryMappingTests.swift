import XCTest
@testable import VoiceCore

final class HistoryMappingTests: XCTestCase {
    func testMapsHistoryResponseItemsToConversations() throws {
        let json = """
        {
          "message": "获取成功",
          "total": 1,
          "success": true,
          "data": [
            {
              "cid": "CID-1",
              "metadata": {
                "cid_md5": "abc123def4567890",
                "processing_time": 5.6
              },
              "display_text": "晚上好啊",
              "created_at": "2026-05-19T13:08:57",
              "updated_at": "2026-05-19T13:09:07",
              "chat_id": "USER-CHAT-1",
              "role": "user"
            }
          ]
        }
        """

        let response = try JSONDecoder.voiceCore.decode(HistoryListResponseDTO.self, from: Data(json.utf8))
        let page = response.toDomain(page: 1, pageSize: 20)

        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.items, [
            Conversation(
                id: "CID-1",
                cidMD5: "abc123def4567890",
                title: "晚上好啊",
                preview: "晚上好啊",
                updatedAt: ISO8601DateFormatter.voiceCore.date(from: "2026-05-19T13:09:07")!,
                durationText: "5.6s"
            )
        ])
    }

    func testMapsMessageResponseItemsToChatMessages() throws {
        let json = """
        {
          "message": "获取成功",
          "total": 2,
          "success": true,
          "data": [
            {
              "cid": "CID-1",
              "role": "user",
              "voice_text": null,
              "created_at": "2026-05-19T13:08:57",
              "chat_id": "USER-CHAT-1",
              "display_text": "晚上好啊"
            },
            {
              "cid": "CID-1",
              "role": "bot",
              "voice_text": "您好，晚上好。",
              "created_at": "2026-05-19T21:09:07",
              "chat_id": "BOT-CHAT-1",
              "display_text": "您好，晚上好。"
            }
          ]
        }
        """

        let response = try JSONDecoder.voiceCore.decode(HistoryMessagesResponseDTO.self, from: Data(json.utf8))
        let page = response.toDomain(page: 0, pageSize: 20)

        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.items.map(\.role), [.user, .assistant])
        XCTAssertEqual(page.items[0].id, "USER-CHAT-1")
        XCTAssertEqual(page.items[0].deliveryState, .complete)
        XCTAssertEqual(page.items[1].voiceText, "您好，晚上好。")
    }

    func testMapsHistoryWithoutMetadataOrOptionalFields() throws {
        let json = """
        {
          "message": "获取成功",
          "total": 1,
          "success": true,
          "data": [
            {
              "cid": "CID-1",
              "role": "bot",
              "display_text": "无 metadata 也能映射"
            }
          ]
        }
        """

        let response = try JSONDecoder.voiceCore.decode(HistoryListResponseDTO.self, from: Data(json.utf8))
        let page = response.toDomain(page: 1, pageSize: 20)

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].cidMD5, ConversationIDFactory.cidMD5(for: "CID-1"))
        XCTAssertEqual(page.items[0].preview, "无 metadata 也能映射")
        XCTAssertNil(page.items[0].durationText)
    }
}
