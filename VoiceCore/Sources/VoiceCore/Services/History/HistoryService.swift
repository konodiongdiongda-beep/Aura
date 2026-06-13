import Foundation

public final class HistoryService: HistoryClient {
    private let conversationsEndpoint: URL
    private let messagesEndpoint: URL
    private let urlSession: URLSession
    private let idFactory: ConversationIDFactory
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        conversationsEndpoint: URL = URL(string: "http://43.98.164.20:6007/history/user/page")!,
        messagesEndpoint: URL = URL(string: "http://43.98.164.20:6007/history-with-alerts/")!,
        urlSession: URLSession = .shared,
        idFactory: ConversationIDFactory = ConversationIDFactory(),
        encoder: JSONEncoder = .voiceCore,
        decoder: JSONDecoder = .voiceCore
    ) {
        self.conversationsEndpoint = conversationsEndpoint
        self.messagesEndpoint = messagesEndpoint
        self.urlSession = urlSession
        self.idFactory = idFactory
        self.encoder = encoder
        self.decoder = decoder
    }

    public func fetchConversations(page: Int, pageSize: Int) async throws -> HistoryPage {
        let conversation = idFactory.makeConversationContext()
        let payload = HistoryPageRequestDTO(
            userID: conversation.userID,
            page: page,
            pageSize: pageSize,
            userName: conversation.userName,
            context: idFactory.makeRequestContext(for: conversation)
        )
        let response: HistoryListResponseDTO = try await post(payload, to: conversationsEndpoint)
        guard response.success else {
            throw AppError.backendRejected(response.message ?? "History request failed.")
        }
        return response.toDomain(page: page, pageSize: pageSize)
    }

    public func fetchMessages(cid: String, page: Int, pageSize: Int) async throws -> MessagePage {
        let conversation = idFactory.makeConversationContext(cid: cid)
        let payload = HistoryMessagesRequestDTO(
            pageSize: pageSize,
            page: page,
            userName: conversation.userName,
            userID: conversation.userID,
            context: idFactory.makeRequestContext(for: conversation),
            cid: cid
        )
        let response: HistoryMessagesResponseDTO = try await post(payload, to: messagesEndpoint)
        guard response.success else {
            throw AppError.backendRejected(response.message ?? "Message history request failed.")
        }
        return response.toDomain(page: page, pageSize: pageSize)
    }

    private func post<Request: Encodable, Response: Decodable>(_ payload: Request, to endpoint: URL) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.networkUnavailable
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.responseParsingFailed
        }
    }
}
