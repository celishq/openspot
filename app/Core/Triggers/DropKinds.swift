import Foundation

public struct DropKinds: Equatable, Sendable {
    public let extensions: Set<String>
    public let folders: Bool
    public let anyFile: Bool
    public let url: Bool
    public let text: Bool
    public let isDeclared: Bool

    public init(_ words: [String] = []) {
        let words = Set(words.map { $0.lowercased() })
        anyFile = words.contains("*")
        folders = words.contains("folder")
        url = words.contains(ContextValue.Kind.url.rawValue)
        text = words.contains(ContextValue.Kind.text.rawValue)
        extensions = words.subtracting(["", "*", "folder", ContextValue.Kind.url.rawValue, ContextValue.Kind.text.rawValue])
        isDeclared = !words.isEmpty
    }

    public var files: Bool {
        anyFile || !extensions.isEmpty
    }

    public var takesFolders: Bool {
        folders || anyFile
    }

    public func takes(_ kind: ContextValue.Kind) -> Bool {
        switch kind {
        case .file: files || takesFolders
        case .url: url
        case .text: text
        }
    }

    func takes(path: String, kind: FileKinds.Kind?) -> Bool {
        guard let kind else { return false }
        if kind == .folder { return takesFolders }
        return anyFile || extensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
}
