public enum HeaderBlock: String, CaseIterable, Sendable {
    case button, field

    public var keys: Set<String> {
        switch self {
        case .button: [rawValue, "title", "icon", "offers", "when", "hotkey", "shortcut", "scope", "close", "form", "confirm"]
        case .field: [rawValue, "title", "icon", "type"]
        }
    }

    init?(block: TextBlock) {
        guard let kind = block.fields.first.flatMap({ HeaderBlock(rawValue: $0.key) }) else { return nil }
        self = kind
    }

    static func unknown(in block: TextBlock) -> String? {
        guard let kind = HeaderBlock(block: block) else { return nil }
        return block.fields.map(\.key).first { HeaderKey.isWord($0) && !kind.keys.contains($0) }
    }
}
