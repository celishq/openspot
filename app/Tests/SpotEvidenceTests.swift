import XCTest
@testable import OpenspotCore

final class SpotEvidenceTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_794_394_800)
    private let file = URL(fileURLWithPath: "/spots/weather.spot/weather.sh")
    private let weather = Spot(id: "weather", name: "Weather", url: URL(fileURLWithPath: "/spots/weather.spot/weather.sh"))
    private let other = Spot(id: "other", name: "Other", url: URL(fileURLWithPath: "/other.sh"))

    private var prompt: AgentPrompt {
        AgentPrompt(folder: URL(fileURLWithPath: "/spots"), guide: URL(fileURLWithPath: "/spots"), app: "openspot")
    }

    func testAFailingSpotGetsItsFailuresAndTheGoalToMakeEveryCallPassWithNoQuestion() throws {
        let usage = StatsLog(at: day)
        for index in 0..<10 { usage.called(weather, CallOutcome(seconds: 1, failure: index < 4 ? .timeout : nil), at: day) }
        usage.failed(weather, fault: "Weather took too long.", at: day)

        let evidence = try XCTUnwrap(SpotEvidence(of: "weather", in: usage.days(14, at: day), app: "openspot"))
        let text = prompt.changing(file, failure: nil, evidence: evidence)

        XCTAssertTrue(text.hasPrefix("Change the Openspot spot in \(file.path): Make every call pass, and keep what works.\n\(AgentPrompt.finishChange)\n"), text)
        XCTAssertTrue(text.contains("- 10 calls, 4 failed: 4 timed out. The last fault: Weather took too long.\n"), text)
        XCTAssertTrue(text.contains("\"openspot\" spot stats --days 14 --spot weather --by version"), text)
        XCTAssertFalse(text.contains("Ask me"), text)
    }

    func testACallTheHeaderDoesNotDeclareGetsTheGoalToDeclareItOrRemoveIt() throws {
        let usage = StatsLog(at: day)
        usage.called(weather, CallOutcome(seconds: 1), at: day)
        _ = usage.refused(UseRefusal(spot: Spot(id: "weather", name: "Weather", url: URL(fileURLWithPath: "/weather.sh")), call: try XCTUnwrap(SpotUseCall(name: "app quit", rule: CallRule(use: .app, used: "quit an app")))), at: day)

        let evidence = try XCTUnwrap(SpotEvidence(of: "weather", in: usage.days(14, at: day), app: "openspot"))

        XCTAssertEqual(evidence.goal, "Declare each use in its spot.toml, or remove the call that needs it.")
        XCTAssertTrue(evidence.facts.contains("Calls that its spot.toml does not declare: app.quit 1 time."), "\(evidence.facts)")
    }

    func testACleanSpotGetsItsShareOfAllSpotsAndTheGoalToJudge() throws {
        let usage = StatsLog(at: day)
        usage.panel(shown: true)
        usage.acted(weather, at: day)
        usage.called(weather, CallOutcome(seconds: 0.1, answered: 0.07), at: day)
        usage.add(ProcessTime(cpu: 1, wakeups: 10), to: "weather", at: day)
        usage.add(ProcessTime(cpu: 3, wakeups: 10), to: "other", at: day)
        usage.panel(shown: false)
        usage.add(ProcessTime(cpu: 0.5, wakeups: 200), to: "weather", at: day)

        let evidence = try XCTUnwrap(SpotEvidence(of: "weather", in: usage.days(14, at: day), app: "openspot"))

        XCTAssertTrue(evidence.goal.hasPrefix("Judge from these numbers whether anything is worth improving"), evidence.goal)
        XCTAssertTrue(evidence.facts.contains("CPU: 1.5 s a day, 33% of the CPU of all spots, 1.5 s for each act."), "\(evidence.facts)")
        XCTAssertTrue(evidence.facts.contains("While the panel was hidden: 500 ms CPU and 200 wakeups a day."), "\(evidence.facts)")
        XCTAssertTrue(evidence.facts.contains("Acts: 1.0 a day, 100% of the acts of all spots."), "\(evidence.facts)")
    }

    func testTheLastChangeIsComparedWithTheVersionsBeforeIt() throws {
        let usage = StatsLog(at: day)
        usage.take(versions: ["weather": "v1"])
        for index in 0..<10 { usage.called(weather, CallOutcome(seconds: 1, failure: index < 4 ? .exit : nil), at: day) }
        usage.take(versions: ["weather": "v2"])
        for _ in 0..<6 { usage.called(weather, CallOutcome(seconds: 1), at: day.addingTimeInterval(60)) }

        let evidence = try XCTUnwrap(SpotEvidence(of: "weather", in: usage.days(14, at: day), app: "openspot"))

        XCTAssertTrue(evidence.facts.contains("Since its last change: 0 of 6 calls failed. Before it: 4 of 10 failed."), "\(evidence.facts)")
    }

    func testASpotWithNoCountsHasNoEvidenceAndThePromptAsksWhatToChange() {
        XCTAssertNil(SpotEvidence(of: "weather", in: StatsLog(at: day).days(14, at: day), app: "openspot"))
        XCTAssertTrue(prompt.changing(file, failure: nil, evidence: nil).contains("Ask me what to change"))
    }

    func testAWishKeepsItsWordsAndGetsTheFactsBelow() throws {
        let usage = StatsLog(at: day)
        usage.called(weather, CallOutcome(seconds: 1), at: day)
        usage.called(other, CallOutcome(seconds: 1), at: day)

        let evidence = try XCTUnwrap(SpotEvidence(of: "weather", in: usage.days(14, at: day), app: "openspot"))
        let text = prompt.changing(file, wish: "Add a refresh button", evidence: evidence)

        XCTAssertTrue(text.hasPrefix("Change the Openspot spot in \(file.path): Add a refresh button\n\(AgentPrompt.finishChange)\n"), text)
        XCTAssertTrue(text.contains("What Openspot counted of this spot over the last 14 days on this Mac:\n- 1 call, 0 failed.\n"), text)
        XCTAssertFalse(text.contains("Judge"), text)
    }
}
