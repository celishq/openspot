import Foundation

struct SpotTypes: Sendable {
    static let scriptFile = "openspot.d.ts"
    static let swiftFile = "Openspot.swift"
    private static let reserved: Set<String> = [
        "break", "case", "catch", "class", "const", "continue", "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally",
        "for", "func", "function", "if", "import", "in", "instanceof", "is", "let", "new", "null", "return", "self", "super", "switch", "this",
        "throw", "true", "try", "typeof", "var", "void", "where", "while", "with", "yield", "Type", "Protocol", "as", "init", "inout", "operator",
        "protocol", "repeat", "static", "struct", "subscript", "throws", "defer", "deinit", "extension", "fileprivate", "guard", "internal",
        "private", "public", "rethrows", "nil", "any", "some", "async", "await"
    ]

    let spot: Spot
    let bound: [String: Spot]

    var shapes: [CallShape] {
        CallShape.all(of: spot, bound: bound)
    }

    var commands: [UseCommand] {
        let bindings = Set(spot.bindings.map(\.name))
        return UseCommand.all(for: spot.uses).filter { !bindings.contains($0.noun) }
    }

    var settings: [Manifest.Parameter] {
        spot.settings.compactMap { setting in setting.valueType.map { Manifest.Parameter(name: setting.id, type: $0, isRequired: setting.defaultValue != nil) } }
    }

    static func key(_ name: String) -> String {
        let key = CommandSlot.identifier([name])
        return reserved.contains(key) ? key + "Value" : key
    }

    static func typeName(_ name: String) -> String {
        let key = CommandSlot.identifier([name])
        return key.prefix(1).uppercased() + key.dropFirst()
    }

    static func isPresent(_ parameter: Manifest.Parameter) -> Bool {
        parameter.isRequired || parameter.defaultValue != nil
    }

    var declarations: String {
        var lines = ["export type Value = string | number | boolean | (string | number | boolean)[]", ""]
        lines.append("export interface Settings \(Self.object(settings, present: \.isRequired))")
        lines.append("")
        lines.append("export interface Inputs {")
        for shape in shapes {
            lines.append("  \(Self.quoted(shape.name)): \(shape.isLoose ? "Record<string, string | string[]>" : Self.object(shape.inputs, present: Self.isPresent))")
        }
        lines += ["}", "", "export interface Outputs {"]
        for shape in shapes where !shape.outputs.isEmpty {
            lines.append("  \(Self.quoted(shape.name)): \(Self.object(shape.outputs, present: \.isRequired))")
        }
        lines += ["}", "", "export interface Events {"]
        for event in spot.events {
            lines.append("  \(Self.quoted(event.name)): \(Self.object(event.values, present: Self.isPresent))")
        }
        lines += ["}", "", "export interface Env {", "  settings: Settings", "  emit<E extends keyof Events>(event: E, values: Events[E]): Promise<void>", "  open(spot: string): Promise<void>"]
        for (noun, verbs) in Dictionary(grouping: commands, by: \.noun).sorted(by: { $0.key < $1.key }) {
            lines.append("  \(Self.quoted(noun)): {")
            for verb in verbs {
                lines.append("    \(verb.method.isEmpty ? "" : Self.quoted(verb.method))(\(Self.parameters(of: verb.slots))): Promise<string>")
            }
            lines.append("  }")
        }
        for binding in spot.bindings {
            guard let other = bound[binding.name] else {
                lines.append("  \(Self.quoted(binding.name)): { [action: string]: (inputs?: Record<string, Value>) => Promise<Record<string, string | string[]> | null> }")
                continue
            }
            lines.append("  \(Self.quoted(binding.name)): {")
            for action in other.typedActions {
                let optional = action.inputs.contains { $0.isRequired && $0.defaultValue == nil } ? "" : "?"
                let inputs = Self.object(action.inputs) { $0.isRequired && $0.defaultValue == nil }
                lines.append("    \(Self.quoted(action.id))(inputs\(optional): \(inputs)): Promise<\(Self.object(action.outputs, present: \.isRequired)) | null>")
            }
            lines.append("  }")
        }
        lines += [
            "}", "",
            "export type Answer<K> = string | Record<string, unknown>[] | (K extends keyof Outputs ? Outputs[K] : never) | void", "",
            "export type Handlers = { [K in keyof Inputs]?: (input: Inputs[K], env: Env) => Answer<K> | Promise<Answer<K>> }", ""
        ]
        return lines.joined(separator: "\n")
    }

    private static func parameters(of slots: [CommandSlot]) -> String {
        var parameters: [String] = []
        var isOptional = false
        for slot in slots where slot.isPositional {
            isOptional = isOptional || !slot.isRequired
            let type = switch slot.kind {
            case .pairs: "Record<string, Value>"
            case .words: "(string | number)[]"
            default: "string | number"
            }
            parameters.append("\(key(slot.key))\(isOptional ? "?" : ""): \(type)")
        }
        let options = slots.filter { !$0.isPositional }
        if !options.isEmpty {
            let fields = options.map { "\(quoted($0.key))?: \($0.kind == .flag ? "boolean" : "string | number | (string | number)[]")" }
            parameters.append("options?: { \(fields.joined(separator: "; ")) }")
        }
        return parameters.joined(separator: ", ")
    }

    private static func object(_ parameters: [Manifest.Parameter], present: (Manifest.Parameter) -> Bool) -> String {
        guard !parameters.isEmpty else { return "{}" }
        return "{ " + parameters.map { "\(quoted($0.name))\(present($0) ? "" : "?"): \(script($0))" }.joined(separator: "; ") + " }"
    }

    private static func script(_ parameter: Manifest.Parameter) -> String {
        let one = switch parameter.type.kind {
        case .number, .duration: "number"
        case .bool: "boolean"
        case .choice: parameter.options.map(quoted).joined(separator: " | ")
        default: "string"
        }
        guard parameter.type.isList else { return one }
        return parameter.type.kind == .choice ? "(\(one))[]" : "\(one)[]"
    }

    static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
