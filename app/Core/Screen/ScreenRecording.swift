import Foundation

public struct ScreenRecording: Equatable, Sendable {
    public enum State: String, CaseIterable, Sendable {
        case recording
        case idle
    }

    public let file: String
    public let camera: String?
    public let events: String?
    public let seconds: Int

    public init(file: String, camera: String? = nil, events: String? = nil, seconds: Int = 0) {
        self.file = file
        self.camera = camera
        self.events = events
        self.seconds = seconds
    }

    public init?(block: TextBlock) {
        guard let file = block.value("file") else { return nil }
        self.init(file: file, camera: block.value("camera"), events: block.value("events"), seconds: block.value("seconds").flatMap(Int.init) ?? 0)
    }

    public var block: TextBlock {
        TextBlock(fields: [.init(key: "state", value: State.recording.rawValue)] + files + [.init(key: "seconds", value: String(seconds))])
    }

    static func status(of recording: ScreenRecording?) -> String {
        (recording?.block ?? TextBlock(fields: [.init(key: "state", value: State.idle.rawValue)])).text
    }

    var paths: String {
        files.map { $0.value + "\n" }.joined()
    }

    private var files: [TextBlock.Field] {
        [("file", file), ("camera", camera), ("events", events)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
    }
}
