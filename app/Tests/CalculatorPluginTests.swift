import XCTest
@testable import OpenspotCore

/// Proves the Calculator plugin with its real script and a fake `openspot calc solve` that prints a file, and its time from
/// a key to its rows with the real API.
final class CalculatorPluginTests: SamplePluginsCase {
    /// A host of the API that reaches nothing on the Mac.
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { false }
    }

    private var calculator: Spot {
        get throws { try XCTUnwrap(try scan.spots.first { $0.name == "Calculator" }) }
    }

    func testThePatternTakesSumsUnitsCurrenciesAndDatesAndLeavesNames() throws {
        let pattern = try XCTUnwrap(try calculator.answers)
        let sums = [
            "2*(3+4)", "15% of 80", "-5+2", "(1+2)*3", ".5*2", "$15", "€20 in usd", "5 km in mi", "15 usd in eur", "today + 3 weeks",
            "Tomorrow", "days until 25 dec", "now in tokyo", "3pm tokyo in kyiv", "next friday", "in 3 weeks", "sqrt 2", "pi*2", "time in london", "₹500 in usd", "the time in tokyo",
        ]
        let names = ["safari", "notes", "calculator", "timer", "nowhere", "instagram", "pinterest", "logic pro", "nextcloud", "daystar", "lastpass"]

        XCTAssertEqual(sums.filter { !pattern.matches($0) }, [])
        XCTAssertEqual(names.filter(pattern.matches), [])
    }

    func testTheCalculatorOnlyAnswersAndHasNoCard() throws {
        let calculator = try calculator

        XCTAssertNil(calculator.read)
        XCTAssertFalse(calculator.isOnGrid)
        XCTAssertFalse(calculator.isFound)
    }

    func testAnAnswerIsTheRowOfTheCalcCommandForTheText() async throws {
        try await withPrivateHome { home in
            try "row=14\ntitle=14\ndetail=2 × (3 + 4)\n".write(to: home.appendingPathComponent("calc-answer"), atomically: true, encoding: .utf8)

            let rows = try await self.calculator.items(query: "2*(3+4)", timeout: 5).items

            XCTAssertEqual(rows.map(\.run), ["14"])
            XCTAssertEqual(rows.first?.subtitle, "2 × (3 + 4)")
            XCTAssertEqual(try String(contentsOf: home.appendingPathComponent("calc-asked"), encoding: .utf8), "2*(3+4)\n")
        }
    }

    func testNoRatesShowARowThatSaysHowToGetThem() async throws {
        try await withPrivateHome { home in
            try "status=offline\n".write(to: home.appendingPathComponent("calc-answer"), atomically: true, encoding: .utf8)

            let rows = try await self.calculator.items(query: "15 usd in eur", timeout: 5).items

            XCTAssertEqual(rows.map(\.title), ["No exchange rates"])
            XCTAssertEqual(rows.first?.subtitle, "Openspot cannot get exchange rates. Connect to the internet, then type again.")
        }
    }

    func testADeadSourceShowsARowThatSaysWhatStillWorks() async throws {
        try await withPrivateHome { home in
            try "status=unavailable\n".write(to: home.appendingPathComponent("calc-answer"), atomically: true, encoding: .utf8)

            let rows = try await self.calculator.items(query: "15 usd in eur", timeout: 5).items

            XCTAssertEqual(rows.map(\.title), ["No exchange rates"])
            XCTAssertEqual(rows.first?.subtitle, "The source of the rates does not answer. Sums, units and dates still work. Try again later.")
        }
    }

    func testAPickCopiesThePlainValue() async throws {
        try await withPrivateHome { home in
            let toast = try await self.calculator.perform(.item(SpotItem(title: "13,46 €", run: "13.46")), timeout: 5)

            XCTAssertEqual(toast, "Copied 13.46")
            XCTAssertEqual(try String(contentsOf: home.appendingPathComponent("clipboard"), encoding: .utf8), "13.46")
        }
    }

    func testTheCalculatorRunsInline() throws {
        XCTAssertEqual(try calculator.mode, .inline)
    }

    /// Types a sum in the main search of a panel with the calculator and the real API, 5 times, and times each key whose
    /// rows show in its own turn. The fastest proves the path, and a busy Mac can slow the others.
    @MainActor
    func testAKeyShowsTheRowOfASumWithin4Milliseconds() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-calc-\(UUID().uuidString)")
        let plugins = folder.appendingPathComponent("plugins", isDirectory: true)
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(at: try calculator.url, to: plugins.appendingPathComponent(try calculator.url.lastPathComponent))
        let suite = "openspot-calc-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let host = TestHost()
        let files = SpotFiles(environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path], home: folder, defaults: defaults)
        let model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        defer { model.quit() }
        host.model = model
        model.runs.api = CommandAPI(mac: Host())
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.searchText = "2+2"
        for _ in 0..<500 where model.visible.first?.id != "calculator\n4" { try await Task.sleep(for: .milliseconds(10)) }

        var times: [Duration] = []
        for _ in 0..<5 {
            model.searchText = ""
            let start = ContinuousClock.now
            model.searchText = "12*(3+4)"
            if model.visible.first?.id == "calculator\n84" { times.append(ContinuousClock.now - start) }
            for _ in 0..<500 where model.visible.first?.id != "calculator\n84" { try await Task.sleep(for: .milliseconds(10)) }
        }

        XCTAssertLessThan(try XCTUnwrap(times.min(), "no key showed its rows in its own turn"), .milliseconds(4), "\(times)")
    }
}
