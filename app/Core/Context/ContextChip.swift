import Foundation

public struct ContextChip: Equatable, Sendable {
    public let source: String
    public let app: String?
    public let value: ContextValue?

    public init(source: String, app: String?, value: ContextValue? = nil) {
        self.source = source
        self.app = app
        self.value = value
    }

    public var isLoading: Bool {
        value == nil
    }

    func filled(with value: ContextValue) -> ContextChip {
        ContextChip(source: source, app: value.app ?? app, value: value)
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
