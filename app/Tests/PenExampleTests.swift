import XCTest
@testable import OpenspotCore

final class PenExampleTests: SampleSpotsCase {
    private func standIn(_ folder: URL) -> [String: String] {
        ["overlay.swift": """
        import Foundation
        \(Self.note(to: folder))
        final class Overlay {
            private let closed: () -> Void
            init(closed: @escaping () -> Void) { self.closed = closed }
            func show() {
                note("show")
                guard ProcessInfo.processInfo.environment["PEN_ESCAPE"] == "1" else { return }
                DispatchQueue.main.async {
                    self.close()
                    self.closed()
                }
            }
            func close() { note("close") }
        }
        """]
    }

    private func pen(in folder: URL, escape: Bool = false) async throws -> (ScriptProcess, SpotFrames) {
        let program = try await swiftSpot("pen", in: folder, standIns: standIn(folder))
        let script = staying(program, as: "pen", home: folder, variables: ["PEN_ESCAPE": escape ? "1" : ""])
        return (script, SpotFrames(script.start()))
    }

    func testItIsAStayingSwiftSpotWhoseDrawIsACommandAndNoEventStartsIt() throws {
        let pen = try example("Pen")

        XCTAssertEqual(pen.mode, .stay)
        XCTAssertNil(pen.read)
        XCTAssertEqual(pen.sources, ["pen"])
        XCTAssertEqual(pen.offers.map(\.id), ["draw"])
        XCTAssertEqual(pen.soleCommand, "draw")
    }

    func testAPressHoldsItsCallWhileTheOverlayShowsAndASecondPressClosesItAndEndsBoth() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await pen(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=draw\n\n")
        try await wait("the overlay") { self.notes(in: folder) == "show\n" }
        XCTAssertEqual(frames.ends, [])
        script.send(text: "call=2\narg=draw\n\n")
        try await wait("the end of both presses") { frames.ends == ["1", "2"] }
        XCTAssertEqual(notes(in: folder), "show\nclose\n")
        script.send(text: "call=3\narg=open\n\n")
        try await wait("a new overlay") { self.notes(in: folder) == "show\nclose\nshow\n" }

        XCTAssertEqual(frames.ends, ["1", "2"])
    }

    func testAStopOfThePressClosesTheOverlay() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await pen(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=draw\n\n")
        try await wait("the overlay") { self.notes(in: folder) == "show\n" }
        script.send(text: "stop=1\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(notes(in: folder), "show\nclose\n")
    }

    func testAnOverlayThatThePersonClosesEndsItsCall() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await pen(in: folder, escape: true)
        defer { script.stop() }

        script.send(text: "call=1\narg=draw\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(notes(in: folder), "show\nclose\n")
    }

    func testTheEndOfStdinEndsTheSpotWhileTheOverlayShows() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await pen(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=draw\n\n")
        try await wait("the overlay") { self.notes(in: folder) == "show\n" }
        script.end()

        try await wait("the end of the spot") { !script.isRunning && frames.ended }
    }

    func testTheRealOverlayTypeChecks() async throws {
        try await typechecks("pen")
    }
}
