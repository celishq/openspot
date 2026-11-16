import Foundation

public enum SpotEdits: String, Sendable {
    case spots
    case keys

    public static func page(of spot: String) -> String {
        "spot:\(spot)"
    }

    public static func spot(onPage page: String) -> String? {
        page.hasPrefix("spot:") ? String(page.dropFirst(5)) : nil
    }
}
