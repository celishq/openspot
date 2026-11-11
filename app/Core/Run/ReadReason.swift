import Foundation

/// Why a read runs. A script gets it as `OPENSPOT_REASON`.
public enum ReadReason: String, Sendable {
    case panel
    case sheet
    case timer
    case search
    case change

    /// The variable that carries this reason to a script.
    var variables: [String: String] {
        ["OPENSPOT_REASON": rawValue]
    }
}
