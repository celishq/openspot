import XCTest
@testable import OpenspotCore

/// Proves how a JavaScript spot answers inside the app: in the turn of the text when it is fast, and in a later turn,
/// with the last rows kept, when it is slow (I3, I5).
@MainActor
final class SpotRunsInlineTests: SpotRunsCase {
    /// A host of the API that reaches nothing on the Mac.
    private struct Host: CommandHost {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { false }
    }

    /// Writes a JavaScript spot with these header lines.
    private func inline(_ name: String = "script", header: String, _ body: String) throws {
        let lines = header.split(separator: "\n").map { "// \($0)\n" }.joined()
        try "\(lines)\(body)\n".write(to: folder.appendingPathComponent("\(name).js"), atomically: true, encoding: .utf8)
    }

    /// A spot that answers each text with one row of it, and works for 300 ms first on the text `slow`.
    private func answering() throws {
        try inline(header: "mode=inline\nanswers=^[0-9]", """
        function read(reason, text) {
          if (text === "12") { const end = Date.now() + 300; while (Date.now() < end) {} }
          return `row=${text}\\ntitle=Is ${text}\\ndetail=${reason}\\n`
        }
        """)
    }

    func testAFastInlineSpotAnswersInTheTurnOfTheText() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("1")
        try await wait("the loaded script") { sheet.answers.map(\.run) == ["1"] }

        sheet.answer("7")

        XCTAssertEqual(sheet.answers.map(\.run), ["7"])
        XCTAssertEqual(sheet.answers.first?.subtitle, "search")
        XCTAssertFalse(sheet.isAnswering)
    }

    func testASlowInlineSpotKeepsTheLastRowsUntilItsAnswerLandsInALaterTurn() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("1")

        sheet.answer("12")

        XCTAssertEqual(sheet.answers.map(\.run), ["1"])
        XCTAssertTrue(sheet.isAnswering)
        try await wait("the slow answer") { sheet.answers.map(\.run) == ["12"] }
        XCTAssertFalse(sheet.isAnswering)
    }

    func testANewerTextDropsTheAnswerOfASlowOlderOne() async throws {
        try answering()
        let sheet = try sheet()

        sheet.answer("12")
        sheet.answer("123")

        try await wait("the newest answer") { sheet.answers.map(\.run) == ["123"] }
        try await pause(0.5)
        XCTAssertEqual(sheet.answers.map(\.run), ["123"])
    }

    func testOpenspotCallAsksTheAPIInTheApp() async throws {
        runs.api = CommandAPI(host: Host())
        try inline(header: "mode=inline\nanswers=^[0-9]", """
        function read(reason, text) {
          const answer = openspot.call(["calc", "solve", text])
          return answer.stdout.replace(/detail=.*/, `detail=${answer.code}`)
        }
        """)
        let sheet = try sheet()

        sheet.answer("2+2")

        try await wait("the answer of the API") { sheet.answers.map(\.run) == ["4"] }
        XCTAssertEqual(sheet.answers.first?.subtitle, "0")
    }

    func testAPickRunsItsOpenFunctionWithTheRow() async throws {
        try inline(header: "mode=inline\nanswers=^[0-9]", """
        function read(reason, text) { return `row=${text}\\ntitle=${text}\\n` }
        function open(id) { return `toast=Picked ${id}\\n` }
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.pick(SpotItem(title: "5", run: "5"))

        try await wait("the toast") { toasts == ["Picked 5"] }
    }

    func testAThrownErrorIsTheFailureOfTheCall() async throws {
        try inline(header: "mode=inline\nread=sheet", "function read() { throw new Error('No sky today') }")
        let (sheet, told) = try toldSheet()

        sheet.open {}

        try await wait("the failure") { told().contains { $0.contains("No sky today") } }
    }
}
