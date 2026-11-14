import Foundation

public struct CalendarList: Equatable, Sendable {
    public let id: String
    public let title: String
    public let account: String
    public let color: String?

    public init(id: String, title: String, account: String, color: String?) {
        self.id = id
        self.title = title
        self.account = account
        self.color = color
    }

    var row: TextBlock {
        TextBlock(fields: [.init(key: "row", value: id), .init(key: "title", value: title), .init(key: "detail", value: account)]
            + (color.map { [.init(key: "color", value: $0)] } ?? []))
    }
}
