import Foundation

public enum Restriction: Equatable, Sendable {
    case unknown
    case checked
    case untrusted(TrustGrant)

    var grant: TrustGrant? {
        guard case .untrusted(let grant) = self else { return nil }
        return grant
    }

    var fix: String {
        switch self {
        case .unknown: "Make the call from a spot that names the use, or from Terminal."
        case .checked: "Add it, so that the spot works for each person who adds it."
        case .untrusted: "Trust it in its Settings, or ask its author to add the use."
        }
    }
}
