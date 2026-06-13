import Foundation

public struct Conversation: Identifiable, Equatable {
    public let id: String
    public let cidMD5: String
    public var title: String
    public var preview: String
    public var updatedAt: Date
    public var durationText: String?

    public init(
        id: String,
        cidMD5: String,
        title: String,
        preview: String,
        updatedAt: Date,
        durationText: String? = nil
    ) {
        self.id = id
        self.cidMD5 = cidMD5
        self.title = title
        self.preview = preview
        self.updatedAt = updatedAt
        self.durationText = durationText
    }
}
