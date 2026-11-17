import Foundation

public enum Restriction: Equatable, Sendable {
    case careful
    case untrusted(TrustGrant)

    var grant: TrustGrant? {
        guard case .untrusted(let grant) = self else { return nil }
        return grant
    }

    var fix: String {
        switch self {
        case .careful: "Add it, or turn Careful mode off."
        case .untrusted: "Trust it in its Settings, or ask its author to add the use."
        }
    }
}
