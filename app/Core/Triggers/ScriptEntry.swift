import Foundation

public struct ScriptEntry: Equatable, Sendable {
    private static let text = ValueType(.text)
    private static let alt = Manifest.Parameter(name: "alt", type: ValueType(.text, isList: true), isRequired: false)
    private static let value = Manifest.Parameter(name: "value", type: text, isRequired: false)

    public static let show = ScriptEntry(name: "show", inputs: [.init(name: "event", type: ValueType(.choice), isRequired: false, options: ShowEvent.options)])
    static let press = ScriptEntry(name: "press", inputs: [.init(name: "item", type: text)])
    static let command = ScriptEntry(name: "command", inputs: [.init(name: "name", type: text), .init(name: "text", type: text)])
    static let search = ScriptEntry(name: "search", inputs: [.init(name: "text", type: text), alt])
    static let every = ScriptEntry(name: "every", inputs: [])
    static let schedule = ScriptEntry(name: "schedule", inputs: [.init(name: "cron", type: text), .init(name: "late", type: ValueType(.duration))])
    static let drop = ScriptEntry(name: "drop", inputs: [.init(name: "file", type: ValueType(.file, isList: true))])
    static let drag = ScriptEntry(name: "drag", inputs: [.init(name: "item", type: ValueType(.text, isList: true))])
    static let sheetText = ScriptEntry(name: EventName.sheetText, inputs: [value, alt])
    static let sheetMore = ScriptEntry(name: EventName.sheetMore, inputs: [.init(name: "after", type: text), value])
    static let all = [show, press, command, search, every, schedule, drop, drag]

    public let name: String
    let inputs: [Manifest.Parameter]

    static func event(_ name: String) -> ScriptEntry {
        name == sheetText.name ? sheetText : name == sheetMore.name ? sheetMore : ScriptEntry(name: name, inputs: [value])
    }

    func message(_ values: [String]..., after given: [TextBlock.Field] = [], then carried: [TextBlock.Field] = []) -> Message {
        let own = zip(inputs, values).flatMap { input, values in values.map { TextBlock.Field(key: input.name, value: $0) } }
        return Message(name, inputs: given + own + carried)
    }
}
