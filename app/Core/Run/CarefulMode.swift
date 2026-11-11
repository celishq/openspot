import Foundation

/// The `sandbox-exec` words that run a spot's process in Careful mode (Z8): it reads everywhere, writes only to its data
/// folder, the temp folders, `/private/tmp`, `/dev` and the cache folder unless its uses name `files`, and the folder of
/// screenshots, the Desktop and Movies too when they name `screen`. It reaches no network unless they name `network`, and
/// sends no Apple Event.
struct CarefulMode: Equatable, Sendable {
    private static let program = "/usr/bin/sandbox-exec"

    let uses: Set<SpotUse>

    /// The words before the program, with the data folder, the temp folder and the home of the process.
    func words(data: String, temp: String, home: String) -> [String] {
        var rules = ["(version 1)", "(allow default)", "(deny appleevent-send)"]
        if !uses.contains(.network) {
            rules += ["(deny network-outbound (remote ip))", "(deny network-inbound (local ip))"]
        }
        if !uses.contains(.files) {
            rules += [
                "(deny file-write*)",
                "(allow file-write* (subpath (param \"DATA\")) (subpath (param \"TEMP\")) (subpath (param \"CACHE\")) (subpath \"/private/tmp\") (subpath \"/dev\"))"
            ]
            if uses.contains(.screen) {
                rules.append("(allow file-write* (subpath (param \"SHOTS\")) (subpath (param \"DESKTOP\")) (subpath (param \"MOVIES\")))")
            }
        }
        let shots = Self.screenshots(home: home)
        return [
            Self.program, "-D", "DATA=\(Self.real(data))", "-D", "TEMP=\(Self.real(temp))", "-D", "CACHE=\(Self.real(Self.cache))",
            "-D", "SHOTS=\(Self.real(shots))", "-D", "DESKTOP=\(Self.real(home + "/Desktop"))", "-D", "MOVIES=\(Self.real(home + "/Movies"))", "-p", rules.joined(separator: "\n")
        ]
    }

    /// The words before the program, with the data folder, the temp folder and the home that an environment names.
    func words(in environment: [String: String]) -> [String] {
        words(data: environment["OPENSPOT_DATA"] ?? NSTemporaryDirectory(), temp: environment["TMPDIR"] ?? NSTemporaryDirectory(), home: environment["HOME"] ?? NSHomeDirectory())
    }

    /// The cache folder of the person, which tools such as `swift` write to.
    private static let cache: String = {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count) > 0 else { return NSTemporaryDirectory() }
        return String(cString: buffer)
    }()

    /// The folder where macOS keeps screenshots, or the Desktop of the home with none set.
    private static func screenshots(home: String) -> String {
        guard let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return home + "/Desktop" }
        return (location as NSString).expandingTildeInPath
    }

    /// The path with each link resolved, as the sandbox sees it, such as `/private/var` for `/var`.
    private static func real(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
