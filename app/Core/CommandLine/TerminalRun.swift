import Foundation

/// A call of one spot that `openspot spot run` makes, with the environment, the arguments and the stdin that a call of the
/// app gets. With no call, it reads a spot that has a `read`, and opens one that has none. A staying script gets the call as
/// a block, and the run ends with the frame that ends that call. A stop of the task that waits for it stops its script.
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
    /// The uses that Careful mode leaves the script, or nil to run it as the person (protocol: Trust).
    let careful: Set<SpotUse>?
    /// The record of the app, which then knows the script's calls of `openspot` as the spot's (protocol: Trust).
    let tokens: CallerTokens?
    /// The environment and the working folder of the caller, or nil for those of this process.
    let environment: [String: String]?
    let folder: URL?

    public init(spot: Spot, arguments: [String], input: String?) {
        self.init(spot: spot, arguments: arguments, input: input, careful: nil, tokens: nil, environment: nil, folder: nil)
    }

    init(spot: Spot, arguments: [String], input: String?, careful: Set<SpotUse>?, tokens: CallerTokens?, environment: [String: String]?, folder: URL?) {
        self.spot = spot
        self.arguments = arguments
        self.input = input
        self.careful = careful
        self.tokens = tokens
        self.environment = environment
        self.folder = folder
    }

    /// The call that this run makes.
    var action: SpotAction {
        SpotAction(arguments: arguments.isEmpty ? (spot.read == nil ? SpotAction.open : SpotAction.read).arguments : arguments)
    }

    /// Makes the call, gives each frame as it comes on the actor of its caller, and returns how the call ended.
    public func start(isolation: isolated (any Actor)? = #isolation, frame: (String) -> Void) async -> End {
        let isRead = action == .read
        if spot.mode == .inline { return await inline(isRead: isRead, frame: frame) }
        let program = SwiftProgram().runnable(for: spot.url, builds: false)
        let token = tokens?.issue(for: spot)
        let variables = ["OPENSPOT_ID": spot.id].merging(isRead ? ReadReason.sheet.variables : [:]) { _, new in new }.merging(token.map { [CallerTokens.variable: $0] } ?? [:]) { _, new in new }
        let process: ScriptProcess
        if spot.mode.stays {
            process = ScriptProcess(url: program, name: spot.url.path, mode: .stays, limit: isRead ? Self.readLimit : nil, dataName: spot.dataName, variables: variables, errorLimit: nil, careful: careful, base: environment, folder: folder)
        } else {
            let sent = action.sent(input: input)
            process = ScriptProcess(url: program, name: spot.url.path, arguments: sent.arguments, mode: .once(input: sent.input), limit: isRead ? Self.readLimit : nil, dataName: spot.dataName, variables: variables, errorLimit: nil, careful: careful, base: environment, folder: folder)
        }
        if let tokens, let token {
            process.onStart { group in tokens.enter(group, token: token) }
            process.onExit { _ in tokens.release(token) }
        }
        return await withTaskCancellationHandler {
            var code: Int32 = 0
            do {
                let frames = process.start()
                if spot.mode.stays { process.send(action, input: input, variables: isRead ? ReadReason.sheet.variables : [:], id: Self.callID) }
                for try await text in frames {
                    if !spot.mode.stays || !SpotOutput(text: text).isMark { frame(text) }
                    if spot.mode.stays, SpotOutput(text: text).summary?.value("end") == String(Self.callID) { process.end() }
                }
            } catch {
                if let last = process.failedFrame { frame(last) }
                code = switch error as? SpotError {
                case .failed(let status, _)?, .failedWithFix(let status, _, _)?: status
                case .timedOut?: 124
                default: 1
                }
                if case .timedOut? = error as? SpotError { return End(code: code, errors: process.errors + "\(spot.name) took too long, so Openspot stopped it.\n") }
                if process.errors.isEmpty, let reason = (error as? SpotError)?.reason ?? Optional(error.localizedDescription) {
                    return End(code: code, errors: reason + "\n")
                }
            }
            return End(code: code, errors: process.errors)
        } onCancel: {
            process.stop()
        }
    }

    /// Runs the call in a JavaScript spot, and gives its frame.
    private func inline(isolation: isolated (any Actor)? = #isolation, isRead: Bool, frame: (String) -> Void) async -> End {
        let script = InlineScript(spot: spot, api: nil, tokens: tokens, careful: careful, limit: Self.readLimit)
        defer { script.end() }
        let call = InlineCall(arguments: action.arguments, variables: ["OPENSPOT_ID": spot.id].merging(isRead ? ReadReason.sheet.variables : [:]) { _, new in new }, input: input)
        script.send(call)
        let outcome = await withTaskCancellationHandler {
            await call.outcome(limit: isRead ? Self.readLimit : nil)
        } onCancel: {
            call.stop()
        }
        switch outcome {
        case .frame(let text):
            if !text.isEmpty { frame(text) }
            return End(code: 0, errors: "")
        case .failed(SpotError.timedOut):
            return End(code: 124, errors: "\(spot.name) took too long, so Openspot stopped it.\n")
        case .failed(let error):
            return End(code: 1, errors: ((error as? SpotError)?.reason ?? error.localizedDescription) + "\n")
        case .dropped:
            return End(code: 1, errors: "\(spot.name) ended before it answered.\n")
        }
    }
}
