import XCTest
@testable import OpenspotCore

/// Proves `OPENSPOT_SH` with real shells and real processes.
final class ShellHelperTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func script(_ body: String, shell: String = "/bin/sh") throws -> URL {
        let url = folder.appendingPathComponent(UUID().uuidString)
        try "#!\(shell)\n. \"$OPENSPOT_SH\"\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private static let hard = [
        "\\", "\\\\", "a\\", "\\n", "a\\nb", "one\ntwo", "one\n", "\none", "\n", "a\\\nb", "=", "a=b=c", "-", "-n", "-e x", "--",
        "%s %d", "*", "$HOME `date`", " spaces ", "\ttab", "\"quotes\" 'too'", "héllo привет", "~", "a\n\n\\\\\n\nb"
    ]

    func testValuePrintsTheRealTextOfEachHardValueInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nb=$(value b; printf x)\nprintf '%s|%s' \"${a%x}\" \"${b%x}\"", shell: shell)
            for text in Self.hard {
                let input = TextBlock(fields: [.init(key: "first", value: "not this"), .init(key: "a", value: text), .init(key: "b", value: "second=\(text)")]).text

                let output = try await ScriptProcess.output(url: url, input: input, limit: 10)

                XCTAssertEqual(output, "\(text)|second=\(text)", "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscIsTheInverseOfValueInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nprintf 'a=%s\\n' \"$(esc \"${a%x}\")\"", shell: shell)
            for text in Self.hard {
                let line = TextBlock(fields: [.init(key: "a", value: text)]).text

                let output = try await ScriptProcess.output(url: url, input: line, limit: 10)

                XCTAssertEqual(output, line, "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscLeavesTheStateOfTheScriptAlone() async throws {
        let url = try script("""
        set -- one two
        IFS=:
        esc 'a\\b
        c'
        printf '|%s|%s|%s' "$IFS" "$1" "$#"
        """)

        let output = try await ScriptProcess.output(url: url, limit: 10)

        XCTAssertTrue(output.hasPrefix("a\\\\b\\nc|:|one|2"), output)
    }

    func testValueOfAnUnknownIdPrintsNothing() async throws {
        let url = try script("value none\nvalue a=\nprintf '%s' \"$(value ''; value a)\"")

        let output = try await ScriptProcess.output(url: url, input: "a=1\n", limit: 10)

        XCTAssertEqual(output, "1")
    }

    func testValueIsSafeWithAStrictScript() async throws {
        let url = try script("set -eu\nvalue none\nvalue a\nesc x")

        let output = try await ScriptProcess.output(url: url, limit: 10)

        XCTAssertEqual(output, "x")
    }

    func testAScriptReadsATwoMegabyteValueWithValue() async throws {
        let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)
        let url = try script("value big")

        let output = try await ScriptProcess.output(url: url, input: TextBlock(fields: [.init(key: "big", value: big)]).text, limit: 30)

        XCTAssertEqual(output, big)
    }

    func testAStayingScriptIsNotBlockedAndKeepsItsCallsOnStdin() async throws {
        let url = try script("""
        printf 'a=%s|%s\\n---\\n' "$(esc 'b\\c')" "$(value a)"
        while IFS= read -r line; do
          [ -z "$line" ] || printf 'got=%s\\n---\\n' "$line"
        done
        """)
        let live = ScriptProcess(url: url, mode: .stays, limit: 3)
        defer { live.end() }
        var frames = try live.start().makeAsyncIterator()

        let first = try await frames.next()
        live.send(.press("go"))
        let second = try await frames.next()

        XCTAssertEqual(first, "a=b\\\\c|\n")
        XCTAssertEqual(second, "got=name=go\n")
    }

    func testAStayingRunSaysSoAndAnyOtherRunDoesNot() {
        let base = ["HOME": folder.path, "OPENSPOT_STAYS": "true"]

        XCTAssertEqual(ScriptProcess.environment(base: base, app: "", stays: true)["OPENSPOT_STAYS"], "true")
        XCTAssertNil(ScriptProcess.environment(base: base, app: "")["OPENSPOT_STAYS"])
    }

    func testTheFileInTheBundleOfTheAppComesFirst() throws {
        let contents = folder.appendingPathComponent("Openspot.app/Contents")
        let resources = contents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let file = resources.appendingPathComponent("openspot.sh")
        try "".write(to: file, atomically: true, encoding: .utf8)
        let app = contents.appendingPathComponent("MacOS/Openspot").path

        let environment = ScriptProcess.environment(base: ["HOME": folder.path, "OPENSPOT_SH": "/given"], app: app)

        XCTAssertEqual(environment["OPENSPOT_SH"], file.path)
    }

    func testWithNoFileInTheBundleTheGivenPathStays() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path, "OPENSPOT_SH": "/given"], app: "/none/Openspot.app/Contents/MacOS/Openspot")

        XCTAssertEqual(environment["OPENSPOT_SH"], "/given")
    }
}
