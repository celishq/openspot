import Foundation

@MainActor
protocol ScriptLink: AnyObject {
    var run: SpotRun? { get set }
    var isAsking: Bool { get }
    var keepsState: Bool { get }
    var holdsScript: Bool { get }
    var isReachable: Bool { get }
    @discardableResult
    func send(_ call: SpotRun.Call) -> Bool
    func form(_ action: SpotAction, key: String) async throws -> String?
    func submit(_ action: SpotAction, key: String, values: String) async throws -> String?
    func stop(_ call: ScriptCall)
    func settle()
    func end()
    func leave()
    func scanned()
}
