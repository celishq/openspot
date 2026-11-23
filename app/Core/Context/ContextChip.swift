import Foundation

public struct ContextChip: Equatable, Sendable {
    public struct Look: Equatable, Sendable {
        public let symbol: String
        public let file: FileIcon?

        public init(symbol: String = "", file: FileIcon? = nil) {
            self.symbol = symbol
            self.file = file
        }
    }

    public let source: String
    public let app: String?
    public let value: ContextValue?
    public let look: Look

    public init(source: String, app: String?, value: ContextValue? = nil, look: Look = Look()) {
        self.source = source
        self.app = app
        self.value = value
        self.look = look
    }

    public static func == (lhs: ContextChip, rhs: ContextChip) -> Bool {
        lhs.source == rhs.source && lhs.app == rhs.app && lhs.value == rhs.value
    }

    public var isLoading: Bool {
        value == nil
    }

    func filled(with value: ContextValue, look: Look) -> ContextChip {
        ContextChip(source: source, app: value.app ?? app, value: value, look: look)
    }

    func rank(over front: String?) -> Int {
        let isFront = front != nil && app == front
        let isText = value?.kind == .text
        return (isFront ? 0 : 2) + (isText ? 0 : 1)
    }
}

extension ContextChip {
    public var words: (title: String, detail: String) {
        guard let value else { return ("Loading", "") }
        let first = value.values.first ?? ""
        switch value.kind {
        case .url:
            return (value.title ?? first, first)
        case .text:
            let line = first.split(whereSeparator: \.isNewline).first.map(String.init) ?? first
            return (line.trimmingCharacters(in: .whitespaces), value.title ?? "Text")
        case .file:
            let names = value.values.map { URL(fileURLWithPath: $0).lastPathComponent }
            let title = value.title ?? (names.count == 1 ? names[0] : "\(names.count) files")
            return (title, names.count == 1 ? URL(fileURLWithPath: first).deletingLastPathComponent().path : names.joined(separator: ", "))
        }
    }

    public var symbol: String {
        switch value?.kind {
        case .url: "link"
        case .text: "text.quote"
        case .file: "doc"
        case nil: "ellipsis"
        }
    }
}
