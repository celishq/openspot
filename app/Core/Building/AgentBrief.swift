import Foundation

struct AgentBrief: Equatable, Sendable {
    static let noQuestion = "Don't ask me anything."
    static let openspot = "Openspot is a launcher for the Mac. Its panel shows a card for each spot: a folder with a spot.toml and a script, a JavaScript file or a Swift file. Openspot calls the spot and shows what it prints."

    let app: String
    let task: String
    let place: [String]
    let reading: [String]
    let finish: String
    let rules: [String]
    let request: String

    var text: String {
        """
        \(Self.openspot)
        \(task)

        Where:
        \(Self.list(["The openspot command is \(Self.quoted(app)). Type it in quotes, since its path can hold a space."] + place))

        Read first:
        \(Self.list(reading))

        Rules:
        \(Self.list([Self.noQuestion + " " + finish] + rules))

        My request:
        <request>
        \(request)
        </request>
        """
    }

    static func quoted(_ app: String) -> String {
        "\"\(app)\""
    }

    private static func list(_ lines: [String]) -> String {
        lines.map { "- " + $0.replacingOccurrences(of: "\n", with: "\n  ") }.joined(separator: "\n")
    }
}
