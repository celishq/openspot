import Foundation
import JavaScriptCore

final class InlineScript: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        var answer = CommandAnswer()
    }

    private typealias Termination = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Bool
    private typealias TimeLimit = @convention(c) (OpaquePointer?, Double, Termination?, UnsafeMutableRawPointer?) -> Void

    private static let timeLimit: TimeLimit? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "JSContextGroupSetExecutionTimeLimit")
        .map { unsafeBitCast($0, to: TimeLimit.self) }

    private static let frame = """
    openspot.frame = function frame(value) {
      if (Array.isArray(value)) return value.map(frame).join("\\n")
      const write = (one) => String(one).replace(/\\\\/g, "\\\\\\\\").replace(/\\n/g, "\\\\n")
      let text = ""
      for (const [key, each] of Object.entries(value || {})) {
        if (each === undefined || each === null) continue
        for (const one of Array.isArray(each) ? each : [each]) text += `${key}=${write(one)}\\n`
      }
      return text
    }
    """

    private let url: URL
    private let name: String
    private let dataName: String?
    private let base: [String: String]
    private let environment: [String: String]
    private let api: CommandAPI?
    private let callers: SpotCallers?
    private let caller: SpotCaller?
    private let careful: CarefulMode?
    private let limit: TimeInterval
    private let idle: TimeInterval
    private let spent: @Sendable (TimeInterval) -> Void
    private let condition = NSCondition()
    private var calls: [InlineCall] = []
    private var isEnded = false
    private var hasThread = false
    private var isOverTime = false
    private var isOverdue = false
    private var running: InlineCall?
    private var deadline = DispatchTime.now()
    private var context: JSContext?
    private var thrown: JSValue?
    private var variables: [String: String] = [:]

    init(spot: Spot, api: CommandAPI?, callers: SpotCallers? = nil, careful: Set<SpotUse>? = nil, limit: TimeInterval = 10, idle: TimeInterval = 30, base: [String: String] = ProcessInfo.processInfo.environment, spent: @escaping @Sendable (TimeInterval) -> Void = { _ in }) {
        self.careful = careful.map(CarefulMode.init)
        url = spot.url
        name = spot.id
        dataName = spot.dataName
        self.base = base
        self.api = api
        self.limit = limit
        self.idle = idle
        self.spent = spent
        self.callers = callers
        caller = callers?.issue(for: spot)
        environment = ScriptProcess.environment(base: base, app: Bundle.main.executablePath ?? "", dataName: spot.dataName)
            .merging(["OPENSPOT_ID": spot.id]) { _, new in new }
    }

    deinit {
        if let caller { callers?.release(caller) }
    }

    var isRunning: Bool {
        condition.withLock { hasThread }
    }

    var hasEnded: Bool {
        condition.withLock { isEnded }
    }

    func send(_ call: InlineCall) {
        condition.withLock {
            guard !isEnded else { return call.finish(.dropped) }
            calls.append(call)
            if !hasThread {
                hasThread = true
                let thread = Thread { [self] in follow() }
                thread.name = "openspot.inline.\(name)"
                thread.stackSize = 8 << 20
                thread.qualityOfService = .userInitiated
                thread.start()
            }
            condition.signal()
        }
    }

    func end() {
        condition.withLock {
            isEnded = true
            condition.signal()
        }
    }

    private func follow() {
        while true {
            condition.lock()
            let idleEnd = Date().addingTimeInterval(idle)
            while calls.isEmpty, !isEnded, condition.wait(until: idleEnd) {}
            if isEnded || calls.isEmpty {
                let dropped = calls
                let outcome: InlineCall.Outcome = isOverdue ? .failed(SpotError.timedOut) : .dropped
                calls = []
                context = nil
                hasThread = false
                condition.unlock()
                dropped.forEach { $0.finish(outcome) }
                return
            }
            let call = calls.removeFirst()
            condition.unlock()
            guard !call.isStopped else {
                call.finish(.dropped)
                continue
            }
            let start = Self.threadTime()
            deadline = call.limit.map { .now() + $0 } ?? .distantFuture
            condition.withLock { running = call }
            autoreleasepool {
                do {
                    call.finish(.frame(try run(call)))
                } catch {
                    call.finish(.failed(error))
                }
            }
            condition.withLock { running = nil }
            spent(Self.threadTime() - start)
        }
    }

    private func timeOut() {
        let call = condition.withLock {
            isOverdue = true
            isEnded = true
            condition.signal()
            return running
        }
        call?.finish(.failed(SpotError.timedOut))
    }

    private static func threadTime() -> TimeInterval {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { thread_info(pthread_mach_thread_np(pthread_self()), thread_flavor_t(THREAD_BASIC_INFO), $0, &count) }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
        return user + Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
    }

    private func run(_ call: InlineCall) throws -> String {
        let context = try loaded()
        let function = context.objectForKeyedSubscript(call.function ?? "main")
        guard let function, let type = context.objectForKeyedSubscript("Function"), function.isInstance(of: type) else { return "" }
        if call.function != nil {
            let result = function.call(withArguments: call.arguments)
            try rethrow()
            if let result, result.isString { return result.toString() ?? "" }
            return result?.toBool() == true ? "true" : ""
        }
        let env = environment.filter { $0.key == "OPENSPOT_ID" }.merging(call.variables) { _, new in new }
        variables = call.variables
        caller?.reason = call.variables[ReadReason.variable]
        defer {
            variables = [:]
            caller?.reason = nil
        }
        let result = function.call(withArguments: [call.arguments, env, call.input ?? ""])
        try rethrow()
        guard let result, !result.isUndefined, !result.isNull else { return "" }
        return result.toString() ?? ""
    }

    private func loaded() throws -> JSContext {
        if let context { return context }
        guard let context = JSContext() else { throw SpotError.failed(1, "Openspot cannot start JavaScript.") }
        context.exceptionHandler = { [weak self] _, value in self?.thrown = value }
        Self.timeLimit?(JSContextGetGroup(context.jsGlobalContextRef), limit, { _, script in
            guard let script else { return true }
            Unmanaged<InlineScript>.fromOpaque(script).takeUnretainedValue().isOverTime = true
            return true
        }, Unmanaged.passUnretained(self).toOpaque())
        let ask: @convention(block) (JSValue, JSValue) -> [String: Any] = { [weak self] argv, input in
            let arguments = (argv.toArray() ?? []).map { "\($0)" }
            let text = input.isUndefined || input.isNull ? nil : input.toString()
            let answer = self?.ask(arguments, input: text) ?? CommandAnswer(code: 1)
            return ["stdout": answer.output, "code": answer.code]
        }
        let openspot = JSValue(newObjectIn: context)
        openspot?.setObject(ask, forKeyedSubscript: "call" as NSString)
        context.setObject(openspot, forKeyedSubscript: "openspot" as NSString)
        context.evaluateScript(Self.frame)
        let text = try String(contentsOf: url, encoding: .utf8)
        context.evaluateScript(text, withSourceURL: url)
        try rethrow()
        self.context = context
        return context
    }

    private func rethrow() throws {
        if isOverTime {
            isOverTime = false
            thrown = nil
            context = nil
            throw SpotError.timedOut
        }
        guard let value = thrown else { return }
        thrown = nil
        let message = value.objectForKeyedSubscript("message").flatMap { $0.isUndefined ? nil : $0.toString() } ?? value.toString() ?? ""
        throw SpotError.failed(1, message)
    }

    private func ask(_ arguments: [String], input: String?) -> CommandAnswer {
        guard !condition.withLock({ isOverdue }) else { return Self.late }
        let environment = environment.merging(variables) { _, new in new }
        guard let call = CommandLineCall(arguments: arguments, spot: environment[CallWords.spotVariable], reason: environment[CallWords.reasonVariable]) else {
            return CommandAnswer(errors: "openspot needs a call, such as calc solve 2+2.\n", code: 2)
        }
        let request = CommandRequest(arguments: arguments, folder: environment["PWD"] ?? FileManager.default.currentDirectoryPath, caller: caller)
        if let api, api.work(for: call, request: request, input: { input ?? "" }) != nil,
           let work = api.work(for: api.admit(call, request: request), request: request, input: { input ?? "" }) {
            return answer { await work() }
        }
        let child = ScriptProcess(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["openspot"] + arguments, mode: .once(input: input), dataName: dataName, variables: self.environment.filter { $0.key == "OPENSPOT_ID" }.merging(variables) { _, new in new }, careful: careful?.uses, base: base)
        child.channel = caller.flatMap { callers?.channel(for: $0) }
        return answer { await Self.answer(of: child) }
    }

    private static var late: CommandAnswer {
        CommandAnswer(errors: SpotError.timedOut.reason + "\n", code: 1)
    }

    private func answer(_ work: @escaping @Sendable () async -> CommandAnswer) -> CommandAnswer {
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let task = Task.detached(priority: .userInitiated) {
            box.answer = await work()
            done.signal()
        }
        guard done.wait(timeout: deadline) == .success else {
            task.cancel()
            timeOut()
            return Self.late
        }
        return box.answer
    }

    private static func answer(of child: ScriptProcess) async -> CommandAnswer {
        var frames: [String] = []
        do {
            for try await frame in child.start() { frames.append(frame) }
            return CommandAnswer(output: frames.joined(separator: SheetFrames.mark + "\n"), code: 0)
        } catch SpotError.failed(let code, _), SpotError.failedWithFix(let code, _, _) {
            return CommandAnswer(output: (frames + (child.failedFrame.map { [$0] } ?? [])).joined(separator: SheetFrames.mark + "\n"), code: code)
        } catch let error as SpotError {
            return CommandAnswer(errors: error.reason + "\n", code: 1)
        } catch {
            return CommandAnswer(errors: error.localizedDescription, code: 127)
        }
    }
}
