import Foundation

/// What a call of `openspot` prints and the code it exits with, as its process gives them.
public struct CommandAnswer: Equatable, Sendable {
    public let output: String
    public let errors: String
    public let code: Int32

    public init(output: String = "", errors: String = "", code: Int32 = 0) {
        self.output = output
        self.errors = errors
        self.code = code
    }

    /// The answer of a failed call: its reason on stderr and code 1, with the link to its fix on stdout when it has one.
    init(failure error: Error) {
        let link = if case PluginError.failedWithFix(_, _, let link) = error { "link=\(link.absoluteString)\n" } else { "" }
        self.init(output: link, errors: "\((error as? PluginError)?.reason ?? error.localizedDescription)\n", code: 1)
    }
}
