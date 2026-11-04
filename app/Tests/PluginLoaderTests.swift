import XCTest
@testable import OpenspotCore

final class PluginLoaderTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func testHeaderReadsNameAndApi() {
        let header = PluginHeader.read("#!/bin/sh\n# @name Links\n# @api 1\necho hi\n")
        XCTAssertEqual(header?.name, "Links")
        XCTAssertEqual(header?.api, 1)
    }

    func testRowParserKeepsValidLinesAndReportsBadOnes() {
        let output = """
        {"title":"Hacker News","subtitle":"news","run":"open https://news.ycombinator.com"}
        not json
        {"title":"Safari","run":"open -a Safari"}
        """
        let result = RowParser.parse(output)
        XCTAssertEqual(result.rows.map(\.title), ["Hacker News", "Safari"])
        XCTAssertEqual(result.rows.first?.subtitle, "news")
        XCTAssertEqual(result.errors.count, 1)
    }

    func testScannerKeepsApiOneAndRefusesUnknownApi() throws {
        _ = try writePlugin("good.sh", "#!/bin/sh\n# @name Good\n# @api 1\n")
        _ = try writePlugin("plain.sh", "#!/bin/sh\necho no header\n")
        _ = try writePlugin("future.sh", "#!/bin/sh\n# @name Future\n# @api 9\n")

        let scan = try PluginScanner.scan(folder)

        XCTAssertEqual(scan.plugins.map(\.name), ["Good"])
        XCTAssertEqual(scan.refused.map(\.file), ["future.sh"])
    }

    func testRunnerReturnsRowsWithTheQuery() async throws {
        let url = try writePlugin("echo.sh", """
        #!/bin/sh
        # @name Echo
        # @api 1
        printf '{"title":"%s","run":"true"}\\n' "$1"
        """)
        let plugin = Plugin(name: "Echo", api: 1, url: url)

        let rows = try await PluginRunner.run(plugin, query: "hello", timeout: 5)

        XCTAssertEqual(rows.rows.map(\.title), ["hello"])
    }

    func testRunnerStopsAPluginThatIsTooSlow() async throws {
        let url = try writePlugin("slow.sh", "#!/bin/sh\n# @name Slow\n# @api 1\nsleep 5\n")
        let plugin = Plugin(name: "Slow", api: 1, url: url)

        do {
            _ = try await PluginRunner.run(plugin, query: "", timeout: 0.5)
            XCTFail("expected a timeout")
        } catch PluginError.timedOut {
        }
    }
}
