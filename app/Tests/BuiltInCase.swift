import XCTest
@testable import OpenspotCore

@MainActor
class BuiltInCase: XCTestCase {
    final class MacSettings: @unchecked Sendable {
        var isOn = false
        var login: LoginItem?
        var link: CommandLink?
        var elevated: [String] = []
        var copied: [String] = []
        var opened: [URL] = []
    }

    var root: URL!
    var spots: URL!
    var core: URL!
    var tools: URL!
    let app = FakeRunningApp()
    private(set) var runs: SpotRuns!
    let mac = MacSettings()
    let reads = FakeReads()
    private var socket: CommandSocket?

    var file: ConfigFile {
        ConfigFile(url: root.appendingPathComponent("config.toml"))
    }

    var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
    }

    var guide: URL {
        root.appendingPathComponent("DOCS.md")
    }

    func fake(_ name: String, _ body: String) throws {
        try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
    }

    func countPrograms() throws -> () -> [String] {
        let log = root.appendingPathComponent("programs")
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "echo \"openspot $*\" >> '\(log.path)'\nexec '\(real.path)' \"$@\"")
        try fake("jq", "echo jq >> '\(log.path)'\nexec /usr/bin/jq \"$@\"")
        return { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    }

    func recordEffects() throws -> () -> [String] {
        let log = root.appendingPathComponent("effects")
        let app = tools.appendingPathComponent("openspot-app")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: app)
        try fake("openspot", "case \"$1\" in toast | select | route) echo \"$*\" >> '\(log.path)'; exit 0 ;; esac\nexec '\(app.path)' \"$@\"")
        return { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    }

    var opensAtLogin: Bool {
        mac.isOn
    }

    var linkFile: URL {
        root.appendingPathComponent("bin/openspot")
    }

    func offerLogin() {
        let mac = mac
        mac.login = LoginItem(isOn: { mac.isOn }, set: { mac.isOn = $0 })
    }

    func offerLink() {
        let mac = mac
        mac.link = CommandLink(link: linkFile, target: root.appendingPathComponent("Openspot.app/Contents/Helpers/openspot"), elevated: { mac.elevated.append($0) })
    }

    nonisolated override func invokeTest() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bi-\(UUID().uuidString.prefix(8))")
        let environment = ProcessInfo.processInfo.environment.merging([
            "PATH": root.appendingPathComponent("tools").path + ":/usr/bin:/bin",
            "OPENSPOT_CONFIG": root.path,
            "OPENSPOT_SPOTS": root.appendingPathComponent("spots").path,
            "OPENSPOT_CORE": root.appendingPathComponent("core").path,
            "OPENSPOT_EXAMPLES": root.appendingPathComponent("examples").path
        ]) { _, new in new }
        TestEnvironment.$values.withValue(environment) { super.invokeTest() }
    }

    override func setUp() async throws {
        root = URL(fileURLWithPath: try XCTUnwrap(TestEnvironment.values["OPENSPOT_CONFIG"]))
        root = try XCTUnwrap(root.lastPathComponent.hasPrefix("bi-") ? root : nil, "the environment of the case did not reach setUp")
        spots = root.appendingPathComponent("spots")
        core = root.appendingPathComponent("core")
        tools = root.appendingPathComponent("tools")
        runs = SpotRuns(environment: TestEnvironment.values, log: CallLog(folder: root.appendingPathComponent("logs")), stats: root.appendingPathComponent("stats"))
        for folder in [spots!, core!, tools!] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: tools.appendingPathComponent("openspot"))
        socket = CommandSocket(folder: root, api: CommandAPI(mac: Mac(calendar: FakeCalendar(), reminders: FakeReminders(), reads: reads, login: { [mac] in mac.login }, link: { [mac] in mac.link }, guide: guide, theme: repoSpots.deletingLastPathComponent().appendingPathComponent("app/Themes/openspot.theme/theme.toml"), openText: { [mac] in mac.opened.append($0) }), places: .test(TestEnvironment.values), app: app, runs: runs))
    }

    override func tearDown() async throws {
        socket?.close()
        try? FileManager.default.removeItem(at: root)
    }

    func spot(_ name: String) throws -> Spot {
        let place = SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots)
        return try XCTUnwrap(try place.scan().scripts.first { $0.id == "openspot/\(name)" })
    }

    func script(_ name: String, _ toml: String) throws {
        try "#!/bin/sh\n".writeScript(to: spots.spotFile((name as NSString).deletingPathExtension), toml: toml)
    }
}
