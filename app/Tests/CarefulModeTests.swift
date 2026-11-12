import XCTest
@testable import OpenspotCore

/// Proves Careful mode with the real `sandbox-exec`: a spot's process writes only to its data folder and the temp folder
/// unless its header names `files`, and reaches no network unless it names `network`. Off, a spot can do all that the
/// person can (protocol: Trust).
@MainActor
final class CarefulModeTests: SpotRunsCase {
    private var outside: URL!
    private var listener: Int32 = -1
    private var port: UInt16 = 0

    override func setUp() async throws {
        try await super.setUp()
        let home = try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home")
        outside = URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("careful-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        listener = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET), sin_port: 0, sin_addr: in_addr(s_addr: inet_addr("127.0.0.1")), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = Darwin.bind(listener, $0, size)
                _ = Darwin.listen(listener, 8)
                _ = getsockname(listener, $0, &size)
            }
        }
        port = UInt16(bigEndian: address.sin_port)
    }

    override func tearDown() async throws {
        close(listener)
        try? FileManager.default.removeItem(at: outside)
        try await super.tearDown()
    }

    /// A spot that tries each use and shows what worked as the title of its read.
    private func trying(uses: String = "") throws -> SpotRun {
        try script(header: "on=sheet.open\(uses.isEmpty ? "" : "\nuses=\(uses)")", """
        r=
        echo a > "$OPENSPOT_DATA/kept" 2>/dev/null && r="${r}data "
        echo a > "${TMPDIR:-/tmp}/careful-$$" 2>/dev/null && r="${r}temp " && rm -f "${TMPDIR:-/tmp}/careful-$$"
        echo a > '\(outside.path)/written' 2>/dev/null && r="${r}files "
        /usr/bin/nc -z -w 2 127.0.0.1 \(port) >/dev/null 2>&1 && r="${r}network "
        echo a > "$(getconf DARWIN_USER_CACHE_DIR)careful-$$" 2>/dev/null && r="${r}cache " && rm -f "$(getconf DARWIN_USER_CACHE_DIR)careful-$$"
        mkdir -p "$HOME/Desktop" && echo a > "$HOME/Desktop/careful-$$" 2>/dev/null && r="${r}screenshots " && rm -f "$HOME/Desktop/careful-$$"
        head -c 1 /etc/hosts >/dev/null && r="${r}read"
        printf 'text=t\\ntitle=%s\\n' "$r"
        """)
        return try sheet()
    }

    private func result(of sheet: SpotRun) async throws -> String {
        runs.panelOpened()
        sheet.open {}
        try await wait("the read") { sheet.reading.value?.title.isEmpty == false }
        return sheet.reading.value?.title ?? ""
    }

    func testOffASpotDoesAllThatThePersonCan() async throws {
        let result = try await result(of: trying())

        XCTAssertEqual(result, "data temp files network cache screenshots read")
    }

    func testOnASpotWritesOnlyToItsDataAndTheTempFolderAndReachesNoNetwork() async throws {
        runs.isCareful = true

        let result = try await result(of: trying())

        XCTAssertEqual(result, "data temp cache read")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("written").path))
    }

    func testOnASpotHasWhatItsUsesName() async throws {
        runs.isCareful = true

        let result = try await result(of: trying(uses: "files,network"))

        XCTAssertEqual(result, "data temp files network cache screenshots read")
    }

    func testOnAScreenSpotWritesToTheFolderOfScreenshots() async throws {
        runs.isCareful = true

        let result = try await result(of: trying(uses: "screen"))

        XCTAssertEqual(result, "data temp cache screenshots read")
    }

    func testOnAStayingSpotIsCarefulToo() async throws {
        runs.isCareful = true
        try script(header: "mode=stay\non=sheet.open", """
        echo a > '\(outside.path)/written' 2>/dev/null && r=files || r=kept
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\ntext=t\\ntitle=%s\\n---\\n' "$call" "$r"
        done
        """)

        let result = try await result(of: try sheet())

        XCTAssertEqual(result, "kept")
    }

    func testAStayingSpotStartsAgainInTheNewModeWhenTheModeChanges() async throws {
        try script(header: "mode=stay\non=sheet.open", """
        echo a > '\(outside.path)/written-$$' 2>/dev/null && r=files || r=kept
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\ntext=t\\ntitle=%s\\n---\\n' "$call" "$r"
        done
        """)
        let sheet = try sheet()
        let first = try await result(of: sheet)
        XCTAssertEqual(first, "files", "the script started as the person")

        runs.isCareful = true

        try await wait("the read of the new process") { sheet.reading.value?.title == "kept" }
    }

    func testOnTheSandboxDeniesAppleEvents() {
        let words = CarefulMode(uses: Set(SpotUse.allCases)).words(data: "/d", temp: "/t", home: "/h")

        XCTAssertTrue(words.contains { $0.contains("(deny appleevent-send)") })
    }

    func testOnTheHelperProcessOfAnInlineSpotIsCarefulToo() async throws {
        let bin = folder.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try "#!/bin/sh\necho a > '\(outside.path)/written' 2>/dev/null && echo files || echo kept\n".writeScript(to: bin.appendingPathComponent("openspot"))
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", "\(bin.path):\(path)", 1)
        defer { setenv("PATH", path, 1) }
        try "// on=sheet.open\nfunction main() { return `text=t\\ntitle=${openspot.call([\"color\", \"pick\"]).stdout.trim()}\\n` }\n"
            .write(to: folder.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
        let sheet = try sheet()
        let before = try await result(of: sheet)
        XCTAssertEqual(before, "files", "the helper ran as the person")
        try FileManager.default.removeItem(at: outside.appendingPathComponent("written"))

        runs.isCareful = true
        sheet.read(need: .change)

        try await wait("the read in Careful mode") { sheet.reading.value?.title == "kept" }
    }
}
