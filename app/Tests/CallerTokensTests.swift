import XCTest
@testable import OpenspotCore

/// Proves that each process and inline link of a spot gets a token that the app maps to the spot while it runs, and that a
/// call with no token, or with an unknown one, is the person's (protocol: Trust).
@MainActor
final class CallerTokensTests: SpotRunsCase {
    private func caller(_ token: String?) -> String? {
        runs.tokens.caller(of: token.map { [CallerTokens.variable: $0] } ?? [:])?.id
    }

    private func token(in name: String) async throws -> String {
        var text = ""
        try await wait("the token in \(name)") {
            text = (try? String(contentsOfFile: self.path(name), encoding: .utf8)) ?? ""
            return text.hasSuffix("\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testAProcessHasATokenOfItsSpotUntilItEnds() async throws {
        try script(header: "on=sheet.open", "echo \"$OPENSPOT_TOKEN\" > '\(path("token"))'\n\(untilRelease)\nprintf 'row=a\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        let token = try await token(in: "token")

        XCTAssertEqual(caller(token), "script")
        openGate()
        try await allEnded()
        try await wait("the release of the token") { self.caller(token) == nil }
    }

    func testEachProcessHasATokenOfItsOwn() async throws {
        try script("one", header: "on=panel.open", "echo \"$OPENSPOT_TOKEN\" > '\(path("one-token"))'\n\(untilRelease)")
        try script("two", header: "on=panel.open", "echo \"$OPENSPOT_TOKEN\" > '\(path("two-token"))'\n\(untilRelease)")
        _ = try scanned()
        runs.panelOpened()

        let one = try await token(in: "one-token")
        let two = try await token(in: "two-token")

        XCTAssertNotEqual(one, two)
        XCTAssertEqual(caller(one), "one")
        XCTAssertEqual(caller(two), "two")
        openGate()
        try await allEnded()
    }

    func testAStayingProcessKeepsItsTokenBetweenCalls() async throws {
        try script(header: "mode=stay\non=sheet.open", """
        echo "$OPENSPOT_TOKEN" > '\(path("token"))'
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nrow=a\\n---\\n' "$call"
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        let token = try await token(in: "token")
        try await wait("the first frame") { !sheet.rows.all.isEmpty }

        XCTAssertEqual(caller(token), "script")
    }

    func testAnInlineCallHasATokenOfItsSpot() async throws {
        try "// on=sheet.open\nfunction main(args, env) { return `text=t\\ntitle=${env.OPENSPOT_TOKEN}\\n` }\n"
            .write(to: folder.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the frame") { sheet.reading.value?.title.isEmpty == false }

        XCTAssertEqual(caller(sheet.reading.value?.title), "script")
    }

    func testACallWithNoTokenOrAnUnknownOneIsThePersons() {
        XCTAssertNil(caller(nil))
        XCTAssertNil(caller("0123456789abcdef0123456789abcdef"))
    }
}
