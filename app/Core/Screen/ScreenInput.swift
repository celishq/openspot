import Foundation

public enum ScreenInput: Equatable, Sendable {
    case mic(String?)
    case system
    case camera(String?)

    static let kinds: Set<String> = ["mic", "system", "camera"]

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

    var word: String {
        switch self {
        case .mic(let id): id.map { "mic:\($0)" } ?? "mic"
        case .system: "system"
        case .camera(let id): id.map { "camera:\($0)" } ?? "camera"
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
