import Foundation

public struct CommandAnswer: Equatable, Sendable {
    public let output: String
    public let errors: String
    public let code: Int32

    public init(output: String = "", errors: String = "", code: Int32 = 0) {
        self.output = output
        self.errors = errors
        self.code = code
    }

    init(failure error: Error) {
        let link = if case SpotError.failedWithFix(_, _, let link) = error { "link=\(link.absoluteString)\n" } else { "" }
        self.init(output: link, errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1)
    }
}

extension CommandAnswer {
    static func notRunning(_ call: String) -> CommandAPI.Work {
        {
            let call = "openspot \(call)"
            return CommandAnswer(errors: "`\(call)` needs the Openspot app, and no app answers. Open Openspot, or quit it and open it again if it is open, then run `\(call)` again.\n", code: 1)
        }
    }

    static func work(_ text: @escaping @Sendable () async throws -> String) -> CommandAPI.Work {
        {
            do { return CommandAnswer(output: try await text()) } catch { return CommandAnswer(failure: error) }
        }
    }
}
