import Observation

/// What the Openspot item shows over its icon: a symbol in place of the icon, and whether its capsule is lit.
@MainActor
@Observable
final class TrayLook {
    var symbol: String?
    var isLit = false
}
