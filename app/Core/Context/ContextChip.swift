import Foundation

public struct ContextChip: Equatable, Sendable {
    public enum Look: Hashable, Sendable {
        case file(FileIcon)
        case symbol(String)
    }

    public enum State: Equatable, Sendable {
        case loading
        case ready(ContextValue)
    }

    public let source: String
    public let app: String?
    public let look: Look
    public let state: State

    public init(source: String, app: String?, look: Look, state: State = .loading) {
        self.source = source
        self.app = app
        self.look = look
        self.state = state
    }

    public var value: ContextValue? {
        guard case .ready(let value) = state else { return nil }
        return value
    }

    public var isLoading: Bool {
        state == .loading
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

    static func symbol(of kind: ContextValue.Kind?) -> String {
        switch kind {
        case .url: "globe"
        case .text: "text.quote"
        case .file: "doc"
        case nil: "ellipsis"
        }
    }
}
