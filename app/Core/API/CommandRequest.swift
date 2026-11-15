import Foundation

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
    let isPiped: Bool

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

    func environment(over base: [String: String]) -> [String: String] {
        base.filter { !$0.key.hasPrefix("OPENSPOT_") }.merging(environment.merging(["PWD": folder]) { _, real in real }) { _, caller in caller }
    }
}
