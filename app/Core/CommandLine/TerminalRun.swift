import Foundation

/// A call of one spot that `openspot spot run` makes, with the environment, the arguments and the stdin that a call of the
/// app gets. With no call, it reads a spot that has a `read`, and opens one that has none. A staying script gets the call as
/// a block, and the run ends with the frame that ends that call.
public struct TerminalRun {
    /// How the call ended: the exit code of the script, and all that it printed on stderr.
    public struct End: Equatable, Sendable {
        public let code: Int32
        public let errors: String
    }

    private static let readLimit: TimeInterval = 10
    private static let callID = 1

    public let spot: Spot
    public let arguments: [String]
    public let input: String?

    public init(spot: Spot, arguments: [String], input: String?) {
        self.spot = spot
        self.arguments = arguments
        self.input = input
    }

    /// The call that this run makes.
    var action: SpotAction {
        SpotAction(arguments: arguments.isEmpty ? (spot.read == nil ? SpotAction.open : SpotAction.read).arguments : arguments)
    }

    /// Makes the call, gives each frame as it comes, and returns how the call ended.
    @MainActor
    public func start(frame: (String) -> Void) async -> End {
        let isRead = action == .read
        if spot.mode == .inline { return await inline(isRead: isRead, frame: frame) }
        let program = SwiftProgram.file(beside: spot.url) ?? spot.url
        let variables = ["OPENSPOT_ID": spot.id].merging(isRead ? ReadReason.sheet.variables : [:]) { _, new in new }
        let process: ScriptProcess
        if spot.mode.stays {
            process = ScriptProcess(url: program, mode: .stays, limit: isRead ? Self.readLimit : nil, dataName: spot.dataName, variables: variables, errorLimit: nil)
        } else {
            let sent = action.sent(input: input)
            process = ScriptProcess(url: program, arguments: sent.arguments, mode: .once(input: sent.input), limit: isRead ? Self.readLimit : nil, dataName: spot.dataName, variables: variables, errorLimit: nil)
        }
        var code: Int32 = 0
        do {
            let frames = process.start()
            if spot.mode.stays { process.send(action, values: input, id: Self.callID, reason: isRead ? .sheet : nil) }
            for try await text in frames {
                frame(text)
                if spot.mode.stays, PluginOutput(text: text).summary?.value("end") == String(Self.callID) { process.end() }
            }
        } catch {
            if let last = process.failedFrame { frame(last) }
            code = switch error as? PluginError {
            case .failed(let status, _)?, .failedWithFix(let status, _, _)?: status
            case .timedOut?: 124
            default: 1
            }
            if case .timedOut? = error as? PluginError { return End(code: code, errors: process.errors + "\(spot.name) took too long, so Openspot stopped it.\n") }
            if process.errors.isEmpty, let reason = (error as? PluginError)?.reason ?? Optional(error.localizedDescription) {
                return End(code: code, errors: reason + "\n")
            }
        }
        return End(code: code, errors: process.errors)
    }

    /// Runs the call in a JavaScript spot, and gives its frame.
    @MainActor
    private func inline(isRead: Bool, frame: (String) -> Void) async -> End {
        let script = InlineScript(spot: spot, api: nil)
        defer { script.end() }
        let call = InlineCall(arguments: action.arguments, reason: isRead ? .sheet : nil, input: input)
        script.send(call)
        switch await call.outcome(limit: isRead ? Self.readLimit : nil) {
        case .frame(let text):
            if !text.isEmpty { frame(text) }
            return End(code: 0, errors: "")
        case .failed(PluginError.timedOut):
            return End(code: 124, errors: "\(spot.name) took too long, so Openspot stopped it.\n")
        case .failed(let error):
            return End(code: 1, errors: ((error as? PluginError)?.reason ?? error.localizedDescription) + "\n")
        case .dropped:
            return End(code: 1, errors: "\(spot.name) ended before it answered.\n")
        }
    }
}
