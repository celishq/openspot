import Foundation

public struct ScreenDevice: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case display
        case window
        case mic
        case camera
    }

    static let system = "system"

    public let kind: Kind
    public let id: String
    public let name: String
    public let detail: String?
    public let app: String?

    public init(kind: Kind, id: String, name: String, detail: String? = nil, app: String? = nil) {
        self.kind = kind
        self.id = id
        self.name = name
        self.detail = detail
        self.app = app
    }

    var row: TextBlock {
        let (detail, icon) = switch kind {
        case .display: ("Display" + (self.detail.map { " · \($0)" } ?? ""), "display")
        case .window: (self.detail ?? "", app ?? "macwindow")
        case .mic: ("Microphone", "mic")
        case .camera: ("Camera", "camera")
        }
        return Self.row("\(kind.rawValue):\(id)", name, detail, icon: icon)
    }

    static func rows(of devices: [ScreenDevice]) -> String {
        let screens = devices.filter { $0.kind == .display || $0.kind == .window }.map(\.row)
        let inputs = devices.filter { $0.kind == .mic || $0.kind == .camera }.map(\.row)
        return (screens + [row(system, "Sound of the Mac", "Sound", icon: "speaker.wave.2")] + inputs).map { $0.text + "\n" }.joined()
    }

    private static func row(_ id: String, _ title: String, _ detail: String, icon: String) -> TextBlock {
        TextBlock(fields: [.init(key: "text", value: id), .init(key: "title", value: title), .init(key: "detail", value: detail), .init(key: "icon", value: icon)])
    }
}
