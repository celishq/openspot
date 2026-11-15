import Foundation

@MainActor
protocol ScriptLink: AnyObject {
    var run: SpotRun? { get set }
    var isAsking: Bool { get }
    @discardableResult
    func send(_ call: OpenCall) -> Bool
    func stop(_ call: ScriptCall)
    func settle()
    func restart()
    func end()
    func leave()
    func scanned(_ stamp: [Int]?)
}

extension ScriptLink {
    func stop(_ call: ScriptCall) {}

    func settle() {}

    func restart() {}

    func end() {}

    func leave() {}

    func scanned(_ stamp: [Int]?) {}
}
