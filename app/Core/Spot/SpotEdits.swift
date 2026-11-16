import Foundation

public enum SpotEdits: String, Sendable {
    case spots
    case keys

    public static func page(of spot: String) -> String {
        "spot:\(spot)"
    }
}
