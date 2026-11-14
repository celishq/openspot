import Foundation

/// Where a spot comes from: the core spots of the app, the spots folder, or the app's own code.
public enum SpotOrigin: Equatable, Sendable {
    case core, mine, builtIn
}
