import Foundation

/// One `openspot` call that reaches the app: a JSON-RPC 2.0 request on one line, with the method `ask` and the params
/// `argv`, `cwd`, `env` and `piped`: the arguments, the working folder and the variables of the calling process, and whether
/// its stdin is a pipe or a file. An `OPENSPOT_*` variable of a folder or a file that is a relative path is read from the
/// working folder, as the process of the caller reads it, and any other variable, such as `OPENSPOT_ID`, passes as it is.
struct CommandRequest: Equatable {
    private struct Line: Decodable {
        struct Params: Decodable {
            let argv: [String]
            let cwd: String
            let env: [String: String]
            let piped: Bool?
        }

        let jsonrpc: String
        let id: Int?
        let method: String
        let params: Params
    }

    static let method = "ask"
    private static let paths: Set<String> = ["OPENSPOT_CONFIG", "OPENSPOT_DATA", "OPENSPOT_SH", "OPENSPOT_SPOTS", "OPENSPOT_CORE"]

    let id: Int?
    let arguments: [String]
    let folder: String
    let environment: [String: String]
    /// Whether the stdin of the caller is a pipe or a file, which `spot run` passes to the script.
    let isPiped: Bool

    /// Reads a line, or returns nil when it is not a JSON-RPC 2.0 request of the method `ask`.
    init?(line: Data) {
        guard let line = try? JSONDecoder().decode(Line.self, from: line), line.jsonrpc == "2.0", line.method == Self.method else { return nil }
        id = line.id
        arguments = line.params.argv
        folder = line.params.cwd
        let folder = URL(fileURLWithPath: line.params.cwd, isDirectory: true)
        isPiped = line.params.piped ?? false
        environment = Dictionary(uniqueKeysWithValues: line.params.env.map { key, value in
            guard Self.paths.contains(key), !["/", ""].contains(value.first.map(String.init) ?? "") else { return (key, value) }
            return (key, URL(fileURLWithPath: value, relativeTo: folder).standardizedFileURL.path)
        })
    }

    /// The environment of the call: that of the app with the variables of the caller in place of its own, no `OPENSPOT_*`
    /// variable that the caller does not have, and its working folder as `PWD`.
    func environment(over base: [String: String]) -> [String: String] {
        base.filter { !$0.key.hasPrefix("OPENSPOT_") }.merging(environment.merging(["PWD": folder]) { _, real in real }) { _, caller in caller }
    }
}
