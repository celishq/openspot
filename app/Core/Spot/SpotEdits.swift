import Foundation

public enum SpotEdits: String, Sendable {
    case spots
    case keys
    case launch

    public static func page(of spot: String) -> String {
        "spot:\(spot)"
    }
}
