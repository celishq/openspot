import Foundation

/// The `sandbox-exec` words that run a spot's process in Careful mode (Z8): it reads everywhere, writes only to its data
/// folder and the temp folder unless its uses name `files`, and reaches no network unless they name `network`.
struct CarefulMode: Equatable, Sendable {
    private static let program = "/usr/bin/sandbox-exec"

    let uses: Set<SpotUse>

    /// The words before the program, with the data folder and the temp folder of the process.
    func words(data: String, temp: String) -> [String] {
        var rules = ["(version 1)", "(allow default)"]
        if !uses.contains(.network) {
            rules += ["(deny network-outbound (remote ip))", "(deny network-inbound (local ip))"]
        }
        if !uses.contains(.files) {
            rules += [
                "(deny file-write*)",
                "(allow file-write* (subpath (param \"DATA\")) (subpath (param \"TEMP\")) (subpath \"/private/tmp\") (subpath \"/dev\"))"
            ]
        }
        return [Self.program, "-D", "DATA=\(Self.real(data))", "-D", "TEMP=\(Self.real(temp))", "-p", rules.joined(separator: "\n")]
    }

    /// The path with each link resolved, as the sandbox sees it, such as `/private/var` for `/var`.
    private static func real(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
