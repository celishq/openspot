import Foundation

public struct AttachmentValue: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case file
        case url
        case text
    }

    public let kind: Kind
    public let values: [String]
    public let title: String?
    public let app: String?
    let files: FileKinds

    public init(url: String, title: String? = nil, app: String? = nil) {
        self.init(kind: .url, values: [url], title: title, app: app, files: FileKinds())
    }

    public init(text: String, title: String? = nil, app: String? = nil) {
        self.init(kind: .text, values: [text], title: title, app: app, files: FileKinds())
    }

    public init(files: FileKinds, title: String? = nil, app: String? = nil) {
        self.init(kind: .file, values: files.paths, title: title, app: app, files: files)
    }

    private init(kind: Kind, values: [String], title: String?, app: String?, files: FileKinds) {
        self.kind = kind
        self.values = values
        self.title = title
        self.app = app
        self.files = files
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

    public var takerWords: String {
        switch self {
        case .file: "Takes the files"
        case .url: "Takes the link"
        case .text: "Takes the text"
        }
    }
}
