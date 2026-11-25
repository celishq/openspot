import Foundation

@MainActor
protocol ScriptMode: AnyObject {
    typealias Frames = (stream: AsyncThrowingStream<String, Error>, halt: () -> Void, process: ScriptProcess?)

    init(runs: SpotRuns)
    var run: SpotRun? { get set }
    var isAsking: Bool { get }
    @discardableResult
    func send(_ call: OpenCall) -> Bool
    func stop(_ call: ScriptCall)
    func settle()
    func end()
    func leave()
    func holdLimit()
    func releaseLimit()
    func scanned(_ stamp: [Int]?)
    static var keepsState: Bool { get }
    static var answersInApp: Bool { get }
    static func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames
    static func answer(of spot: Spot, _ handler: String, input: String?, limit: TimeInterval?, variables: [String: String], in runs: SpotRuns) async throws -> String
}

extension ScriptMode {
    func stop(_ call: ScriptCall) {}

    func settle() {}

    func end() {}

    func leave() {}

    func holdLimit() {}

    func releaseLimit() {}

    func scanned(_ stamp: [Int]?) {}

    static var keepsState: Bool {
        false
    }

    static var answersInApp: Bool {
        false
    }

    static func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames {
        runs.process(of: spot, message, limit: limit, reason: reason, variables: variables, call: call)
    }

    static func answer(of spot: Spot, _ handler: String, input: String?, limit: TimeInterval?, variables: [String: String], in runs: SpotRuns) async throws -> String {
        try await collect(of: spot, handler, input: input, limit: limit, variables: variables, in: runs)
    }

    static func collect(of spot: Spot, _ handler: String, input: String?, limit: TimeInterval?, variables: [String: String], in runs: SpotRuns) async throws -> String {
        let (stream, halt, _) = frames(of: spot, Message(handler, given: input), limit: limit, reason: nil, variables: variables, call: nil, in: runs)
        defer { if runs.sheets[spot.id] == nil { runs.dropScript(of: spot.id) } }
        if handler == ScriptEntry.show.name {
            defer { halt() }
            for try await frame in stream { return frame }
            return ""
        }
        var text = ""
        for try await frame in stream { text += frame }
        return text
    }
}
