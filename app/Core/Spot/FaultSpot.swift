import Foundation

public struct FaultSpot: Equatable, Sendable {
    public static let fileID = "openspot/faults"
    static let fixPart = "fix"
    static let editPart = "edit"

    public let file: URL
    public let name: String
    public let faults: [String]
    let prompt: AgentPrompt

    public init(file: URL, name: String, faults: [String], prompt: AgentPrompt) {
        self.file = file
        self.name = name
        self.faults = faults
        self.prompt = prompt
    }

    public func answer(_ arguments: [String]) async throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case Self.fixPart:
            let toast = try await prompt.copy(prompt.fixing(file, faults: faults))
            return TextBlock(fields: [.init(key: "toast", value: toast)]).text
        case Self.editPart:
            _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", "-t", file.path])
            return ""
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private var sheet: String {
        [
            TextBlock(fields: [.init(key: "grid", value: "fault fault"), .init(key: "grid", value: "\(Self.editPart) \(Self.fixPart)")]),
            TextBlock(fields: [
                .init(key: "field", value: "fault"),
                .init(key: "readonly", value: "true"),
                .init(key: "value", value: ([file.path] + faults).joined(separator: "\n\n"))
            ]),
            TextBlock(fields: [
                .init(key: "button", value: Self.editPart),
                .init(key: "title", value: "Edit"),
                .init(key: "shortcut", value: "cmd+e"),
                .init(key: "close", value: "true")
            ]),
            TextBlock(fields: [
                .init(key: "button", value: Self.fixPart),
                .init(key: "title", value: "Copy prompt for AI"),
                .init(key: "shortcut", value: "cmd+return"),
                .init(key: "close", value: "true"),
                .init(key: "look", value: "strong")
            ])
        ].map(\.text).joined(separator: "\n")
    }
}
