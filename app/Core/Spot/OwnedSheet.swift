import Foundation

public enum OwnedSheet: String, Sendable {
    case settings
    case edit

    private static let mark: Character = "\u{1F}"

    public func id(of spot: String) -> String {
        "\(spot)\(Self.mark)\(rawValue)"
    }

    public static func owner(of id: String) -> (spot: String, sheet: OwnedSheet)? {
        guard let mark = id.lastIndex(of: mark), let sheet = OwnedSheet(rawValue: String(id[id.index(after: mark)...])) else { return nil }
        return (String(id[..<mark]), sheet)
    }
}
