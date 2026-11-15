import Foundation

public struct ScreenRecording: Equatable, Sendable {
    public enum State: String, CaseIterable, Sendable {
        case recording
        case ended
        case idle
    }

    public let file: String
    public let camera: String?
    public let events: String?
    public let seconds: Int
    public let state: State
    public let fault: String?
    public let isLogFull: Bool

    public init(file: String, camera: String? = nil, events: String? = nil, seconds: Int = 0, state: State = .recording, fault: String? = nil, isLogFull: Bool = false) {
        self.file = file
        self.camera = camera
        self.events = events
        self.seconds = seconds
        self.state = state
        self.fault = fault
        self.isLogFull = isLogFull
    }

    public init?(block: TextBlock) {
        guard let file = block.value("file") else { return nil }
        self.init(
            file: file, camera: block.value("camera"), events: block.value("events"), seconds: block.value("seconds").flatMap(Int.init) ?? 0,
            state: block.value("state").flatMap(State.init) ?? .recording, fault: block.value("fault"), isLogFull: block.value("log") == Self.full
        )
    }

    private static let full = "full"

    public var block: TextBlock {
        TextBlock(fields: [.init(key: "state", value: state.rawValue)] + files + [.init(key: "seconds", value: String(seconds))] + wire)
    }

    private var wire: [TextBlock.Field] {
        [("fault", fault), ("log", isLogFull ? Self.full : nil)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
    }

    var stopAnswer: CommandAnswer {
        let full = isLogFull ? events.map { "The events in \($0) stop where they reached \(InputLogSpan.byteLimit >> 20) MB.\n" } : nil
        let said = [fault.map { $0 + "\n" }, full].compactMap { $0 }.joined()
        return CommandAnswer(output: paths, errors: said, code: fault == nil ? 0 : 1)
    }

    static func status(of recording: ScreenRecording?) -> String {
        guard let recording else { return TextBlock(fields: [.init(key: "state", value: State.idle.rawValue)]).text }
        return TextBlock(fields: [.init(key: "state", value: recording.state.rawValue)] + recording.files + [.init(key: "seconds", value: String(recording.seconds))]).text
    }

    var paths: String {
        files.map { $0.value + "\n" }.joined()
    }

    private var files: [TextBlock.Field] {
        [("file", file), ("camera", camera), ("events", events)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
    }
}
