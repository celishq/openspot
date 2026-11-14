import Foundation

public enum RecordingRequest: Equatable, Sendable {
    public struct Plan: Equatable, Sendable {
        public var target: ScreenTarget
        public var inputs: [ScreenInput]
        public var cursor: Bool
        public var file: String
        public var camera: String?
        public var events: String?

        public init(target: ScreenTarget, inputs: [ScreenInput], cursor: Bool, file: String, camera: String? = nil, events: String? = nil) {
            self.target = target
            self.inputs = inputs
            self.cursor = cursor
            self.file = file
            self.camera = camera
            self.events = events
        }
    }

    case start(Plan)
    case stop
    case status

    public var text: String {
        switch self {
        case .stop: return "do=stop\n"
        case .status: return "do=status\n"
        case .start(let plan):
            var fields: [TextBlock.Field] = [.init(key: "do", value: "start"), plan.target.field]
            fields += plan.inputs.map { .init(key: "input", value: $0.word) }
            fields += [.init(key: "cursor", value: String(plan.cursor)), .init(key: "file", value: plan.file)]
            fields += [("camera", plan.camera), ("events", plan.events)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
            return TextBlock(fields: fields).text
        }
    }

    public init?(text: String) {
        guard let block = TextBlock.blocks(in: text).first else { return nil }
        switch block.value("do") {
        case "stop": self = .stop
        case "status": self = .status
        case "start":
            guard let target = ScreenTarget(block: block), let file = block.value("file") else { return nil }
            let inputs = block.values("input").compactMap(ScreenInput.init(word:))
            self = .start(Plan(target: target, inputs: inputs, cursor: block.flag("cursor") ?? false, file: file, camera: block.value("camera"), events: block.value("events")))
        default: return nil
        }
    }
}
