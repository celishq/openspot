import Foundation

public struct ConfigFile: Equatable, Sendable {
    public let url: URL
    let disk: any ConfigDisk

    public init(url: URL, disk: any ConfigDisk = LocalDisk()) {
        self.url = url
        self.disk = disk
    }

    public static func == (left: ConfigFile, right: ConfigFile) -> Bool {
        left.url == right.url
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ConfigFile {
        standard(in: SpotsFolder.config(environment: environment, home: home))
    }

    static func standard(in folder: URL, disk: any ConfigDisk = LocalDisk()) -> ConfigFile {
        ConfigFile(url: folder.appendingPathComponent("config.toml"), disk: disk)
    }

    public func read() -> Config {
        do {
            return Config(text: try disk.read(url) ?? "")
        } catch {
            return Config(unreadable: error.localizedDescription)
        }
    }

    public func readKept() -> KeptConfig {
        let stamp = disk.readStamp(of: url)
        return KeptConfig(config: read(), stamp: stamp)
    }

    public func readKept(unlessCurrent kept: KeptConfig) -> KeptConfig {
        kept.stamp == disk.readStamp(of: url) ? kept : readKept()
    }

    @discardableResult
    public func change(from kept: KeptConfig? = nil, _ work: (inout Config) throws -> Void) throws -> KeptConfig {
        try locked {
            let old = if let kept, kept.config.isReadable, kept.stamp == disk.readStamp(of: url) {
                kept.config
            } else {
                Config(document: try ConfigDocument(text: try disk.read(url) ?? ""))
            }
            var config = old
            try work(&config)
            guard config != old else { return KeptConfig(config: old, stamp: disk.readStamp(of: url)) }
            let text = config.text
            try disk.write(text, to: url)
            return KeptConfig(config: Config(text: text), stamp: disk.readStamp(of: url))
        }
    }

    public func begin(naming ids: [String]) throws {
        try locked {
            guard try disk.read(url) == nil else { return }
            var config = Config()
            config.arrangement.arrange(ids)
            try disk.write(config.text, to: url)
        }
    }

    private func locked<Result>(_ work: () throws -> Result) throws -> Result {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = open(folder.appendingPathComponent(".\(url.lastPathComponent).lock").path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard lock >= 0 else { throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: folder.path]) }
        defer { close(lock) }
        flock(lock, LOCK_EX)
        defer { flock(lock, LOCK_UN) }
        return try work()
    }
}
