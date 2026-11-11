import Foundation
import JavaScriptCore

/// A JavaScript spot that runs inside the app, in a context of its own on a thread of its own (I3). It loads its file as
/// it starts. Each call runs the function of its name and returns the text of a frame. `openspot.input` holds the stdin of
/// the call and `openspot.value` the value of its event, and `openspot.call(argv, input)` asks the API and returns
/// `{ stdout, code }` (I4). A loop that never returns keeps its thread.
final class InlineScript: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        var answer = CommandAnswer()
    }

    private let url: URL
    private let environment: [String: String]
    private let api: CommandAPI?
    private let condition = NSCondition()
    private var calls: [InlineCall] = []
    private var isEnded = false
    /// The context of the script, which only its thread touches.
    private var context: JSContext?
    private var thrown: JSValue?
    /// The reason of the call that runs, which `openspot.call` passes on.
    private var reason: ReadReason?

    init(spot: Spot, api: CommandAPI?) {
        url = spot.url
        self.api = api
        environment = ScriptProcess.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "", dataName: spot.dataName)
            .merging(["OPENSPOT_ID": spot.id]) { _, new in new }
        let thread = Thread { [self] in follow() }
        thread.name = "openspot.inline.\(spot.id)"
        thread.stackSize = 8 << 20
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Puts a call in line on the thread of the script.
    func send(_ call: InlineCall) {
        condition.withLock {
            guard !isEnded else { return call.finish(.dropped) }
            calls.append(call)
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

    /// Loads the file, then runs each call in turn until the end.
    private func follow() {
        _ = try? loaded()
        while true {
            condition.lock()
            while calls.isEmpty, !isEnded { condition.wait() }
            if isEnded {
                let dropped = calls
                calls = []
                condition.unlock()
                dropped.forEach { $0.finish(.dropped) }
                context = nil
                return
            }
            let call = calls.removeFirst()
            condition.unlock()
            guard !call.isStopped else {
                call.finish(.dropped)
                continue
            }
            autoreleasepool {
                do {
                    call.finish(.frame(try run(call)))
                } catch {
                    call.finish(.failed(error))
                }
            }
        }
    }

    /// Runs the function that the call names, with the reason first for a read. A name that the script does not define
    /// gives an empty frame.
    private func run(_ call: InlineCall) throws -> String {
        let context = try loaded()
        guard let name = call.arguments.first else { return "" }
        let function = context.objectForKeyedSubscript(name)
        guard let function, let type = context.objectForKeyedSubscript("Function"), function.isInstance(of: type) else { return "" }
        let isRead = name == SpotAction.read.arguments.first
        let arguments = (isRead ? [(call.reason ?? .sheet).rawValue] : []) + call.arguments.dropFirst()
        reason = call.reason
        defer { reason = nil }
        let openspot = context.objectForKeyedSubscript("openspot")
        openspot?.setObject(call.input ?? "", forKeyedSubscript: "input" as NSString)
        openspot?.setObject(call.reason?.value ?? "", forKeyedSubscript: "value" as NSString)
        let result = function.call(withArguments: arguments)
        try rethrow()
        guard let result, !result.isUndefined, !result.isNull else { return "" }
        return result.toString() ?? ""
    }

    /// The context with the file run in it, which it makes at the first call.
    private func loaded() throws -> JSContext {
        if let context { return context }
        guard let context = JSContext() else { throw PluginError.failed(1, "Openspot cannot start JavaScript.") }
        context.exceptionHandler = { [weak self] _, value in self?.thrown = value }
        let ask: @convention(block) (JSValue, JSValue) -> [String: Any] = { [weak self] argv, input in
            let arguments = (argv.toArray() ?? []).map { "\($0)" }
            let text = input.isUndefined || input.isNull ? nil : input.toString()
            let answer = self?.ask(arguments, input: text) ?? CommandAnswer(code: 1)
            return ["stdout": answer.output, "code": answer.code]
        }
        let openspot = JSValue(newObjectIn: context)
        openspot?.setObject(ask, forKeyedSubscript: "call" as NSString)
        context.setObject(openspot, forKeyedSubscript: "openspot" as NSString)
        let text = try String(contentsOf: url, encoding: .utf8)
        context.evaluateScript(text, withSourceURL: url)
        try rethrow()
        self.context = context
        return context
    }

    /// Throws what the script threw, as the failure of its call.
    private func rethrow() throws {
        guard let value = thrown else { return }
        thrown = nil
        let message = value.objectForKeyedSubscript("message").flatMap { $0.isUndefined ? nil : $0.toString() } ?? value.toString() ?? ""
        throw PluginError.failed(1, message)
    }

    /// Asks the API in the app, or the `openspot` command for a call that runs in a process of its own.
    private func ask(_ arguments: [String], input: String?) -> CommandAnswer {
        let environment = environment.merging(reason?.variables ?? [:]) { _, new in new }
        guard let call = CommandLineCall(arguments: arguments, environment: environment) else {
            return CommandAnswer(errors: "openspot needs a call, such as calc solve 2+2.\n", code: 2)
        }
        if let api, let work = api.work(for: call, input: { input ?? "" }, environment: environment) {
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

    /// Runs the `openspot` command on the path, and returns its stdout and its code.
    private func process(_ arguments: [String], input: String?, environment: [String: String]) -> CommandAnswer {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["openspot"] + arguments
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
