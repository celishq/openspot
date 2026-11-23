import XCTest
@testable import OpenspotCore

final class GridExampleTests: SampleSpotsCase {
    private static let link = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    private func standIn(_ folder: URL) -> [String: String] {
        ["board.swift": """
        import Foundation
        \(Self.note(to: folder))
        final class Grid {
            private var picked: ((Pick?) -> Void)?
            func warm() { note("warm") }
            func show(picked: @escaping (Pick?) -> Void) {
                note("show")
                let given = ProcessInfo.processInfo.environment["GRID_PICK"] ?? ""
                let corners = given.split(separator: " ").compactMap { Int($0) }
                if given == "cancel" { return DispatchQueue.main.async { picked(nil) } }
                guard corners.count == 4 else { return self.picked = picked }
                DispatchQueue.main.async { picked(Pick(columns: 6, rows: 6, from: (corners[0], corners[1]), to: (corners[2], corners[3]))) }
            }
            func hide() {
                note("hide")
                let done = picked
                picked = nil
                done?(nil)
            }
            func land() { note("land") }
        }
        """]
    }

    private func grid(in folder: URL, pick: String = "", openspot: String = "echo \"$*\" >> '%@/calls'") async throws -> (ScriptProcess, SpotFrames) {
        try "#!/bin/sh\n[ \"$1\" = toast ] && { shift; echo \"$*\" >> '\(folder.path)/toasts'; exit 0; }\n\(openspot.replacingOccurrences(of: "%@", with: folder.path))\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/opened'\n".writeScript(to: folder.appendingPathComponent("tools/open"))
        let program = try await swiftSpot("grid", in: folder, standIns: standIn(folder))
        let script = staying(program, as: "grid", home: folder, variables: ["GRID_PICK": pick])
        return (script, SpotFrames(script.start()))
    }

    private func calls(in folder: URL) -> String {
        (try? read("calls", in: folder)) ?? ""
    }

    func testItIsAStayingSwiftSpotThatThePanelKeepsReady() throws {
        let grid = try example("Grid")

        XCTAssertEqual(grid.mode, .stay)
        XCTAssertEqual(grid.triggers.moments, [.panel])
        XCTAssertNil(grid.triggers.search)
        XCTAssertEqual(grid.sources, ["grid"])
    }

    func testTheGridGivesTheBlockBetweenTwoCornersAsPartsOfTheScreen() async throws {
        let folder = try temporaryFolder()
        let grid = try await swiftSpot("grid", in: folder)

        func pick(_ numbers: Int...) async throws -> String {
            try await ScriptProcess.output(url: grid, arguments: ["pick"] + numbers.map(String.init), base: TestEnvironment.values)
        }

        let forward = try await pick(6, 6, 1, 1, 4, 3)
        let backward = try await pick(6, 6, 4, 3, 1, 1)
        let whole = try await pick(6, 6, 0, 0, 5, 5)
        let one = try await pick(6, 6, 2, 5, 2, 5)
        let outside = try await pick(6, 6, -2, 0, 9, 0)
        XCTAssertEqual(forward, "1/6 1/6 4/6 3/6\n")
        XCTAssertEqual(backward, forward)
        XCTAssertEqual(whole, "0 0 1 1\n")
        XCTAssertEqual(one, "2/6 5/6 1/6 1/6\n")
        XCTAssertEqual(outside, "0 0 1 1/6\n")
    }

    func testTheGreyBlockOfEachPickIsTheFrameThatTheMoveGivesTheWindowOnEachScreen() async throws {
        let folder = try temporaryFolder()
        let grid = try await swiftSpot("grid", in: folder)
        let areas = [
            CGRect(x: 0, y: 33, width: 1728, height: 1084),
            CGRect(x: 0, y: 25, width: 1440, height: 875),
            CGRect(x: -1920, y: -200, width: 1920, height: 1055),
            CGRect(x: 1728, y: 0, width: 2560, height: 1415),
            CGRect(x: 0, y: 38, width: 1511, height: 943),
        ]
        var checked = 0

        for area in areas {
            let numbers = [6, 6, area.minX, area.minY, area.width, area.height].map { String(Int($0)) }
            let lines = try await ScriptProcess.output(url: grid, arguments: ["frames"] + numbers, base: TestEnvironment.values).split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: "|")
                let drawn = parts[1].split(separator: " ").compactMap { Double($0) }
                let move = try XCTUnwrap(WindowMove(words: [String(parts[0])]))
                let moved = move.target(window: .zero, area: area)
                XCTAssertEqual(CGRect(x: drawn[0], y: drawn[1], width: drawn[2], height: drawn[3]), moved, "\(parts[0]) on \(area)")
                checked += 1
            }
        }

        XCTAssertEqual(checked, 5 * 666)
    }

    func testAPressHoldsItsCallUntilThePickAndMovesTheFrontWindowToTheBlock() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder, pick: "0 0 2 5")
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(calls(in: folder), "window move 0 0 3/6 1\n")
        XCTAssertEqual(notes(in: folder), "show\nland\n")
        XCTAssertEqual(toasts(in: folder), [])
    }

    func testAMoveWithoutAccessibilityOpensItsSettingsAndShowsNoFailure() async throws {
        let folder = try temporaryFolder()
        let refused = "echo link=\(Self.link)\necho 'Openspot cannot move the window.' >&2\nexit 1"
        let (script, frames) = try await grid(in: folder, pick: "0 0 2 5", openspot: refused)
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(try read("opened", in: folder), "\(Self.link)\n")
        XCTAssertEqual(toasts(in: folder), [])
    }

    func testAMoveThatFailsForAnotherReasonSaysWhy() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder, pick: "0 0 2 5", openspot: "echo 'Openspot cannot find a window to move.' >&2\nexit 1")
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(toasts(in: folder), ["Openspot cannot find a window to move."])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("opened").path))
    }

    func testAPressThatThePersonCancelsMovesNothing() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder, pick: "cancel")
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(calls(in: folder), "")
        XCTAssertEqual(notes(in: folder), "show\n")
    }

    func testASecondPressWhileTheGridShowsEndsAtOnceAndAStopHidesTheGrid() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\ncall=2\narg=place\n\n")
        try await wait("the end of the second press") { frames.ends == ["2"] }
        XCTAssertEqual(notes(in: folder), "show\n")
        script.send(text: "stop=1\n\n")
        try await wait("the end of the first press") { frames.ends == ["2", "1"] }

        XCTAssertEqual(notes(in: folder), "show\nhide\n")
        XCTAssertEqual(calls(in: folder), "")
    }

    func testOnlyAShowOfAnOpenOfThePanelWarmsTheGrid() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=show\n\n")
        try await wait("the end of the plain read") { frames.ends == ["1"] }
        XCTAssertEqual(notes(in: folder), "")
        script.send(text: "call=2\narg=show\ninput.event=panel.open\n\n")
        try await wait("the end of the read") { frames.ends == ["1", "2"] }

        XCTAssertEqual(notes(in: folder), "warm\n")
    }

    func testTheEndOfStdinEndsTheSpotWhileTheGridShows() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await grid(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=place\n\n")
        try await wait("the grid") { self.notes(in: folder) == "show\n" }
        script.end()

        try await wait("the end of the spot") { !script.isRunning && frames.ended }
    }

    func testTheRealGridTypeChecks() async throws {
        try await typechecks("grid")
    }
}
