import Foundation

public enum ClipboardContents: Equatable, Sendable {
    case none
    case text
    case files([URL])
    case image(String)

    static let concealedType = "org.nspasteboard.ConcealedType"
    static let textType = "public.utf8-plain-text"
    static let pngType = "public.png"
    static let tiffType = "public.tiff"

    init(types: Set<String>, files: [URL]) {
        if types.contains(Self.concealedType) { self = .none }
        else if !files.isEmpty { self = .files(files) }
        else if types.contains(Self.textType) { self = .text }
        else if types.contains(Self.pngType) { self = .image("png") }
        else if types.contains(Self.tiffType) { self = .image("tiff") }
        else { self = .none }
    }

    init(of board: any MacClipboard) {
        self.init(types: board.types(), files: board.files())
    }
}
