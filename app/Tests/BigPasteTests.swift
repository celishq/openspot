import XCTest
@testable import OpenspotCore

@MainActor
final class BigPasteTests: XCTestCase {
    private static let megabyte = 1_000_000

    private static let texts: [(name: String, text: String)] = [
        ("letters", String(repeating: "a", count: megabyte)),
        ("lines", String(repeating: "one line\n", count: megabyte / 9)),
        ("backslashes", String(repeating: "\\", count: megabyte)),
        ("words", String(repeating: "héllo wörld ", count: megabyte / 14))
    ]

    private var folder: URL!
    private var runs: SpotRuns!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-paste-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func sheet(answer: String) throws -> SpotRun {
        let url = folder.spotFile("script")
        try """
        #!/bin/sh
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nfield=input\\nvalue=\\n\\nfield=output\\nvalue=\\nreadonly=true\\n' ;;
          input) \(answer) ;;
        esac
        """.writeScript(to: url, toml: "")
        runs.take(try SpotsFolder(url: folder).scan())
        return try XCTUnwrap(runs.sheets["script"])
    }

    private func answer(of sheet: SpotRun, to text: String, _ name: String) async throws {
        sheet.open {}
        try await wait("the open sheet") { sheet.panel != nil && sheet.calls.isEmpty }
        let input = try XCTUnwrap(sheet.panel?.parts.first { $0.id == "input" })
        sheet.set(input, to: text)
        try await wait("the answer to the \(name)", seconds: 60) { sheet.panel?.parts.first(where: { $0.id == "output" })?.value == text }
        sheet.close()
        runs.panelClosed()
        try await wait("the end of the calls") { sheet.calls.isEmpty }
    }

    func testAPasteOfOneMegabyteAnswersWhole() async throws {
        let sheet = try sheet(answer: "printf 'frame=\\nclass=gap-part\\n\\nfield=output\\nvalue='; sed -n 's/^input\\.input=//p'")
        for (name, text) in Self.texts {
            try await answer(of: sheet, to: text, name)
        }
    }

    func testAPasteOfOneMegabyteThroughTheShellHelperAnswersWhole() async throws {
        let sheet = try sheet(answer: #". "$OPENSPOT_SH"; input=$(value input.input; printf x); printf 'frame=\nclass=gap-part\n\nfield=output\nvalue=%s\n' "$(esc "${input%x}")""#)
        for (name, text) in Self.texts {
            try await answer(of: sheet, to: text, name)
        }
    }
}
