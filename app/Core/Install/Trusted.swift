import Foundation

public enum Trusted: Hashable, Sendable {
    case author(String)
    case source(String)

    static let tableName = "trusted"

    init?(table: ConfigDocument.Table) {
        if case .string(let key)? = table["author"] {
            self = .author(key)
        } else if case .string(let source)? = table["source"] {
            self = .source(source)
        } else {
            return nil
        }
    }

    var table: ConfigDocument.Table {
        switch self {
        case .author(let key): ConfigDocument.Table(Self.tableName, [("author", .string(key))])
        case .source(let source): ConfigDocument.Table(Self.tableName, [("source", .string(source))])
        }
    }

    var title: String {
        switch self {
        case .author: "Trust its author"
        case .source: "Trust this spot"
        }
    }
}
