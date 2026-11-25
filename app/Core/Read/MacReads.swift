import Foundation

public protocol MacReads: Sendable {
    func front() async -> FrontApp?
    func name(of bundleID: String) -> String?
    func place(of bundleID: String) -> String?
    func access(to bundleID: String, asks: Bool) async -> ReadAccess
    func run(_ script: String) async -> [String]?
    func accessibility(asks: Bool) -> ReadAccess
    func selectedText(of bundleID: String) async -> String?
}
