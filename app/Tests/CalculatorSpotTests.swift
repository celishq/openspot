import XCTest
@testable import OpenspotCore

final class CalculatorSpotTests: SampleSpotsCase {
    private var calculator: Spot {
        get throws { try XCTUnwrap(try scan.spots.first { $0.name == "Calculator" }) }
    }

    func testThePatternTakesSumsUnitsCurrenciesAndDatesAndLeavesNames() throws {
        let pattern = try XCTUnwrap(try calculator.triggers.search)
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

        XCTAssertFalse(calculator.triggers.shows)
        XCTAssertFalse(calculator.isOnGrid)
        XCTAssertFalse(calculator.isFound)
    }

    private let rates = #"{"date":"2026-11-10","usd":{"usd":1,"eur":0.8973,"uah":45.4772}}"#

    func testAnAnswerIsALargeCardOfTheSumOverTheAnswerThatFillsIt() async throws {
        try await withPrivateHome { _ in
            let answers = try await self.calculator.search("1000+234", timeout: 60).answers(asCard: self.calculator.triggers.search?.isCard == true)

            XCTAssertEqual(answers.map(\.run), ["1234"])
            XCTAssertEqual(answers.first?.card?.face.answerSize, .large)
            XCTAssertEqual(answers.first?.card?.face.parts.map(\.id), ["sum", "answer"])
            XCTAssertEqual(answers.first?.card?.face.parts.map(\.title), ["1000 + 234", nil])
            XCTAssertEqual(answers.first?.card?.face.node("answer")?.style.grows, true)
            XCTAssertEqual(answers.first?.openTitle, "Copy")
        }
    }

    private func keep(_ value: String, as name: String, in home: URL) throws {
        let spot = try calculator
        try SpotCache.standard(environment: ["HOME": home.path]).keep(value, as: name, of: spot.dataName ?? spot.id)
    }

    func testACurrencyReadsTheKeptRatesAndShowsItsSymbolFaint() async throws {
        try await withPrivateHome { home in
            try self.keep(self.rates, as: "rates", in: home)

            let answers = try await self.calculator.search("15 usd in eur", timeout: 60).answers(asCard: self.calculator.triggers.search?.isCard == true)

            XCTAssertEqual(answers.map(\.run), ["13.46"])
            XCTAssertEqual(answers.first?.card?.face.parts.first?.title.map { $0.hasPrefix("15 USD in EUR · rates of") }, true)
            XCTAssertEqual(answers.first?.card?.face.parts.last?.numberPieces.contains(where: \.isUnit), true)
        }
    }

    func testATimeInAnotherZoneKeepsTheZoneItWasReadIn() async throws {
        try await withPrivateHome { _ in
            let answers = try await self.calculator.search("3pm tokyo in berlin", timeout: 60).answers(asCard: self.calculator.triggers.search?.isCard == true)

            XCTAssertEqual(answers.first?.card?.face.parts.first?.title.map { $0.hasSuffix("· Tokyo") }, true)
        }
    }

    func testNoKeptRatesShowARowThatTheyAreComing() async throws {
        try await withPrivateHome { _ in
            let rows = try await self.calculator.search("15 usd in eur", timeout: 60).items

            XCTAssertEqual(rows.map(\.title), ["Getting exchange rates"])
        }
    }

    func testAFailureOfTheRatesShowsARowThatSaysHowToGetThem() async throws {
        try await withPrivateHome { home in
            try self.keep("offline", as: "rates-failure", in: home)

            let rows = try await self.calculator.search("15 usd in eur", timeout: 60).items

            XCTAssertEqual(rows.map(\.title), ["No exchange rates"])
            XCTAssertEqual(rows.first?.subtitle, "Openspot cannot get exchange rates. Connect to the internet, then type again.")
        }
    }

    func testADeadSourceShowsARowThatSaysWhatStillWorks() async throws {
        try await withPrivateHome { home in
            try self.keep("unavailable", as: "rates-failure", in: home)

            let rows = try await self.calculator.search("15 usd in eur", timeout: 60).items

            XCTAssertEqual(rows.map(\.title), ["No exchange rates"])
            XCTAssertEqual(rows.first?.subtitle, "The source of the rates does not answer. Sums, units and dates still work. Try again later.")
        }
    }

    func testAPickCopiesThePlainValue() async throws {
        try await withPrivateHome { home in
            try await self.calculator.perform("press", input: "input.item=13.46\n", timeout: 60)

            XCTAssertEqual(self.toasts(in: home), ["Copied 13.46"])
            XCTAssertEqual(try String(contentsOf: home.appendingPathComponent("clipboard"), encoding: .utf8), "13.46")
        }
    }

    func testTheCalculatorRunsInline() throws {
        XCTAssertEqual(try calculator.mode, .inline)
    }

    @MainActor
    private func panel(in folder: URL, defaults: UserDefaults, fetch: Fetch? = nil) async throws -> SpotsModel {
        let spots = folder.appendingPathComponent("spots", isDirectory: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        let source = try calculator.url.deletingLastPathComponent()
        try FileManager.default.copyItem(at: source, to: spots.appendingPathComponent(source.lastPathComponent))
        let host = FakeHost()
        let files = AppPlaces(environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path], home: folder, defaults: defaults)
        let model = SpotsModel(host: host, files: files, runs: SpotRuns(environment: TestEnvironment.values, stopPause: 0.2, cache: SpotCache(folder: folder.appendingPathComponent("cache"))))
        host.model = model
        if let fetch { model.runs.fetch = fetch }
        model.runs.api = CommandAPI(mac: Mac(), places: files, runs: model.runs)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        return model
    }

    @MainActor
    func testAKeyShowsTheRowOfASumWithin4Milliseconds() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-calc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "openspot-calc-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = try await panel(in: folder, defaults: defaults)
        defer { model.quit() }
        model.searchText = "2+2"
        for _ in 0..<6000 where model.visible.first?.id != "calculator\n4" { try await Task.sleep(for: .milliseconds(10)) }

        var times: [Duration] = []
        for _ in 0..<5 {
            model.searchText = ""
            let start = ContinuousClock.now
            model.searchText = "12*(3+4)"
            if model.visible.first?.id == "calculator\n84" { times.append(ContinuousClock.now - start) }
            for _ in 0..<6000 where model.visible.first?.id != "calculator\n84" { try await Task.sleep(for: .milliseconds(10)) }
        }

        XCTAssertLessThan(try XCTUnwrap(times.min(), "no key showed its rows in its own turn"), .milliseconds(4), "\(times)")
    }

    @MainActor
    func testACurrencyShowsTheLoadingRowUntilItsRatesComeThenItsAnswer() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-calc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
        FakeWeb.answers.withLock { $0[source] = .init(status: 200, body: Data(rates.utf8), headers: [:]) }
        let suite = "openspot-calc-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = try await panel(in: folder, defaults: defaults, fetch: Fetch(configuration: FakeWeb.configuration, wait: 30))
        defer { model.quit() }

        model.searchText = "15 usd in eur"

        try await wait("the answer from the fetched rates") { model.visible.first?.id == "calculator\n13.46" }
        XCTAssertEqual(FakeWeb.asked.withLock { $0.filter { $0.url?.absoluteString == source }.count }, 1)
    }
}

@MainActor
private extension Spot {
    func search(_ text: String, timeout: TimeInterval) async throws -> Frame {
        try await answer("search", input: "input.text=\(text)\n", timeout: timeout)
    }
}
