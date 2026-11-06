import XCTest
@testable import OpenspotCore

@MainActor
final class SpotSessionTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func make(name: String = "script", _ body: String, isLive: Bool = false, read: SpotRead? = nil) throws -> SpotSession {
        let url = folder.appendingPathComponent("\(name).sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return SpotSession(command: PluginCommand(id: name, name: name, url: url, kind: .list, read: read, isLive: isLive))
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    func testARunThatEndsWithNoOutputEmptiesTheList() async throws {
        let session = try make("[ -f '\(path("second"))' ] && exit 0\ntouch '\(path("second"))'\nprintf 'row=A\\nrun=a\\n'")

        session.read()
        try await wait("the row") { session.list.shown.count == 1 }
        session.read()
        try await wait("no rows") { session.list.shown.isEmpty }
    }

    func testAReadReplacedByANewerOneLeavesTheRows() async throws {
        let session = try make("""
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'row=A\\nrun=a\\n'; exit 0; }
        sleep 0.3
        printf 'row=A\\nrun=a\\n'
        """)
        session.read()
        try await wait("the row") { session.list.shown.count == 1 }

        session.read()
        session.read()
        var lowest = 1
        for _ in 0..<80 {
            lowest = min(lowest, session.list.shown.count)
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(lowest, 1)
        XCTAssertEqual(session.list.shown.count, 1)
    }

    func testClosingLeavesAReadThatHasNoFrameYet() async throws {
        let session = try make("sleep 0.2\nprintf 'row=A\\nrun=a\\n'")

        session.open {}
        session.close()

        try await wait("the row") { session.list.shown.count == 1 }
    }

    func testClosingOneSessionLeavesTheReadOfAnother() async throws {
        let first = try make(name: "first", "printf 'part=a\\ntitle=A\\n---\\n'\nsleep 30")
        let second = try make(name: "second", "sleep 0.3\nprintf 'row=B\\nrun=b\\n'")

        first.open {}
        try await wait("the first frame") { first.panel != nil }
        second.read()
        first.close()

        try await wait("the row") { second.list.shown.count == 1 }
    }

    func testClosingStopsAScriptThatKeepsPrinting() async throws {
        let session = try make("""
        printf 'layout=none\\n\\npart=a\\ntitle=0\\n---\\n'
        sleep 0.3
        touch '\(path("went-on"))'
        printf 'part=a\\ntitle=1\\n---\\n'
        """)

        session.open {}
        try await wait("the first frame") { session.panel != nil }
        session.close()
        try await Task.sleep(for: .milliseconds(600))

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(session.panel?.parts.first?.title, "0")
    }

    func testAnOpenSheetTakesLaterFrames() async throws {
        let session = try make("printf 'part=a\\ntitle=0\\n---\\n'\nsleep 0.1\nprintf 'part=a\\ntitle=1\\n---\\n'")

        session.open {}

        try await wait("the later frame") { session.panel?.parts.first?.title == "1" }
    }

    func testAnOlderAnswerDoesNotReplaceANewerChange() async throws {
        let session = try make("""
        case "$1" in
          set) [ "$3" = old ] && sleep 0.3; printf 'part=a\\ntitle=%s\\ntext=x\\n' "$3" ;;
          *) printf 'part=a\\ntitle=start\\ntext=x\\n' ;;
        esac
        """)
        session.open {}
        try await wait("the sheet") { session.panel != nil }
        let part = try XCTUnwrap(session.panel?.parts.first)

        session.set(part, to: "old")
        session.set(part, to: "new")

        try await wait("the newest answer") { session.panel?.parts.first?.title == "new" }
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(session.panel?.parts.first?.title, "new")
        XCTAssertEqual(session.panel?.parts.first?.value, "new")
    }

    func testAToastIsReported() async throws {
        let session = try make("printf 'part=a\\ntitle=A\\n---\\n'\nprintf 'toast=Later\\n\\npart=a\\ntitle=B\\n---\\n'")
        var toasts: [String] = []
        session.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        session.open {}

        try await wait("the toast") { toasts == ["Later"] }
    }

    private static let counter = """
    count=0
    trap 'touch "%@"' EXIT
    while IFS= read -r line; do
      case "$line" in
        event=press) count=$((count + 1)) ;;
        '') printf 'part=a\\ntitle=%%s\\npress=true\\n---\\n' "$count" ;;
      esac
    done
    """

    func testALiveSheetOpensWithItsFirstFrame() async throws {
        let session = try make("sleep 0.2\n" + String(format: Self.counter, path("ended")), isLive: true)
        var isReady = false

        session.open { isReady = true }
        XCTAssertFalse(isReady)

        try await wait("the first frame") { isReady }
        XCTAssertEqual(session.panel?.parts.first?.title, "0")
    }

    func testALiveScriptDoesNotStartBeforeItsSheetOpens() async throws {
        let session = try make("touch '\(path("started"))'", isLive: true, read: .open)

        session.read()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(exists("started"))
    }

    func testClosingEndsALiveScriptAndTheNextOpenStartsAfresh() async throws {
        let session = try make(String(format: Self.counter, path("ended")), isLive: true)
        session.open {}
        try await wait("the first frame") { session.panel != nil }
        let part = try XCTUnwrap(session.panel?.parts.first)
        session.press(part)
        try await wait("the count") { session.panel?.parts.first?.title == "1" }

        session.close()
        try await wait("the end of the script") { exists("ended") }

        var isReady = false
        session.open { isReady = true }
        try await wait("the new run") { isReady }
        XCTAssertEqual(session.panel?.parts.first?.title, "0")
        session.close()
    }

    func testAPressJustBeforeClosingStillReachesALiveScript() async throws {
        let session = try make("""
        while IFS= read -r line; do
          case "$line" in
            event=press) sleep 0.2; touch '\(path("copied"))' ;;
            '') printf 'part=copy\\ntitle=Copy\\npress=true\\n---\\n' ;;
          esac
        done
        """, isLive: true)
        session.open {}
        try await wait("the first frame") { session.panel != nil }

        session.press(try XCTUnwrap(session.panel?.parts.first))
        session.close()

        try await wait("the copy") { exists("copied") }
    }

    func testAKeptSearchIsAskedAgainOnOpen() async throws {
        let session = try make("printf 'row=Notes\\nrun=n\\n\\nrow=Mail\\nrun=m\\n'")
        session.open {}
        try await wait("the rows") { session.list.shown.count == 2 }
        session.search("no")
        session.close()

        session.open {}

        XCTAssertEqual(session.list.query, "no")
        try await wait("the match") { session.list.shown.map(\.title) == ["Notes"] }
    }
}
