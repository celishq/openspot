import Foundation

public struct AttachmentValue: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case file
        case url
        case text
    }

    public enum Payload: Equatable, Sendable {
        case files(FileKinds)
        case url(String)
        case text(String)
    }

    public let payload: Payload
    public let title: String?
    public let app: String?
    public let icon: Icon?

    public init(_ payload: Payload, title: String? = nil, app: String? = nil, icon: Icon? = nil) {
        self.payload = payload
        self.title = title
        self.app = app
        self.icon = icon
    }

    public init(url: String, title: String? = nil, app: String? = nil, icon: Icon? = nil) {
        self.init(.url(url), title: title, app: app, icon: icon)
    }

    public init(text: String, title: String? = nil, app: String? = nil, icon: Icon? = nil) {
        self.init(.text(text), title: title, app: app, icon: icon)
    }

    public init(files: FileKinds, title: String? = nil, app: String? = nil, icon: Icon? = nil) {
        self.init(.files(files), title: title, app: app, icon: icon)
    }

    public var kind: Kind {
        switch payload {
        case .files: .file
        case .url: .url
        case .text: .text
        }
    }

    var texts: [String] {
        switch payload {
        case .files(let files): files.paths
        case .url(let url): [url]
        case .text(let text): [text]
        }
    }
}

extension AttachmentValue.Kind {
    public enum Badge: Hashable, Sendable {
        case symbol(String)
        case letter(String)
    }

    public var symbol: String {
        switch self {
        case .url: "arrow.up.right"
        case .text: "text.quote"
        case .file: "doc"
        }
    }

    public var captionSymbol: String {
        self == .text ? "textformat" : symbol
    }

    public var badge: Badge {
        switch self {
        case .url: .symbol("arrow.up.right")
        case .text: .letter("T")
        case .file: .symbol("doc.fill")
        }
    }
}
