import Foundation

public struct DropKinds: Equatable, Sendable {
    public let extensions: Set<String>
    public let folders: Bool
    public let anyFile: Bool
    public let isDeclared: Bool

    public init(_ words: [String] = []) {
        let words = Set(words.map { $0.lowercased() })
        anyFile = words.contains("*")
        folders = words.contains("folder")
        extensions = words.subtracting(["", "*", "folder"])
        isDeclared = !words.isEmpty
    }

    public var files: Bool {
        anyFile || !extensions.isEmpty
    }

    public var takesFolders: Bool {
        folders || anyFile
    }

    var takesAny: Bool {
        files || takesFolders
    }

    func takes(_ value: AttachmentValue) -> Bool {
        value.kind == .file && !value.files.paths.isEmpty && value.files.paths.allSatisfy { takes(path: $0, kind: value.files.kind(of: $0)) }
    }

    func takes(path: String, kind: FileKinds.Kind?) -> Bool {
        guard let kind else { return false }
        if kind == .folder { return takesFolders }
        return anyFile || extensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
}
