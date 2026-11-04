import XCTest
@testable import OpenspotCore

final class PluginRunTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws -> Plugin {
        let url = folder.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return Plugin(name: name, api: 1, url: url)
    }

    func testReturnsRowsForTheQuery() async throws {
        let plugin = try writePlugin("echo.sh", """
        #!/bin/sh
        # @name Echo
        # @api 1
        printf '{"title":"%s","run":"true"}\\n' "$1"
        """)

        let result = try await PluginRun(plugin: plugin, query: "hello", timeout: 5).execute()

        XCTAssertEqual(result.rows.map(\.title), ["hello"])
    }

    func testTimesOutASlowPlugin() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\n# @name Slow\n# @api 1\nsleep 5\n")

        do {
            _ = try await PluginRun(plugin: plugin, query: "", timeout: 0.5).execute()
            XCTFail("expected a timeout")
        } catch PluginError.timedOut {
        }
    }
}
