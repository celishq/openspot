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
        let link = if case SpotError.failedWithFix(_, _, let link) = error { "link=\(link.absoluteString)\n" } else { "" }
        self.init(output: link, errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1)
    }
}

extension CommandAnswer {
    /// The work of a call that only the running app can answer, when no app answers. `call` is its words, such as
    /// `spot store`.
    static func notRunning(_ call: String) -> CommandAPI.Work {
        {
            let call = "openspot \(call)"
            return CommandAnswer(errors: "`\(call)` needs the Openspot app, and no app answers. Open Openspot, or quit it and open it again if it is open, then run `\(call)` again.\n", code: 1)
        }
    }

    /// The work that prints what the text work returns, and fails as `init(failure:)` says.
    static func work(_ text: @escaping @Sendable () async throws -> String) -> CommandAPI.Work {
        {
            do { return CommandAnswer(output: try await text()) } catch { return CommandAnswer(failure: error) }
        }
    }
}
