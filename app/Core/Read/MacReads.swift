import Foundation

public protocol MacReads: Sendable {
    func front() async -> FrontApp?
    func isInstalled(_ bundleID: String) -> Bool
    func access(to bundleID: String, asks: Bool) async -> ReadAccess
    func run(_ script: String) async -> [String]?
    func accessibility(asks: Bool) -> ReadAccess
    func selectedText() async -> String?
    func copyCount() -> Int
    func copiedText() -> String?
}
