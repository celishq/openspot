import Foundation

public struct CommandRequest: Equatable, Sendable {
    private struct Line: Decodable {
        struct Params: Decodable {
            let argv: [String]
            let cwd: String
            let piped: Bool?
        }

        let jsonrpc: String
        let id: Int?
        let method: String
        let params: Params
    }

    static let method = "ask"

    public let id: Int?
    public let arguments: [String]
    public let folder: String
    public var caller: SpotCaller?
    public var isFromGroup = false
    public let isPiped: Bool

    public init(arguments: [String], folder: String, caller: SpotCaller? = nil, isPiped: Bool = true, id: Int? = nil) {
        self.id = id
        self.arguments = arguments
        self.folder = folder
        self.caller = caller
        self.isPiped = isPiped
    }

    init?(line: Data) {
        guard let line = try? JSONDecoder().decode(Line.self, from: line), line.jsonrpc == "2.0", line.method == Self.method else { return nil }
        self.init(arguments: line.params.argv, folder: line.params.cwd, isPiped: line.params.piped ?? false, id: line.id)
    }

    var place: URL {
        URL(fileURLWithPath: folder, isDirectory: true)
    }

    func asking(_ arguments: [String]) -> CommandRequest {
        CommandRequest(arguments: arguments, folder: folder, caller: caller)
    }
}
