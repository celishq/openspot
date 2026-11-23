import Foundation

public struct TerminalRun {
    public struct End: Equatable, Sendable {
        public let code: Int32
        public let errors: String
    }

    private static let showLimit: TimeInterval = 10
    static let errorLimit = 1 << 20
    private static let callID = 1

    public let spot: Spot
    public let handler: String?
    public let input: String?
    let inputs: [TextBlock.Field]
    let settings: [TextBlock.Field]
    let careful: Set<SpotUse>?
    let callers: SpotCallers?
    let environment: [String: String]?
    let folder: URL?
    let usage: StatsLog?

    public init(spot: Spot, handler: String?, input: String?) {
        self.init(spot: spot, handler: handler, input: input, inputs: [], settings: [], careful: nil, callers: nil, environment: nil, folder: nil)
    }

    init(spot: Spot, handler: String?, input: String?, inputs: [TextBlock.Field], settings: [TextBlock.Field], careful: Set<SpotUse>?, callers: SpotCallers?, environment: [String: String]?, folder: URL?, usage: StatsLog? = nil) {
        self.usage = usage
        self.spot = spot
        self.handler = handler
        self.input = input
        self.inputs = inputs
        self.settings = settings
        self.careful = careful
        self.callers = callers
        self.environment = environment
        self.folder = folder
    }

    var called: String {
        handler ?? (spot.hasSheet ? Handler.show.name : Handler.press.name)
    }

    private func message(isInShow: Bool) -> Message {
        var message = isInShow ? ShowEvent.sheet.message(after: inputs) : Message(called, inputs: inputs)
        message.given = input
        message.settings = settings
        return message
    }

    public func start(isolation: isolated (any Actor)? = #isolation, frame: (String) -> Void) async -> End {
        if spot.reachesAccountKey {
            return End(code: 1, errors: "\(spot.name) reaches your account key, so it runs only in the Openspot panel. Open it there.\n")
        }
        let isInShow = called == Handler.show.name
        if spot.mode == .inline { return await inline(isInShow: isInShow, frame: frame) }
        let swift = SwiftProgram()
        let program = swift.runnable(for: spot, builds: false)
        let caller = callers?.issue(for: spot, reason: isInShow ? ShowEvent.sheet.name : nil)
        let process = ScriptProcess(
            spot: spot, program: program, swift: swift, sending: spot.mode.stays ? nil : message(isInShow: isInShow), limit: isInShow ? Self.showLimit : nil,
            errorLimit: Self.errorLimit, careful: careful, base: environment, folder: folder
        )
        usage?.track(process, of: spot.id)
        if let callers, let caller { callers.attach(process, to: caller) }
        return await withTaskCancellationHandler {
            var code: Int32 = 0
            do {
                let frames = process.start()
                if spot.mode.stays { process.send(message(isInShow: isInShow), id: Self.callID) }
                for try await text in frames {
                    let head = spot.mode.stays ? FrameRoot(text: text) : nil
                    if head?.isMark != true { frame(text) }
                    if head?.end == String(Self.callID) { process.end() }
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

    private func inline(isolation: isolated (any Actor)? = #isolation, isInShow: Bool, frame: (String) -> Void) async -> End {
        let script = InlineScript(spot: spot, api: nil, callers: callers, careful: careful, limit: Self.showLimit, base: environment ?? ProcessInfo.processInfo.environment)
        defer { script.end() }
        let call = InlineCall(arguments: [called], variables: ["OPENSPOT_ID": spot.id], input: message(isInShow: isInShow).text, reason: isInShow ? ShowEvent.sheet.name : nil, limit: isInShow ? Self.showLimit : nil)
        script.send(call)
        let outcome = await withTaskCancellationHandler {
            await call.outcome(limit: isInShow ? Self.showLimit : nil)
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
