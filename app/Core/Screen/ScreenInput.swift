import Foundation

/// A sound or a camera that a recording takes beside its source (S4). An id names a device from `openspot screen sources`,
/// and none means the one that macOS uses now.
public enum ScreenInput: Equatable, Sendable {
    case mic(String?)
    case system
    case camera(String?)

    static let kinds: Set<String> = ["mic", "system", "camera"]

    /// Reads one input word, such as `mic`, `system` or `camera:<id>`. Returns nil for anything else.
    init?(word: String) {
        let (kind, value) = ScreenSource.split(word)
        guard value?.isEmpty != true else { return nil }
        switch (kind, value) {
        case ("mic", _): self = .mic(value)
        case ("system", nil): self = .system
        case ("camera", _): self = .camera(value)
        default: return nil
        }
    }

    var kind: String {
        switch self {
        case .mic: "mic"
        case .system: "system"
        case .camera: "camera"
        }
    }
}
