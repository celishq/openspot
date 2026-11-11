import Foundation

/// One `openspot` call that reaches the app: a JSON-RPC 2.0 request on one line, with the method `ask` and the params
/// `argv`, `cwd` and `env`, the arguments, the working folder and the `OPENSPOT_*` variables of the calling process. A
/// variable that is a relative path is read from the working folder, as the process of the caller reads it.
struct CommandRequest: Equatable {
    private struct Line: Decodable {
        struct Params: Decodable {
            let argv: [String]
            let cwd: String
            let env: [String: String]
        }

        let jsonrpc: String
        let id: Int?
        let method: String
        let params: Params
    }

    static let method = "ask"

    let id: Int?
    let arguments: [String]
    let folder: String
    let environment: [String: String]

    /// Reads a line, or returns nil when it is not a JSON-RPC 2.0 request of the method `ask`.
    init?(line: Data) {
        guard let line = try? JSONDecoder().decode(Line.self, from: line), line.jsonrpc == "2.0", line.method == Self.method else { return nil }
        id = line.id
        arguments = line.params.argv
        folder = line.params.cwd
        let folder = URL(fileURLWithPath: line.params.cwd, isDirectory: true)
        environment = line.params.env.filter { $0.key.hasPrefix("OPENSPOT_") }.mapValues { value in
            ["/", ""].contains(value.first.map(String.init) ?? "") ? value : URL(fileURLWithPath: value, relativeTo: folder).standardizedFileURL.path
        }
    }

    /// The environment of the call: that of the app, with the `OPENSPOT_*` variables of the caller in place of its own.
    func environment(over base: [String: String]) -> [String: String] {
        base.filter { !$0.key.hasPrefix("OPENSPOT_") }.merging(environment) { _, caller in caller }
    }
}
