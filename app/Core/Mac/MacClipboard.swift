import Foundation

public protocol MacClipboard: Sendable {
    func copy(text: String) throws
    func copy(file: URL) throws
    func text() -> String
    func paste() throws
}
