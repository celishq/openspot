import Foundation

/// Where a spot comes from: the core spots of the app, the spots folder, the app's own code, or a package of the store.
public enum SpotOrigin: String, Equatable, Sendable {
    case core, mine, builtIn = "builtin", store
}
