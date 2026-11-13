import XCTest
@testable import OpenspotCore

/// The spots of the app, as `spots/openspot` holds them. Each one runs as the app runs it, and its `openspot` calls go
/// through the real command to the socket of a test's API, with a config and a spots folder of the test's own.
@MainActor
class BuiltInCase: XCTestCase {
    private final class Host: Mac {
        let mac: MacSettings
        let guide: URL?

        init(mac: MacSettings, guide: URL?) {
            self.mac = mac
            self.guide = guide
        }

        var login: LoginItem? { mac.login }
        var link: CommandLink? { mac.link }

        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    /// The settings of the Mac that a test offers: the login item and the link of the command, and what they did.
    final class MacSettings: @unchecked Sendable {
        var isOn = false
        var login: LoginItem?
        var link: CommandLink?
        var elevated: [String] = []
    }

    private static let names = ["PATH", "OPENSPOT_CONFIG", "OPENSPOT_SPOTS", "OPENSPOT_CORE"]

    var root: URL!
    var spots: URL!
    var core: URL!
    /// The folder of the tools on the path, with `openspot` in it.
    var tools: URL!
    let app = FakeRunningApp()
    /// The runs that start a spot when a test needs the API to know it as the caller, as the app does.
    let runs = SpotRuns()
    let mac = MacSettings()
    private var socket: CommandSocket?
    private var before: [String: String] = [:]

    var file: ConfigFile {
        ConfigFile(url: root.appendingPathComponent("config.toml"))
    }

    /// The folder of the repo's spots, which the app copies into its bundle.
    var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
    }

    /// The guide that `openspot guide` prints, which a test writes when it needs one.
    var guide: URL {
        root.appendingPathComponent("GUIDE.md")
    }

    /// Writes a tool of this name on the path, with this body after its first line.
    func fake(_ name: String, _ body: String) throws {
        try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
    }

    /// Puts a counter in front of `openspot` and `jq` on the path, and returns a reader of the programs that they started, one
    /// line for each.
    func countPrograms() throws -> () -> [String] {
        let log = root.appendingPathComponent("programs")
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "echo \"openspot $*\" >> '\(log.path)'\nexec '\(real.path)' \"$@\"")
        try fake("jq", "echo jq >> '\(log.path)'\nexec /usr/bin/jq \"$@\"")
        return { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    }

    /// Whether the app opens at login, as the API sees it.
    var opensAtLogin: Bool {
        mac.isOn
    }

    /// The link of the command in a folder of the test.
    var linkFile: URL {
        root.appendingPathComponent("bin/openspot")
    }

    /// Gives the API a login item, which the test's Mac keeps.
    func offerLogin() {
        let mac = mac
        mac.login = LoginItem(isOn: { mac.isOn }, set: { mac.isOn = $0 })
    }

    /// Gives the API a link of the command in a folder of the test.
    func offerLink() {
        let mac = mac
        mac.link = CommandLink(link: linkFile, target: root.appendingPathComponent("Openspot.app/Contents/Helpers/openspot"), elevated: { mac.elevated.append($0) })
    }

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("bi-\(UUID().uuidString.prefix(8))")
        spots = root.appendingPathComponent("spots")
        core = root.appendingPathComponent("core")
        tools = root.appendingPathComponent("tools")
        for folder in [spots!, core!, tools!] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: tools.appendingPathComponent("openspot"))
        let environment = ProcessInfo.processInfo.environment
        before = environment.filter { Self.names.contains($0.key) }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        setenv("OPENSPOT_CONFIG", root.path, 1)
        setenv("OPENSPOT_SPOTS", spots.path, 1)
        setenv("OPENSPOT_CORE", core.path, 1)
        socket = CommandSocket(folder: root, api: CommandAPI(mac: Host(mac: mac, guide: guide), app: app, runs: runs))
    }

    override func tearDown() async throws {
        socket?.close()
        for name in Self.names {
            if let value = before[name] { setenv(name, value, 1) } else { unsetenv(name) }
        }
        try? FileManager.default.removeItem(at: root)
    }

    /// The spot of the app in this file of `spots/openspot`, as a scan of the core folder gives it.
    func spot(_ name: String) throws -> Spot {
        let place = SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots)
        return try XCTUnwrap(try place.scan().scripts.first { $0.id == "openspot/\(name)" })
    }

    /// Writes a script with these header lines into the spots folder of the test.
    func script(_ name: String, _ header: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { "# \($0)\n" }.joined()
        try "#!/bin/sh\n\(lines)".writeScript(to: spots.appendingPathComponent(name))
    }
}
