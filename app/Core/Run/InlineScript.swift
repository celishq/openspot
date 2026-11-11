import Foundation
import JavaScriptCore

/// A JavaScript spot that runs inside the app, in a context of its own on a thread of its own (I3). It makes the thread
/// and loads its file at its first call, and lets go of both after `idle` seconds with no call (A26). Each call runs
/// `main(args, env, input)` with the three parts of the call and returns the text of a frame (I6), and fails as too slow
/// past `limit` (I7). `openspot.call(argv, input)` asks the API and returns `{ stdout, code }` (I4).
final class InlineScript: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        var answer = CommandAnswer()
    }

    private typealias Termination = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Bool
    private typealias TimeLimit = @convention(c) (OpaquePointer?, Double, Termination?, UnsafeMutableRawPointer?) -> Void

    /// `JSContextGroupSetExecutionTimeLimit`, which JavaScriptCore exports with no public header.
    private static let timeLimit: TimeLimit? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "JSContextGroupSetExecutionTimeLimit")
        .map { unsafeBitCast($0, to: TimeLimit.self) }

    /// `openspot.frame(object)`, which writes an object as one block, or a list of objects as blocks, with each value
    /// written as a value: a list repeats its key, and null leaves it out (C8).
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
    private let environment: [String: String]
    private let api: CommandAPI?
    private let tokens: CallerTokens?
    private let token: String?
    /// The sandbox of Careful mode for each process that `openspot.call` starts, or nil to run them as the person.
    private let careful: CarefulMode?
    private let limit: TimeInterval
    private let idle: TimeInterval
    /// Takes the CPU time of each call on the thread.
    private let spent: @Sendable (TimeInterval) -> Void
    private let condition = NSCondition()
    private var calls: [InlineCall] = []
    private var isEnded = false
    private var hasThread = false
    /// Whether the time limit stopped the call that runs.
    private var isOverTime = false
    /// The context of the script, which only its thread touches.
    private var context: JSContext?
    private var thrown: JSValue?
    /// The variables of the call that runs, which `openspot.call` passes on.
    private var variables: [String: String] = [:]

    /// `tokens` gives the script a token of its spot for as long as it lives (Z2). `careful` runs each process that it starts
    /// in Careful mode with these uses (Z8).
    init(spot: Spot, api: CommandAPI?, tokens: CallerTokens? = nil, careful: Set<SpotUse>? = nil, limit: TimeInterval = 10, idle: TimeInterval = 30, spent: @escaping @Sendable (TimeInterval) -> Void = { _ in }) {
        self.careful = careful.map(CarefulMode.init)
        url = spot.url
        name = spot.id
        self.api = api
        self.limit = limit
        self.idle = idle
        self.spent = spent
        self.tokens = tokens
        token = tokens?.issue(for: spot)
        environment = ScriptProcess.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "", dataName: spot.dataName)
            .merging(["OPENSPOT_ID": spot.id]) { _, new in new }
            .merging(token.map { [CallerTokens.variable: $0] } ?? [:]) { _, new in new }
    }

    deinit {
        if let token { tokens?.release(token) }
    }

    /// Whether its thread runs, with its context.
    var isRunning: Bool {
        condition.withLock { hasThread }
    }

    /// Puts a call in line on the thread of the script, and starts the thread when none runs.
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

    /// Ends the thread once the call that runs returns. Each call in line is dropped.
    func end() {
        condition.withLock {
            isEnded = true
            condition.signal()
        }
    }

    /// Runs each call in turn until the end, or until no call comes for `idle` seconds, and then lets go of the context.
    private func follow() {
        while true {
            condition.lock()
            let deadline = Date().addingTimeInterval(idle)
            while calls.isEmpty, !isEnded, condition.wait(until: deadline) {}
            if isEnded || calls.isEmpty {
                let dropped = calls
                calls = []
                context = nil
                hasThread = false
                condition.unlock()
                dropped.forEach { $0.finish(.dropped) }
                return
            }
            let call = calls.removeFirst()
            condition.unlock()
            guard !call.isStopped else {
                call.finish(.dropped)
                continue
            }
            let start = Self.threadTime()
            autoreleasepool {
                do {
                    call.finish(.frame(try run(call)))
                } catch {
                    call.finish(.failed(error))
                }
            }
            spent(Self.threadTime() - start)
        }
    }

    /// The CPU time, user and system, of the thread that asks.
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

    /// Runs `main` with the arguments, the variables and the stdin of the call (I6). A script with no `main` gives an empty
    /// frame.
    private func run(_ call: InlineCall) throws -> String {
        let context = try loaded()
        let function = context.objectForKeyedSubscript("main")
        guard let function, let type = context.objectForKeyedSubscript("Function"), function.isInstance(of: type) else { return "" }
        let env = environment.filter { ["OPENSPOT_ID", CallerTokens.variable].contains($0.key) }.merging(call.variables) { _, new in new }
        variables = call.variables
        defer { variables = [:] }
        let result = function.call(withArguments: [call.arguments, env, call.input ?? ""])
        try rethrow()
        guard let result, !result.isUndefined, !result.isNull else { return "" }
        return result.toString() ?? ""
    }

    /// The context with the file run in it, which it makes at the first call.
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

    /// Throws what the script threw, as the failure of its call. A call that the time limit stopped fails as too slow, and
    /// the next call starts from a new context.
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

    /// Asks the API in the app, or the `openspot` command for a call that runs in a process of its own.
    private func ask(_ arguments: [String], input: String?) -> CommandAnswer {
        let environment = environment.merging(variables) { _, new in new }
        guard let call = CommandLineCall(arguments: arguments, environment: environment) else {
            return CommandAnswer(errors: "openspot needs a call, such as calc solve 2+2.\n", code: 2)
        }
        if let api, api.work(for: call, input: { input ?? "" }, environment: environment) != nil,
           let work = api.work(for: api.admit(call, arguments: arguments, environment: environment), input: { input ?? "" }, environment: environment) {
            let box = Box()
            let done = DispatchSemaphore(value: 0)
            Task.detached(priority: .userInitiated) {
                box.answer = await work()
                done.signal()
            }
            done.wait()
            return box.answer
        }
        return process(arguments, input: input, environment: environment)
    }

    /// Runs the `openspot` command on the path, in Careful mode when it is on, and returns its stdout and its code.
    private func process(_ arguments: [String], input: String?, environment: [String: String]) -> CommandAnswer {
        let words = (careful?.words(in: environment) ?? []) + ["/usr/bin/env", "openspot"] + arguments
        let process = Process()
        process.executableURL = URL(fileURLWithPath: words[0])
        process.arguments = Array(words.dropFirst())
        process.environment = environment
        let output = Pipe()
        let stdin = Pipe()
        process.standardOutput = output
        process.standardInput = stdin
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandAnswer(errors: error.localizedDescription, code: 127)
        }
        let writer = stdin.fileHandleForWriting
        DispatchQueue.global().async {
            if let input { writer.write(Data(input.utf8)) }
            try? writer.close()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandAnswer(output: String(decoding: data, as: UTF8.self), code: process.terminationStatus)
    }
}
