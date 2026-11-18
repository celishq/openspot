import Foundation

public struct CommandAnswer: Equatable, Sendable {
    public let output: String
    public let errors: String
    public let code: Int32
    let fix: URL?

    public init(output: String = "", errors: String = "", code: Int32 = 0) {
        self.init(output: output, errors: errors, code: code, fix: nil)
    }

    private init(output: String, errors: String, code: Int32, fix: URL?) {
        self.output = output
        self.errors = errors
        self.code = code
        self.fix = fix
    }

    init(failure error: Error) {
        let fix: URL? = if case SpotError.failedWithFix(_, _, let link) = error { link } else { nil }
        self.init(output: fix.map { "link=\($0.absoluteString)\n" } ?? "", errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1, fix: fix)
    }
}

extension CommandAnswer {
    static func notRunning(_ call: String) -> CommandAPI.Work {
        {
            let call = "openspot \(call)"
            return CommandAnswer(errors: "`\(call)` needs the Openspot app, and no app answers. Open Openspot, or quit it and open it again if it is open, then run `\(call)` again.\n", code: 3)
        }
    }

    static func work(_ text: @escaping @Sendable () async throws -> String) -> CommandAPI.Work {
        {
            do { return CommandAnswer(output: try await text()) } catch { return CommandAnswer(failure: error) }
        }
    }
}
