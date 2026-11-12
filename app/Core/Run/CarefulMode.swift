import Foundation

/// The `sandbox-exec` words that run a spot's process in Careful mode (Z8): it reads everywhere, writes only to its data
/// folder, the temp folders, `/private/tmp`, `/dev` and the cache folder unless its uses name `files`, and the folder of
/// screenshots, the Desktop and Movies too when they name `screen`. It reaches no network unless they name `network`, and
/// sends no Apple Event. A file that the app writes for the spot, such as a capture, follows the same folders.
struct CarefulMode: Equatable, Sendable {
    private static let program = "/usr/bin/sandbox-exec"

    let uses: Set<SpotUse>

    /// The words before the program, with the data folder, the temp folder and the home of the process.
    func words(data: String, temp: String, home: String) -> [String] {
        var rules = ["(version 1)", "(allow default)", "(deny appleevent-send)"]
        if !uses.contains(.network) {
            rules += ["(deny network-outbound (remote ip))", "(deny network-inbound (local ip))"]
        }
        let folders = writable(data: data, temp: temp, home: home)
        if let folders {
            rules += ["(deny file-write*)", "(allow file-write* \(folders.map { "(subpath (param \"\($0.name)\"))" }.joined(separator: " ")))"]
        }
        return [Self.program] + (folders ?? []).flatMap { ["-D", "\($0.name)=\($0.path)"] } + ["-p", rules.joined(separator: "\n")]
    }

    /// The words before the program, with the data folder, the temp folder and the home that an environment names.
    func words(in environment: [String: String]) -> [String] {
        words(data: environment["OPENSPOT_DATA"] ?? NSTemporaryDirectory(), temp: environment["TMPDIR"] ?? NSTemporaryDirectory(), home: environment["HOME"] ?? NSHomeDirectory())
    }

    /// Whether a process could write the file, with each link of its folders resolved. A nil data folder allows none.
    func allows(writing file: URL, data: String?, temp: String, home: String) -> Bool {
        guard let folders = writable(data: data, temp: temp, home: home) else { return true }
        let path = Self.real(file.standardizedFileURL.path)
        return folders.contains { path == $0.path || path.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
    }

    /// Each folder that a process may write to, by the name of its parameter in the sandbox, with each link resolved. Nil
    /// when its uses name `files`, which may write anywhere.
    private func writable(data: String?, temp: String, home: String) -> [(name: String, path: String)]? {
        guard !uses.contains(.files) else { return nil }
        var folders = [("TEMP", temp), ("CACHE", Self.cache), ("TMP", "/private/tmp"), ("DEV", "/dev")]
        if let data { folders.insert(("DATA", data), at: 0) }
        if uses.contains(.screen) {
            folders += [("SHOTS", Self.screenshots(home: home)), ("DESKTOP", home + "/Desktop"), ("MOVIES", home + "/Movies")]
        }
        return folders.map { ($0.0, Self.real($0.1)) }
    }

    /// The cache folder of the person, which tools such as `swift` write to.
    private static let cache: String = {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count) > 0 else { return NSTemporaryDirectory() }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }()

    /// The folder where macOS keeps screenshots, or the Desktop of the home with none set.
    private static func screenshots(home: String) -> String {
        guard let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return home + "/Desktop" }
        return (location as NSString).expandingTildeInPath
    }

    /// The path with each link resolved, as the sandbox sees it, such as `/private/var` for `/var`. A path that does not
    /// exist yet resolves its deepest folder that does.
    private static func real(_ path: String) -> String {
        if let resolved = realpath(path, nil) {
            defer { free(resolved) }
            return String(cString: resolved)
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard parent != path, !parent.isEmpty else { return path }
        return (real(parent) as NSString).appendingPathComponent((path as NSString).lastPathComponent)
    }
}
