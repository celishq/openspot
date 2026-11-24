import Foundation

public protocol MacClipboard: Sendable {
    func copy(text: String) throws
    func copy(file: URL) throws
    func text() -> String
    func contents() -> ClipboardContents
    func count() -> Int
    func writeImage(to file: URL) throws
    func paste() throws
}
