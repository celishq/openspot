import Foundation

public struct Handler: Equatable, Sendable {
    private static let text = ValueType(.text)
    private static let alt = Manifest.Parameter(name: "alt", type: ValueType(.text, isList: true), isRequired: false)
    private static let value = Manifest.Parameter(name: "value", type: text, isRequired: false)

    public static let show = Handler(name: "show", inputs: [.init(name: "event", type: ValueType(.choice), isRequired: false, options: ShowEvent.moments)])
    static let press = Handler(name: "press", inputs: [.init(name: "item", type: text)])
    static let command = Handler(name: "command", inputs: [.init(name: "name", type: text), .init(name: "text", type: text)])
    static let search = Handler(name: "search", inputs: [.init(name: "text", type: text), alt])
    static let every = Handler(name: "every", inputs: [])
    static let schedule = Handler(name: "schedule", inputs: [.init(name: "cron", type: text), .init(name: "late", type: ValueType(.duration))])
    static let drop = Handler(name: "drop", inputs: [.init(name: "file", type: ValueType(.file, isList: true))])
    static let drag = Handler(name: "drag", inputs: [.init(name: "item", type: ValueType(.text, isList: true))])
    static let sheetText = Handler(name: SpotEvent.sheetText, inputs: [value, alt])
    static let all = [show, press, command, search, every, schedule, drop, drag]

    public let name: String
    let inputs: [Manifest.Parameter]

    static func event(_ name: String) -> Handler {
        name == sheetText.name ? sheetText : Handler(name: name, inputs: [value])
    }

    func message(_ values: [String]..., after given: [TextBlock.Field] = [], then carried: [TextBlock.Field] = []) -> Message {
        let own = zip(inputs, values).flatMap { input, values in values.map { TextBlock.Field(key: input.name, value: $0) } }
        return Message(name, inputs: given + own + carried)
    }
}
