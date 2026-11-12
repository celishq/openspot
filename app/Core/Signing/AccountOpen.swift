import Foundation

/// The step that `openspot account <verb>` opens the account sheet on.
public enum AccountOpen: String, Sendable, CaseIterable {
    /// The choice between a new account and an existing one.
    case setUp = "set-up"
    case signIn = "sign-in"
    case words
    case signOut = "sign-out"

    /// The step of the window.
    public var step: AccountFlow.Step {
        switch self {
        case .setUp: .choose
        case .signIn: .restore
        case .words: .words
        case .signOut: .signOut
        }
    }
}
