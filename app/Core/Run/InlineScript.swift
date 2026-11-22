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

    private static let library = """
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
    openspot.value = function value(key, text) {
      const read = (one) => one.replace(/\\\\(n|\\\\)/g, (_, kind) => kind === "n" ? "\\n" : "\\\\")
      return String(text || "").split("\\n").filter((line) => line.startsWith(key + "=")).map((line) => read(line.slice(key.length + 1))).join("\\n")
    }
    openspot.handle = function handle(handlers, name, input, env, done) {
      const fail = (error) => done(false, error && error.message !== undefined ? String(error.message) : String(error))
      let result
      try { result = handlers[name](input, env) } catch (error) { return fail(error) }
      Promise.resolve(result).then((value) => done(true, openspot.answer(value)), fail)
    }
    openspot.answer = function answer(value) {
      if (value === undefined || value === null) return ""
      if (typeof value === "string") return value
      if (Array.isArray(value)) return openspot.frame(value)
      const out = {}
      for (const [key, each] of Object.entries(value)) out["out." + key] = each
      return openspot.frame(out)
    }
    openspot.env = function env(call, spec, bindings, settings) {
      const failure = (argv, answer) => new Error(answer.errors || `openspot ${argv.join(" ")} exited ${answer.code}.`)
      const run = async (argv) => {
        const answer = await openspot.ask(call, argv)
        if (answer.code !== 0) throw failure(argv, answer)
        return answer
      }
      const listed = (value) => (Array.isArray(value) ? value : [value]).filter((one) => one !== undefined && one !== null)
      const pairs = (values) => Object.entries(values || {}).flatMap(([key, each]) => listed(each).map((one) => `${key}=${one}`))
      const words = (slots, args) => {
        const argv = []
        const positional = slots.filter((slot) => !slot.option)
        positional.forEach((slot, index) => {
          const value = args[index]
          if (value === undefined || value === null) return
          if (slot.kind === "pairs") argv.push(...pairs(value))
          else argv.push(...listed(value).map(String))
        })
        const options = args[positional.length] || {}
        for (const slot of slots.filter((slot) => slot.option)) {
          const value = options[slot.key]
          if (value === undefined || value === null || value === false) continue
          if (slot.kind === "flag") argv.push(slot.option)
          else for (const one of listed(value)) argv.push(slot.option, String(one))
        }
        return argv
      }
      const env = { settings }
      for (const [noun, verbs] of Object.entries(spec)) {
        env[noun] = {}
        for (const [method, verb] of Object.entries(verbs)) {
          env[noun][method] = async (...args) => (await run([...verb.words, ...words(verb.slots, args)])).output.replace(/\\n$/, "")
        }
      }
      env.emit = async (event, values) => { await run(["emit", event, ...pairs(values)]) }
      env.open = async (spot) => { await run(["spot", "open", spot]) }
      for (const name of bindings) {
        env[name] = new Proxy({}, {
          get: (_, action) => typeof action !== "string" || action === "then" ? undefined : async (inputs) => {
            const argv = ["run", `${name}.${action}`, ...pairs(inputs)]
            const answer = await openspot.ask(call, argv)
            if (answer.code === 4) return null
            if (answer.code !== 0) throw failure(argv, answer)
            return answer.values
          },
        })
      }
      return env
    }
    """

    private static let module = try? NSRegularExpression(pattern: #"(?m)^([ \t]*)export[ \t]+default[ \t]+"#)

    private let url: URL
    private let name: String
    private let spot: Spot
    private let bound: [String: Spot]
    private let shapes: [String: CallShape]
    private let dataName: String?
    private let base: [String: String]
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
    private var reason: String?

    init(spot: Spot, api: CommandAPI?, callers: SpotCallers? = nil, careful: Set<SpotUse>? = nil, limit: TimeInterval = 10, idle: TimeInterval = 30, bound: [String: Spot] = [:], base: [String: String] = ProcessInfo.processInfo.environment, spent: @escaping @Sendable (TimeInterval) -> Void = { _ in }) {
        self.careful = careful.map(CarefulMode.init)
        url = spot.url
        name = spot.id
        self.spot = spot
        self.bound = bound
        shapes = Dictionary(CallShape.all(of: spot, bound: bound).map { ($0.name, $0) }) { first, _ in first }
        dataName = spot.dataName
        self.base = base
        self.api = api
        self.limit = limit
        self.idle = idle
        self.spent = spent
        self.callers = callers
        caller = callers?.issue(for: spot)
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
        if call.function == nil, let name = call.arguments.first, let handlers = handlers(in: context), Self.isFunction(handlers.objectForKeyedSubscript(name), in: context) {
            return try handle(call, name: name, handlers: handlers, in: context)
        }
        let function = context.objectForKeyedSubscript(call.function ?? "main")
        guard let function, let type = context.objectForKeyedSubscript("Function"), function.isInstance(of: type) else { return "" }
        if call.function != nil {
            let result = function.call(withArguments: call.arguments)
            try rethrow()
            if let result, result.isString { return result.toString() ?? "" }
            return result?.toBool() == true ? "true" : ""
        }
        let env = [CallWords.spotVariable: name].merging(call.variables) { _, new in new }
        enter(call)
        defer { leave() }
        let result = function.call(withArguments: [call.arguments, env, call.input ?? ""])
        try rethrow()
        guard let result, !result.isUndefined, !result.isNull else { return "" }
        return result.toString() ?? ""
    }

    private func enter(_ call: InlineCall) {
        variables = call.variables
        reason = call.reason
        caller?.reason = call.reason
        caller?.call = call.opened
    }

    private func leave() {
        variables = [:]
        reason = nil
        caller?.reason = nil
        caller?.call = nil
    }

    private func handlers(in context: JSContext) -> JSValue? {
        guard let handlers = context.objectForKeyedSubscript("openspot")?.objectForKeyedSubscript("handlers"), handlers.isObject else { return nil }
        return handlers
    }

    private static func isFunction(_ value: JSValue?, in context: JSContext) -> Bool {
        guard let value, let type = context.objectForKeyedSubscript("Function") else { return false }
        return value.isInstance(of: type)
    }

    private func handle(_ call: InlineCall, name: String, handlers: JSValue, in context: JSContext) throws -> String {
        let fields = TextBlock.blocks(in: call.input ?? "").flatMap(\.fields)
        let input = Self.values(of: fields, prefix: "input.", types: shapes[name]?.inputs ?? [])
        let settings = Self.values(of: fields, prefix: "setting.", types: spot.settings.compactMap { setting in setting.valueType.map { Manifest.Parameter(name: setting.id, type: $0) } })
        let openspot = context.objectForKeyedSubscript("openspot")
        let env = openspot?.invokeMethod("env", withArguments: [0, UseCommand.spec(for: spot.uses), spot.bindings.map(\.name), settings])
        var answer: (isDone: Bool, text: String)?
        let done: @convention(block) (JSValue, JSValue) -> Void = { isDone, text in answer = (isDone.toBool(), text.toString() ?? "") }
        enter(call)
        defer { leave() }
        openspot?.invokeMethod("handle", withArguments: [handlers, name, input, env as Any, JSValue(object: done, in: context) as Any])
        try rethrow()
        guard let answer else { return "" }
        guard answer.isDone else { throw SpotError.failed(1, answer.text) }
        return answer.text
    }

    static func values(of fields: [TextBlock.Field], prefix: String, types: [Manifest.Parameter]) -> [String: Any] {
        var grouped: [String: [String]] = [:]
        for field in fields where field.key.hasPrefix(prefix) {
            grouped[String(field.key.dropFirst(prefix.count)), default: []].append(field.value)
        }
        var values: [String: Any] = [:]
        for (name, texts) in grouped {
            guard let type = types.first(where: { $0.name == name })?.type else {
                values[name] = texts.count == 1 ? texts[0] : texts
                continue
            }
            let typed = texts.map { text -> Any in
                switch type.kind {
                case .number, .duration: Double(text) ?? text
                case .bool: text == "true"
                default: text
                }
            }
            values[name] = type.isList ? typed : typed.last
        }
        for type in types where type.type.isList && values[type.name] == nil && type.isRequired {
            values[type.name] = [Any]()
        }
        return values
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
        let asked: @convention(block) (JSValue, JSValue) -> [String: Any] = { [weak self] _, argv in
            let arguments = (argv.toArray() ?? []).map { "\($0)" }
            guard let self else { return ["code": 1, "output": "", "errors": ""] }
            return self.answered(arguments, self.ask(arguments, input: nil))
        }
        let openspot = JSValue(newObjectIn: context)
        openspot?.setObject(ask, forKeyedSubscript: "call" as NSString)
        openspot?.setObject(asked, forKeyedSubscript: "ask" as NSString)
        context.setObject(openspot, forKeyedSubscript: "openspot" as NSString)
        context.evaluateScript(Self.library)
        var text = try String(contentsOf: url, encoding: .utf8)
        text = Self.module?.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1openspot.handlers = ") ?? text
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
        let own = [CallWords.spotVariable: name].merging(variables) { _, new in new }
        guard let call = CommandLineCall(arguments: arguments, spot: own[CallWords.spotVariable], reason: reason) else {
            return CommandAnswer(errors: "openspot needs a call, such as calc solve 2+2.\n", code: 2)
        }
        let request = CommandRequest(arguments: arguments, folder: base["PWD"] ?? FileManager.default.currentDirectoryPath, caller: caller)
        if let api, api.work(for: call, request: request, input: { input ?? "" }) != nil,
           let work = api.work(for: api.admit(call, request: request), request: request, input: { input ?? "" }) {
            return answer { await work() }
        }
        let child = ScriptProcess(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["openspot"] + arguments, mode: .once(input: input), dataName: dataName, variables: own, careful: careful?.uses, base: base)
        child.channel = caller.flatMap { callers?.channel(for: $0) }
        return answer { await Self.answer(of: child) }
    }

    private func answered(_ arguments: [String], _ answer: CommandAnswer) -> [String: Any] {
        var result: [String: Any] = ["code": answer.code, "output": answer.output, "errors": answer.errors.hasSuffix("\n") ? String(answer.errors.dropLast()) : answer.errors]
        if arguments.first == RunCall.noun.name, arguments.count > 1, answer.code == 0 {
            let target = arguments[1]
            let action = bound[Manifest.Triggers.binding(of: target)]?.typedActions.first { $0.id == Manifest.Triggers.event(of: target) }
            let fields = TextBlock.blocks(in: answer.output).flatMap(\.fields).filter { $0.key.hasPrefix(RootKey.outputPrefix) }
            result["values"] = Self.values(of: fields, prefix: RootKey.outputPrefix, types: action?.outputs ?? [])
        }
        return result
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
