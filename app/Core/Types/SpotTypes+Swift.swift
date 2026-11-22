import Foundation

extension SpotTypes {
    private static let runtime = """
    struct Failure: Error, CustomStringConvertible {
        let code: Int32
        let description: String
    }

    protocol Outputs {
        var lines: [String] { get }
    }

    struct NoOutputs: Outputs {
        var lines: [String] { [] }
    }

    enum Answer<Output: Outputs> {
        case none
        case frame(String)
        case values(Output)

        var lines: [String] {
            switch self {
            case .none: []
            case .frame(let text): [text]
            case .values(let output): output.lines
            }
        }
    }

    enum Openspot {
        static func run(_ words: [String]) -> (code: Int32, output: String, errors: String) {
            var output: [Int32] = [0, 0]
            var errors: [Int32] = [0, 0]
            guard pipe(&output) == 0, pipe(&errors) == 0 else { return (1, "", "Openspot cannot open a pipe.") }
            var actions: posix_spawn_file_actions_t?
            posix_spawn_file_actions_init(&actions)
            defer { posix_spawn_file_actions_destroy(&actions) }
            posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
            posix_spawn_file_actions_adddup2(&actions, output[1], 1)
            posix_spawn_file_actions_adddup2(&actions, errors[1], 2)
            posix_spawn_file_actions_addclose(&actions, output[0])
            posix_spawn_file_actions_addclose(&actions, errors[0])
            let argv = (["openspot"] + words).map { strdup($0) } + [nil]
            defer { argv.forEach { free($0) } }
            var child: pid_t = 0
            let started = posix_spawnp(&child, "openspot", &actions, nil, argv, environ)
            close(output[1])
            close(errors[1])
            guard started == 0 else {
                close(output[0])
                close(errors[0])
                return (127, "", "Openspot cannot start the openspot command.")
            }
            let texts = drain(output[0], errors[0])
            var status: Int32 = 0
            while waitpid(child, &status, 0) == -1, errno == EINTR {}
            let code = status & 0x7f == 0 ? (status >> 8) & 0xff : 1
            return (code, texts.0, texts.1)
        }

        private static func drain(_ first: Int32, _ second: Int32) -> (String, String) {
            var texts: [[UInt8]] = [[], []]
            var fds = [pollfd(fd: first, events: Int16(POLLIN), revents: 0), pollfd(fd: second, events: Int16(POLLIN), revents: 0)]
            var buffer = [UInt8](repeating: 0, count: 4096)
            var open = 2
            while open > 0 {
                if poll(&fds, 2, -1) < 0, errno != EINTR { break }
                for index in 0..<2 where fds[index].fd >= 0 && fds[index].revents != 0 {
                    let count = read(fds[index].fd, &buffer, buffer.count)
                    if count > 0 {
                        texts[index] += buffer[..<count]
                    } else if count == 0 || errno != EINTR {
                        close(fds[index].fd)
                        fds[index].fd = -1
                        open -= 1
                    }
                }
            }
            return (String(decoding: texts[0], as: UTF8.self), String(decoding: texts[1], as: UTF8.self))
        }

        static func command(_ words: [String]) throws -> String {
            let answer = run(words)
            guard answer.code == 0 else { throw failure(words, answer) }
            return answer.output.hasSuffix("\\n") ? String(answer.output.dropLast()) : answer.output
        }

        static func bound(_ words: [String]) throws -> [String: [String]]? {
            let answer = run(words)
            if answer.code == 4 { return nil }
            guard answer.code == 0 else { throw failure(words, answer) }
            return fields(answer.output, prefix: "out.")
        }

        private static func failure(_ words: [String], _ answer: (code: Int32, output: String, errors: String)) -> Failure {
            let errors = answer.errors.hasSuffix("\\n") ? String(answer.errors.dropLast()) : answer.errors
            return Failure(code: answer.code, description: errors.isEmpty ? "openspot \\(words.joined(separator: " ")) exited \\(answer.code)." : errors)
        }

        static func fields(_ text: String, prefix: String = "") -> [String: [String]] {
            var fields: [String: [String]] = [:]
            for line in text.split(separator: "\\n") {
                guard let equals = line.firstIndex(of: "="), line.hasPrefix(prefix) else { continue }
                fields[String(line[line.index(line.startIndex, offsetBy: prefix.count)..<equals]), default: []].append(unescape(line[line.index(after: equals)...]))
            }
            return fields
        }

        static func escape(_ text: String) -> String {
            var result = ""
            for character in text {
                result += character == "\\\\" ? "\\\\\\\\" : character == "\\n" ? "\\\\n" : String(character)
            }
            return result
        }

        static func unescape(_ text: Substring) -> String {
            var result = ""
            var isEscaped = false
            for character in text {
                if isEscaped {
                    result += character == "n" ? "\\n" : character == "\\\\" ? "\\\\" : "\\\\\\(character)"
                    isEscaped = false
                } else if character == "\\\\" {
                    isEscaped = true
                } else {
                    result.append(character)
                }
            }
            return result
        }

        static func pairs(_ values: [String: String]) -> [String] {
            values.keys.sorted().map { "\\($0)=\\(values[$0] ?? "")" }
        }

        static func line(_ key: String, _ value: String) -> String {
            "out.\\(key)=" + escape(value)
        }

        static func input() -> [String: [String]] {
            var lines: [String] = []
            while let line = readLine() { lines.append(line) }
            return fields(lines.joined(separator: "\\n"))
        }

        static func scoped(_ fields: [String: [String]], _ prefix: String) -> [String: [String]] {
            var scoped: [String: [String]] = [:]
            for (key, values) in fields where key.hasPrefix(prefix) { scoped[String(key.dropFirst(prefix.count))] = values }
            return scoped
        }
    }

    """

    var swift: String {
        var lines = ["import Darwin\n", Self.runtime]
        lines.append(Self.record("Settings", settings, present: \.isRequired, outputs: false))
        for shape in shapes {
            if shape.isLoose {
                lines.append("struct \(Self.typeName(shape.name))Input {\n    let values: [String: [String]]\n\n    init(_ fields: [String: [String]]) {\n        values = fields\n    }\n}\n")
            } else {
                lines.append(Self.record("\(Self.typeName(shape.name))Input", shape.inputs, present: Self.isPresent, outputs: false))
            }
            if !shape.outputs.isEmpty { lines.append(Self.record("\(Self.typeName(shape.name))Output", shape.outputs, present: \.isRequired, outputs: true)) }
        }
        var handlers = ["protocol Handlers {"]
        var defaults = ["extension Handlers {"]
        var cases: [String] = []
        for shape in shapes {
            let output = shape.outputs.isEmpty ? "NoOutputs" : "\(Self.typeName(shape.name))Output"
            let signature = "func `\(Self.key(shape.name))`(_ input: \(Self.typeName(shape.name))Input, _ env: Env) async throws -> Answer<\(output)>"
            handlers.append("    \(signature)")
            defaults.append("    \(signature) {\n        .none\n    }\n")
            cases.append("            case \(Self.quoted(shape.name)): lines = try await handlers.`\(Self.key(shape.name))`(\(Self.typeName(shape.name))Input(input), env).lines")
        }
        lines.append((handlers + ["}", ""]).joined(separator: "\n"))
        lines.append((defaults + ["}", ""]).joined(separator: "\n"))
        lines.append("""
        extension Openspot {
            static func serve(_ handlers: some Handlers) async {
                let fields = input()
                let input = scoped(fields, "input.")
                let env = Env(settings: Settings(scoped(fields, "setting.")))
                do {
                    let lines: [String]
                    switch CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "" {
        \(cases.joined(separator: "\n"))
                    default: lines = []
                    }
                    if !lines.isEmpty { print(lines.joined(separator: "\\n")) }
                } catch {
                    print("error=" + escape("\\(error)"))
                }
            }
        }

        """)
        lines.append(environment)
        return lines.joined(separator: "\n")
    }

    private var environment: String {
        var env = ["struct Env {", "    let settings: Settings"]
        var parts: [String] = []
        for (noun, verbs) in Dictionary(grouping: commands, by: \.noun).sorted(by: { $0.key < $1.key }) {
            env.append("    let `\(Self.key(noun))` = \(Self.typeName(noun))Commands()")
            parts.append((["struct \(Self.typeName(noun))Commands {"] + verbs.map(Self.method) + ["}", ""]).joined(separator: "\n"))
        }
        for binding in spot.bindings {
            env.append("    let `\(Self.key(binding.name))` = \(Self.typeName(binding.name))Binding()")
            parts.append(Self.binding(binding, of: bound[binding.name]))
        }
        if !spot.events.isEmpty {
            env.append("\n    func emit(_ event: Event) async throws {\n        _ = try Openspot.command([\"emit\"] + event.words)\n    }")
            parts.append(event)
        }
        env.append("\n    func open(_ spot: String) async throws {\n        _ = try Openspot.command([\"spot\", \"open\", spot])\n    }")
        return ((env + ["}", ""]) + parts).joined(separator: "\n")
    }

    private var event: String {
        var cases: [String] = []
        var words: [String] = []
        for event in spot.events {
            let labels = event.values.map { "`\(Self.key($0.name))`: \(Self.swiftType($0, present: Self.isPresent($0)))\(Self.isPresent($0) ? "" : " = nil")" }
            cases.append("    case `\(Self.key(event.name))`\(labels.isEmpty ? "" : "(\(labels.joined(separator: ", ")))")")
            let names = event.values.indices.map { "v\($0)" }
            let bindings = names.isEmpty ? "" : "(" + names.map { "let \($0)" }.joined(separator: ", ") + ")"
            let values = zip(event.values, names).map { value, name in
                "\(Self.texts(name, value, present: Self.isPresent(value))).map { \(Self.quoted(value.name + "=")) + $0 }"
            }
            words.append("        case .`\(Self.key(event.name))`\(bindings): [\(Self.quoted(event.name))]\(values.map { " + " + $0 }.joined())")
        }
        return (["enum Event {"] + cases + ["", "    var words: [String] {", "        switch self {"] + words + ["        }", "    }", "}", ""]).joined(separator: "\n")
    }

    private static func method(_ command: UseCommand) -> String {
        var parameters: [String] = []
        var body = ["        var words = [\(command.words.map(quoted).joined(separator: ", "))]"]
        var isOptional = false
        for slot in command.slots where slot.isPositional {
            isOptional = isOptional || !slot.isRequired
            let name = "`\(key(slot.key))`"
            switch slot.kind {
            case .pairs:
                parameters.append("_ \(name): [String: String] = [:]")
                body.append("        words += Openspot.pairs(\(name))")
            case .words:
                parameters.append("_ \(name): [String]\(isOptional ? " = []" : "")")
                body.append("        words += \(name)")
            default:
                if isOptional {
                    parameters.append("_ \(name): String? = nil")
                    body.append("        if let value = \(name) { words.append(value) }")
                } else {
                    parameters.append("_ \(name): String")
                    body.append("        words.append(\(name))")
                }
            }
        }
        for slot in command.slots where !slot.isPositional {
            let name = "`\(key(slot.key))`"
            let option = quoted(slot.option ?? "")
            if slot.kind == .flag {
                parameters.append("\(name): Bool = false")
                body.append("        if \(name) { words.append(\(option)) }")
            } else {
                parameters.append("\(name): String? = nil")
                body.append("        if let value = \(name) { words += [\(option), value] }")
            }
        }
        body.append("        return try Openspot.command(words)")
        return (["    func `\(command.method)`(\(parameters.joined(separator: ", "))) async throws -> String {"] + body + ["    }", ""]).joined(separator: "\n")
    }

    private static func binding(_ binding: Manifest.Binding, of other: Spot?) -> String {
        let name = "\(typeName(binding.name))Binding"
        guard let other else {
            return """
            struct \(name) {
                func run(_ action: String, _ inputs: [String: String] = [:]) async throws -> [String: [String]]? {
                    try Openspot.bound(["run", \(quoted(binding.name + ".")) + action] + Openspot.pairs(inputs))
                }
            }

            """
        }
        var parts = ["struct \(name) {"]
        var records: [String] = []
        for action in other.typedActions {
            let values = "\(typeName(binding.name))\(typeName(action.id))Values"
            let parameters = action.inputs.map { input in
                let given = input.isRequired && input.defaultValue == nil
                return "`\(key(input.name))`: \(swiftType(input, present: given))\(given ? "" : input.type.isList ? " = []" : " = nil")"
            }
            var body = ["        var words = [\"run\", \(quoted("\(binding.name).\(action.id)"))]"]
            for input in action.inputs {
                let given = input.isRequired && input.defaultValue == nil
                body.append("        words += \(texts("`\(key(input.name))`", input, present: given)).map { \(quoted(input.name + "=")) + $0 }")
            }
            body.append("        guard let fields = try Openspot.bound(words) else { return nil }")
            body.append("        return \(values)(fields)")
            parts.append((["    func `\(key(action.id))`(\(parameters.joined(separator: ", "))) async throws -> \(values)? {"] + body + ["    }", ""]).joined(separator: "\n"))
            records.append(record(values, action.outputs, present: \.isRequired, outputs: false))
        }
        return ((parts + ["}", ""]) + records).joined(separator: "\n")
    }

    private static func record(_ name: String, _ parameters: [Manifest.Parameter], present: (Manifest.Parameter) -> Bool, outputs: Bool) -> String {
        var lines = ["struct \(name)\(outputs ? ": Outputs" : "") {"]
        for parameter in parameters {
            let isPresent = present(parameter)
            let type = swiftType(parameter, present: isPresent)
            lines.append(outputs ? "    var `\(key(parameter.name))`: \(type)\(isPresent ? "" : parameter.type.isList ? " = []" : " = nil")" : "    let `\(key(parameter.name))`: \(type)")
        }
        if outputs {
            lines.append("\n    var lines: [String] {\n        var lines: [String] = []")
            for parameter in parameters {
                lines.append("        lines += \(texts("`\(key(parameter.name))`", parameter, present: present(parameter))).map { Openspot.line(\(quoted(parameter.name)), $0) }")
            }
            lines.append("        return lines\n    }")
        } else {
            lines.append("\n    init(_ fields: [String: [String]]) {")
            for parameter in parameters {
                lines.append("        `\(key(parameter.name))` = \(read(parameter, present: present(parameter)))")
            }
            lines.append("    }")
        }
        return (lines + ["}", ""]).joined(separator: "\n")
    }

    private static func swiftType(_ parameter: Manifest.Parameter, present: Bool) -> String {
        let one = switch parameter.type.kind {
        case .number, .duration: "Double"
        case .bool: "Bool"
        default: "String"
        }
        if parameter.type.isList { return "[\(one)]" }
        return present ? one : one + "?"
    }

    private static func read(_ parameter: Manifest.Parameter, present: Bool) -> String {
        let field = "fields[\(quoted(parameter.name))]"
        let convert = switch parameter.type.kind {
        case .number, .duration: ".compactMap { Double($0) }"
        case .bool: ".map { $0 == \"true\" }"
        default: ""
        }
        if parameter.type.isList { return "(\(field) ?? [])\(convert)" }
        let fallback = switch parameter.type.kind {
        case .number, .duration: "0"
        case .bool: "false"
        default: "\"\""
        }
        let one = "(\(field) ?? [])\(convert).last"
        return present ? "\(one) ?? \(fallback)" : one
    }

    private static func texts(_ name: String, _ parameter: Manifest.Parameter, present: Bool) -> String {
        if parameter.type.isList { return "\(name).map { String($0) }" }
        return present ? "[String(\(name))]" : "(\(name).map { [String($0)] } ?? [])"
    }
}
