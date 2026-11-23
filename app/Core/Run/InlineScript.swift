import Foundation
import JavaScriptCore

final class InlineScript: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        var answer = CommandAnswer()
    }

    private final class Held: @unchecked Sendable {
        let value: JSValue?

        init(_ value: JSValue?) {
            self.value = value
        }
    }

    private struct Waiting {
        let call: InlineCall
        let caller: SpotCaller?
        var spent: TimeInterval = 0
        var asks = 0
    }

    private typealias Termination = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Bool
    private typealias TimeLimit = @convention(c) (OpaquePointer?, Double, Termination?, UnsafeMutableRawPointer?) -> Void

    private static let timeLimit: TimeLimit? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "JSContextGroupSetExecutionTimeLimit")
        .map { unsafeBitCast($0, to: TimeLimit.self) }

    private static let overTime: Termination = { _, script in
        guard let script else { return true }
        Unmanaged<InlineScript>.fromOpaque(script).takeUnretainedValue().isOverTime = true
        return true
    }

    private static let module = try? NSRegularExpression(pattern: #"(?m)^([ \t]*)export[ \t]+default[ \t]+"#)

    private let url: URL
    private let name: String
    private let spot: Spot
    private let bound: [String: Spot]
    private let shapes: [String: CallShape]
    private lazy var commands = UseCommand.spec(for: spot.uses)
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
    private var settles: [() -> Void] = []
    private var waiting: [Int: Waiting] = [:]
    private var nextToken = 1
    private var isEnded = false
    private var hasThread = false
    private var isOverTime = false
    private var isOverdue = false
    private var running: InlineCall?
    private var deadline = DispatchTime.now()
    private var context: JSContext?
    private var thrown: JSValue?

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
            var idleEnd = Date().addingTimeInterval(idle)
            while calls.isEmpty, settles.isEmpty, !isEnded {
                if condition.wait(until: idleEnd) { continue }
                for (token, held) in waiting where held.call.isStopped || held.call.isDone || held.asks == 0 {
                    waiting[token] = nil
                    if let caller = held.caller { callers?.release(caller) }
                    held.call.finish(.failed(SpotError.failed(1, "\(held.call.arguments.first ?? "A handler") of \(spot.name) waits for a promise that nothing settles, so Openspot ended it.")))
                }
                if waiting.isEmpty { break }
                idleEnd = Date().addingTimeInterval(idle)
            }
            if isEnded || calls.isEmpty && settles.isEmpty {
                let dropped = calls + waiting.values.map(\.call)
                let held = waiting.values.compactMap(\.caller)
                let outcome: InlineCall.Outcome = isOverdue ? .failed(SpotError.timedOut) : .dropped
                calls = []
                settles = []
                waiting = [:]
                context = nil
                hasThread = false
                condition.unlock()
                held.forEach { callers?.release($0) }
                dropped.forEach { $0.finish(outcome) }
                return
            }
            if !settles.isEmpty {
                let settle = settles.removeFirst()
                condition.unlock()
                autoreleasepool { settle() }
                continue
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
                    if let frame = try run(call) { call.finish(.frame(frame)) }
                } catch {
                    call.finish(.failed(error))
                    if context == nil { waiting.keys.forEach { finish($0, .failed(SpotError.timedOut)) } }
                }
            }
            condition.withLock { running = nil }
            spent(Self.threadTime() - start)
        }
    }

    private func arm(_ seconds: TimeInterval) {
        guard let context else { return }
        Self.timeLimit?(JSContextGetGroup(context.jsGlobalContextRef), max(seconds, 0.001), Self.overTime, Unmanaged.passUnretained(self).toOpaque())
    }

    private func slice(_ token: Int, _ work: () -> Void) {
        guard let held = waiting[token] else { return }
        arm(limit - held.spent)
        let start = Self.threadTime()
        work()
        let used = Self.threadTime() - start
        waiting[token]?.spent += used
        do {
            try rethrow()
        } catch SpotError.timedOut {
            for other in waiting.keys { finish(other, .failed(SpotError.timedOut)) }
            return
        } catch {
            return finish(token, .failed(error))
        }
        if let held = waiting[token], held.spent > limit { finish(token, .failed(SpotError.timedOut)) }
    }

    private func finish(_ token: Int, _ outcome: InlineCall.Outcome) {
        guard let held = waiting.removeValue(forKey: token) else { return }
        if let caller = held.caller { callers?.release(caller) }
        held.call.finish(outcome)
    }

    private func settle(_ token: Int, _ work: @escaping () -> Void) {
        condition.withLock {
            guard !isEnded else { return }
            settles.append { [self] in
                let start = Self.threadTime()
                slice(token, work)
                spent(Self.threadTime() - start)
            }
            condition.signal()
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

    private func run(_ call: InlineCall) throws -> String? {
        let context = try loaded()
        guard let name = call.arguments.first, let handlers = handlers(in: context), Self.isFunction(handlers.objectForKeyedSubscript(name), in: context) else { return "" }
        handle(call, name: name, handlers: handlers, in: context)
        return nil
    }

    private func handlers(in context: JSContext) -> JSValue? {
        guard let handlers = context.objectForKeyedSubscript("openspot")?.objectForKeyedSubscript("handlers"), handlers.isObject else { return nil }
        return handlers
    }

    private static func isFunction(_ value: JSValue?, in context: JSContext) -> Bool {
        guard let value, let type = context.objectForKeyedSubscript("Function") else { return false }
        return value.isInstance(of: type)
    }

    private func handle(_ call: InlineCall, name: String, handlers: JSValue, in context: JSContext) {
        let fields = TextBlock.blocks(in: call.input ?? "").flatMap(\.fields)
        let input = Self.values(of: fields, prefix: "input.", types: shapes[name]?.inputs ?? [])
        let settings = Self.values(of: fields, prefix: "setting.", types: spot.settings.map(\.parameter))
        let token = nextToken
        nextToken += 1
        let caller = callers?.issue(for: spot, reason: call.reason)
        caller?.call = call.opened
        waiting[token] = Waiting(call: call, caller: caller)
        let done: @convention(block) (JSValue, JSValue) -> Void = { [weak self] isDone, text in
            let text = text.toString() ?? ""
            self?.finish(token, isDone.toBool() ? .frame(text) : .failed(SpotError.failed(1, text)))
        }
        let openspot = context.objectForKeyedSubscript("openspot")
        slice(token) {
            let env = openspot?.invokeMethod("env", withArguments: [token, commands, spot.bindings.map(\.name), settings])
            openspot?.invokeMethod("handle", withArguments: [handlers, name, input, env as Any, JSValue(object: done, in: context) as Any])
        }
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
            let typed = texts.map(type.script)
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
        Self.timeLimit?(JSContextGetGroup(context.jsGlobalContextRef), limit, Self.overTime, Unmanaged.passUnretained(self).toOpaque())
        let ask: @convention(block) (JSValue, JSValue) -> [String: Any] = { [weak self] argv, input in
            let arguments = (argv.toArray() ?? []).map { "\($0)" }
            let text = input.isUndefined || input.isNull ? nil : input.toString()
            let answer = self?.ask(arguments, input: text) ?? CommandAnswer(code: 1)
            return ["stdout": answer.output, "code": answer.code]
        }
        let asked: @convention(block) (JSValue, JSValue) -> JSValue? = { [weak self] token, argv in
            let arguments = (argv.toArray() ?? []).map { "\($0)" }
            return self?.asked(arguments, token: Int(token.toInt32()))
        }
        let openspot = JSValue(newObjectIn: context)
        openspot?.setObject(ask, forKeyedSubscript: "call" as NSString)
        openspot?.setObject(asked, forKeyedSubscript: "ask" as NSString)
        context.setObject(openspot, forKeyedSubscript: "openspot" as NSString)
        guard let library = Bundle(for: InlineScript.self).url(forResource: "InlineScript", withExtension: "js"),
              let shared = try? String(contentsOf: library, encoding: .utf8) else { throw SpotError.failed(1, "Openspot cannot find its JavaScript library.") }
        context.evaluateScript(shared, withSourceURL: library)
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
        return answer(work(arguments, input: input, caller: caller, reason: nil, variables: [:]))
    }

    private func asked(_ arguments: [String], token: Int) -> JSValue? {
        guard let context = JSContext.current() else { return nil }
        guard let held = waiting[token] else { return JSValue(newPromiseRejectedWithReason: "The call of \(spot.name) has ended.", in: context) }
        waiting[token]?.asks += 1
        let work = work(arguments, input: nil, caller: held.caller, reason: held.call.reason, variables: held.call.variables)
        var resolve: JSValue?
        let promise = JSValue(newPromiseIn: context) { found, _ in resolve = found }
        let settled = Held(resolve)
        Task.detached(priority: .userInitiated) { [weak self] in
            let answer = await work()
            self?.settle(token) { [weak self] in
                guard let self else { return }
                waiting[token]?.asks -= 1
                settled.value?.call(withArguments: [answered(arguments, answer)])
            }
        }
        return promise
    }

    private func work(_ arguments: [String], input: String?, caller: SpotCaller?, reason: String?, variables: [String: String]) -> CommandAPI.Work {
        let own = [CallWords.spotVariable: name].merging(variables) { _, new in new }
        guard let call = CommandLineCall(arguments: arguments, spot: own[CallWords.spotVariable], reason: reason) else {
            return { CommandAnswer(errors: "openspot needs a call, such as calc solve 2+2.\n", code: 2) }
        }
        let request = CommandRequest(arguments: arguments, folder: base["PWD"] ?? FileManager.default.currentDirectoryPath, caller: caller)
        if let api, api.work(for: call, request: request, input: { input ?? "" }) != nil,
           let work = api.work(for: api.admit(call, request: request), request: request, input: { input ?? "" }) {
            return work
        }
        let child = ScriptProcess(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["openspot"] + arguments, mode: .once(input: input), dataName: dataName, variables: own, careful: careful?.uses, base: base)
        child.channel = caller.flatMap { callers?.channel(for: $0) }
        return { await Self.answer(of: child) }
    }

    private func answered(_ arguments: [String], _ answer: CommandAnswer) -> [String: Any] {
        var result: [String: Any] = ["code": answer.code, "output": answer.output, "errors": answer.errors.hasSuffix("\n") ? String(answer.errors.dropLast()) : answer.errors]
        if arguments.first == RunCall.noun.name, arguments.count > 1, answer.code == 0 {
            let action = RunCall.target(arguments[1]).flatMap { target in try? bound[target.binding]?.action(target.action) }
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
            return CommandAnswer(output: (frames + (child.failedFrame.map { [$0] } ?? [])).joined(separator: SheetFrames.mark + "\n"), errors: child.errors, code: code)
        } catch let error as SpotError {
            return CommandAnswer(errors: error.reason + "\n", code: 1)
        } catch {
            return CommandAnswer(errors: error.localizedDescription, code: 127)
        }
    }
}
