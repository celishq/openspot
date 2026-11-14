import Foundation

public struct ConfigFile: Equatable, Sendable {
    public let url: URL

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ConfigFile {
        ConfigFile(url: SpotsFolder.config(environment: environment, home: home).appendingPathComponent("config.toml"))
    }

    public func read() -> Config {
        Config(text: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
    }

    public func set(_ key: String, to value: String) throws {
        try set(key, line: "\(key) = \"\(value)\"")
    }

    public func set(_ key: String, to isOn: Bool) throws {
        try set(key, line: "\(key) = \(isOn)")
    }

    private func set(_ key: String, line: String) throws {
        try locked {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.last == "" { lines.removeLast() }
            if let index = lines.firstIndex(where: { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == key }) {
                lines[index] = line
            } else {
                lines.insert(line, at: lines.firstIndex { $0.hasPrefix("[[") } ?? lines.endIndex)
            }
            try save(lines.joined(separator: "\n") + "\n")
        }
    }

    public func set(setting key: String, of spot: String, to value: String?) throws {
        try locked {
            let config = read()
            var settings = config.settings
            let new = value.map { SpotSetting(spot: spot, key: key, value: $0) }
            if let place = settings.firstIndex(where: { $0.spot == spot && $0.key == key }) {
                settings.removeAll { $0.spot == spot && $0.key == key }
                if let new { settings.insert(new, at: place) }
            } else if let new {
                settings.append(new)
            }
            try writeTables(config.arrangement, keys: config.keys, settings: settings)
        }
    }

    public func write(_ arrangement: SpotArrangement) throws {
        try locked {
            let config = read()
            try writeTables(arrangement, keys: config.keys, settings: config.settings)
        }
    }

    public func write(keys: [GlobalKey]) throws {
        try locked {
            let config = read()
            try writeTables(config.arrangement, keys: keys, settings: config.settings)
        }
    }

    public func assign(_ trigger: Trigger?, to spot: String, act: GlobalKey.Act) throws {
        try locked {
            let config = read()
            var keys = config.keys
            if trigger == .shake { keys.removeAll { $0.trigger == .shake && ($0.spot != spot || $0.act != act) } }
            let place = keys.firstIndex { $0.spot == spot && $0.act == act }
            let key = trigger.map { GlobalKey(spot: spot, act: act, trigger: $0) }
            switch (place, key) {
            case (let place?, let key?): keys[place] = key
            case (let place?, nil): keys.remove(at: place)
            case (nil, let key?): keys.append(key)
            case (nil, nil): break
            }
            try writeTables(config.arrangement, keys: keys, settings: config.settings)
        }
    }

    private func writeTables(_ arrangement: SpotArrangement, keys: [GlobalKey], settings values: [SpotSetting]) throws {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        _ = try TomlDocument(text: text)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var settings = Array(lines.prefix { !$0.hasPrefix("[[") })
        while settings.last == "" { settings.removeLast() }
        let tables = ([arrangement.text] + keys.map(\.text) + values.map(\.text)).filter { !$0.isEmpty }.joined(separator: "\n\n")
        try save((settings + (settings.isEmpty ? [] : [""]) + [tables]).joined(separator: "\n") + "\n")
    }

    public func begin(enabling ids: [String]) throws {
        try locked {
            guard !FileManager.default.fileExists(atPath: url.path) else { return }
            var arrangement = SpotArrangement()
            ids.forEach { arrangement.set(isEnabled: true, of: $0) }
            try save(ids.isEmpty ? "" : arrangement.text + "\n")
        }
    }

    public func turn(_ id: String, on isOn: Bool) throws {
        try locked {
            let config = read()
            var arrangement = config.arrangement
            arrangement.set(isEnabled: isOn, of: id)
            try writeTables(arrangement, keys: config.keys, settings: config.settings)
        }
    }

    public func showInMenuBar(_ id: String, _ isShown: Bool) throws {
        try locked {
            let config = read()
            var arrangement = config.arrangement
            arrangement.set(isInMenuBar: isShown, of: id)
            try writeTables(arrangement, keys: config.keys, settings: config.settings)
        }
    }

    private func save(_ text: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func locked(_ work: () throws -> Void) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = open(folder.appendingPathComponent(".\(url.lastPathComponent).lock").path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard lock >= 0 else { throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: folder.path]) }
        defer { close(lock) }
        flock(lock, LOCK_EX)
        defer { flock(lock, LOCK_UN) }
        try work()
    }
}
