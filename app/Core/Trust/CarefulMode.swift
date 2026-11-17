import Foundation

struct CarefulMode: Equatable, Sendable {
    private static let program = "/usr/bin/sandbox-exec"

    let uses: Set<SpotUse>

    func words(data: String, temp: String, home: String, kept: [String] = []) -> [String] {
        var rules = ["(version 1)", "(allow default)", "(deny appleevent-send)"]
        if !uses.contains(.network) {
            rules += ["(deny network-outbound (remote ip))", "(deny network-inbound (local ip))"]
        }
        let folders = writable(data: data, temp: temp, home: home)
        if let folders {
            rules += ["(deny file-write*)", "(allow file-write* \(folders.map { "(subpath (param \"\($0.name)\"))" }.joined(separator: " ")))"]
        }
        let fenced = kept.enumerated().map { (name: "KEPT\($0.offset)", path: Self.real($0.element)) }
        if !fenced.isEmpty {
            rules += ["(deny file-write* \(fenced.map { "(subpath (param \"\($0.name)\"))" }.joined(separator: " ")))", "(allow file-write* (subpath (param \"OWN\")))"]
        }
        let named = (folders ?? []) + fenced + (fenced.isEmpty ? [] : [(name: "OWN", path: Self.real(data))])
        return [Self.program] + named.flatMap { ["-D", "\($0.name)=\($0.path)"] } + ["-p", rules.joined(separator: "\n")]
    }

    func words(in environment: [String: String]) -> [String] {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)
        let kept = [SpotsFolder.config(environment: environment, home: homeURL).path, SpotsFolder.standard(environment: environment, home: homeURL).url.path]
        return words(data: environment["OPENSPOT_DATA"] ?? NSTemporaryDirectory(), temp: environment["TMPDIR"] ?? NSTemporaryDirectory(), home: home, kept: kept)
    }

    func allows(writing file: URL, data: String?, temp: String, home: String) -> Bool {
        guard let folders = writable(data: data, temp: temp, home: home) else { return true }
        let path = Self.real(file.standardizedFileURL.path)
        return folders.contains { path == $0.path || path.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
    }

    private func writable(data: String?, temp: String, home: String) -> [(name: String, path: String)]? {
        guard !uses.contains(.files) else { return nil }
        var folders = [("TEMP", temp), ("CACHE", Self.cache), ("TMP", "/private/tmp"), ("DEV", "/dev")]
        if let data { folders.insert(("DATA", data), at: 0) }
        if uses.contains(.screen) {
            folders += [("SHOTS", Self.screenshots(home: home)), ("DESKTOP", home + "/Desktop"), ("MOVIES", home + "/Movies")]
        }
        return folders.map { ($0.0, Self.real($0.1)) }
    }

    private static let cache: String = {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count) > 0 else { return NSTemporaryDirectory() }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }()

    private static func screenshots(home: String) -> String {
        guard let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return home + "/Desktop" }
        return (location as NSString).expandingTildeInPath
    }

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
