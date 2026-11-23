import Foundation

public struct ContextValue: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case file
        case url
        case text

        static let words = Set([Kind.url.rawValue, Kind.text.rawValue])
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
