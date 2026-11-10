import Foundation

/// A calendar of events or a list of reminders, with the account that holds it.
public struct AgendaList: Equatable, Sendable {
    public let id: String
    public let title: String
    public let account: String
    /// Its colour as `#RRGGBB`.
    public let color: String?

    public init(id: String, title: String, account: String, color: String?) {
        self.id = id
        self.title = title
        self.account = account
        self.color = color
    }

    /// Its row, whose id `--calendar` and `--list` take (E1).
    var row: TextBlock {
        TextBlock(fields: [.init(key: "row", value: id), .init(key: "title", value: title), .init(key: "detail", value: account)]
            + (color.map { [.init(key: "color", value: $0)] } ?? []))
    }
}
