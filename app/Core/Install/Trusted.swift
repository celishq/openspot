import Foundation

public enum Trusted: Hashable, Sendable {
    case author(String)
    case spot(String)

    static let tableName = "trusted"

    init?(table: ConfigDocument.Table) {
        if case .string(let key)? = table["author"] {
            self = .author(key)
        } else if case .string(let spot)? = table["spot"] {
            self = .spot(spot)
        } else {
            return nil
        }
    }

    var table: ConfigDocument.Table {
        switch self {
        case .author(let key): ConfigDocument.Table(Self.tableName, [("author", .string(key))])
        case .spot(let spot): ConfigDocument.Table(Self.tableName, [("spot", .string(spot))])
        }
    }

    var title: String {
        switch self {
        case .author: "Trust its author"
        case .spot: "Trust this spot"
        }
    }
}
