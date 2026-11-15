import XCTest
@testable import OpenspotCore

@MainActor
class SpotRunsCase: XCTestCase {
    var folder: URL!
    var runs: SpotRuns!
    var time = Date(timeIntervalSince1970: 1000)
    var menuBar: Set<String> = []

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-runs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50))
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(name))
    }

    func log(_ name: String = "log") -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
    }

    @discardableResult
    func script(_ name: String = "script", header: String = "", log: String = "log", _ body: String = "") throws -> URL {
        let url = folder.spotFile(name)
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\necho $$ >> '\(path("pids"))'\necho \"$*\" >> '\(path(log))'\n\(body)\n".writeScript(to: url)
        return url
    }

    @discardableResult
    func script(body: String) throws -> URL {
        try script("script", header: "", body)
    }

    func scanned() throws -> ScanResult {
        let scan = try SpotsFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        runs.take(scan, menuBar: menuBar)
        return scan
    }

    func sheet(_ id: String = "script") throws -> SpotRun {
        _ = try scanned()
        return try XCTUnwrap(runs.sheets[id])
    }

    func wait(_ what: String, until condition: @escaping () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    func allEnded() async throws {
        let text = (try? String(contentsOfFile: path("pids"), encoding: .utf8)) ?? ""
        let pids = text.split(separator: "\n").compactMap { Int32($0) }
        try await wait("the end of each script") { pids.allSatisfy { kill($0, 0) != 0 } }
    }

    func pid(_ name: String) async throws -> Int32 {
        var text = ""
        try await wait("the pid in \(name)") {
            text = (try? String(contentsOfFile: self.path(name), encoding: .utf8)) ?? ""
            return text.hasSuffix("\n")
        }
        return try XCTUnwrap(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    var untilRelease: String {
        "n=0; while [ ! -f '\(path("release"))' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
    }

    func openGate() {
        FileManager.default.createFile(atPath: path("release"), contents: Data())
    }

    func pause(_ seconds: Double = 0.2) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    @discardableResult
    func staying(header: String = "mode=stay\noffers=card\noffers=menubar", head: String = "", frame: String = "row=a\\ntitle=A\\n") throws -> URL {
        try script(header: header, """
        trap 'touch "\(path("ended"))"' EXIT
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\(head)\\n\(frame)---\\n' "$call"
        done
        """)
    }

    func blocks(ids: Bool = false) -> [String] {
        let text = (try? String(contentsOfFile: path("blocks"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }.map { block in
            ids ? block : block.split(separator: "\n").filter { !$0.hasPrefix("call=") && !$0.hasPrefix("env.") }.joined(separator: "\n")
        }
    }

    func toldSheet() throws -> (sheet: SpotRun, told: () -> [String]) {
        let sheet = runs.sheet(for: try XCTUnwrap(SpotsFolder(url: folder).scan().scripts.first))
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        return (sheet, { failures })
    }
}

extension Date {
    static func += (date: inout Date, seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}
