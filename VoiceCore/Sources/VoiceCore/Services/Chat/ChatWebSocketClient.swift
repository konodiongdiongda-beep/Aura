import Foundation

public final class ChatWebSocketClient: ChatClient {
    private let endpoint: URL
    private let urlSession: URLSession
    private let idFactory: ConversationIDFactory
    private let encoder: JSONEncoder

    public init(
        endpoint: URL = URL(string: "ws://43.98.164.20:6007/ws/chat")!,
        urlSession: URLSession = .shared,
        idFactory: ConversationIDFactory = ConversationIDFactory(),
        encoder: JSONEncoder = .voiceCore
    ) {
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.idFactory = idFactory
        self.encoder = encoder
    }

    public func sendMessage(_ text: String, conversation: ConversationContext) -> AsyncThrowingStream<ChatStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            let turn = idFactory.makeTurnContext(for: conversation)
            let parser = ChatStreamParser(activeBotChatID: turn.botChatID)
            let webSocket = urlSession.webSocketTask(with: endpoint)

            let task = Task {
                do {
                    continuation.yield(.started(userChatID: turn.userChatID, botChatID: turn.botChatID))
                    webSocket.resume()

                    let payload = ChatRequestPayload(content: text, turn: turn)
                    let data = try encoder.encode(payload)
                    guard let json = String(data: data, encoding: .utf8) else {
                        throw AppError.responseParsingFailed
                    }
                    try await webSocket.send(.string(json))

                    while !Task.isCancelled {
                        let message = try await webSocket.receive()
                        let lines: [String]
                        switch message {
                        case let .string(text):
                            lines = text.split(whereSeparator: \.isNewline).map(String.init)
                        case let .data(data):
                            let text = String(data: data, encoding: .utf8) ?? ""
                            lines = text.split(whereSeparator: \.isNewline).map(String.init)
                        @unknown default:
                            lines = []
                        }

                        for line in lines {
                            let updates = try parser.parseLine(line)
                            for update in updates {
                                continuation.yield(update)
                                if update == .completed {
                                    continuation.finish()
                                    webSocket.cancel(with: .normalClosure, reason: nil)
                                    return
                                }
                            }
                        }
                    }
                } catch is CancellationError {
                    webSocket.cancel(with: .goingAway, reason: nil)
                    continuation.finish()
                } catch {
                    if Task.isCancelled || isLocalCancellation(error) {
                        webSocket.cancel(with: .goingAway, reason: nil)
                        continuation.finish()
                        return
                    }
                    print("[ChatWebSocketClient] failed: \(error.localizedDescription)")
                    webSocket.cancel(with: .goingAway, reason: nil)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                webSocket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func isLocalCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return nsError.code == NSURLErrorCancelled || nsError.code == NSURLErrorNetworkConnectionLost
    }
}
