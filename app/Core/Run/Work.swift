import Foundation

@MainActor
public struct Work: Equatable {
    public let spot: String
    public let name: String
    public let call: ScriptCall
    public let isDone: Bool

    init(spot: String, name: String, call: ScriptCall, isDone: Bool = false) {
        self.spot = spot
        self.name = name
        self.call = call
        self.isDone = isDone
    }

    public var words: String {
        call.title ?? "Setting up \(name)"
    }

    public var fill: WorkFill {
        isDone ? .full : call.progress
    }

    func done() -> Work {
        Work(spot: spot, name: name, call: call, isDone: true)
    }

    public nonisolated static func == (lhs: Work, rhs: Work) -> Bool {
        lhs.spot == rhs.spot && lhs.call === rhs.call && lhs.isDone == rhs.isDone
    }
}
