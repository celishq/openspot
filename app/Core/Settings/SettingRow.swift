import Foundation

public struct SettingRow: PrintedRecord, Equatable, Identifiable, Sendable {
    public enum Kind: String, Encodable, Sendable {
        case key, field, toggle, choice, secret, text
    }

    public enum Section: String, Encodable, Sendable {
        case general, developer, keys, look, account, spot
    }

    static let secretValue = "set"

    public let item: String
    public let spot: String
    public let name: String
    public let key: String
    public let title: String
    public let value: String?
    public let kind: Kind
    public let section: Section
    public let icon: String
    public let detail: String?
    public let options: String?
    public let `default`: String?

    init(spot: String, name: String, key: String, title: String, value: String?, kind: Kind, section: Section, icon: String, detail: String? = nil, options: [String] = [], default: String? = nil) {
        item = "\(spot)/\(key)"
        self.spot = spot
        self.name = name
        self.key = key
        self.title = title
        self.value = value
        self.kind = kind
        self.section = section
        self.icon = icon
        self.detail = detail
        self.options = options.isEmpty ? nil : options.joined(separator: ",")
        self.default = `default`
    }

    public var id: String {
        item
    }

    var blocks: [[(String, String?)]] {
        [[("item", item), ("spot", spot), ("name", name), ("key", key), ("title", title), ("value", value), ("kind", kind.rawValue), ("section", section.rawValue), ("icon", icon), ("detail", detail), ("options", options), ("default", `default`)]]
    }
}
