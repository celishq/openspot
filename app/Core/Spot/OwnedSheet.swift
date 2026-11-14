import Foundation

/// A sheet that the app makes for one spot, which grows from that spot's card: its Settings or its Edit sheet. Its ID is
/// the spot's ID and a mark that no file name holds, so that it never meets the ID of a spot.
public enum OwnedSheet: String, Sendable {
    case settings
    case edit

    private static let mark: Character = "\u{1F}"

    /// The ID of this sheet of a spot.
    public func id(of spot: String) -> String {
        "\(spot)\(Self.mark)\(rawValue)"
    }

    /// The spot and the kind of an owned sheet's ID, or nil for the ID of a spot.
    public static func owner(of id: String) -> (spot: String, sheet: OwnedSheet)? {
        guard let mark = id.lastIndex(of: mark), let sheet = OwnedSheet(rawValue: String(id[id.index(after: mark)...])) else { return nil }
        return (String(id[..<mark]), sheet)
    }
}
