import XCTest
@testable import OpenspotCore

final class ConfettiSpotTests: SampleSpotsCase {
    private var spotFolder: URL {
        examples.deletingLastPathComponent().appendingPathComponent("spots/confetti.spot")
    }

    private var confetti: Spot {
        get throws {
            try XCTUnwrap(try scan.spots.first { $0.id == "confetti" })
        }
    }

    private func program(in folder: URL) async throws -> URL {
        let main = folder.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: spotFolder.appendingPathComponent("confetti.swift"), to: main)
        let sources = try FileManager.default.contentsOfDirectory(atPath: spotFolder.appendingPathComponent("confetti").path).filter { $0.hasSuffix(".swift") }
        let program = folder.appendingPathComponent("confetti")
        let paths = [main.path] + sources.map { spotFolder.appendingPathComponent("confetti/\($0)").path }
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-Onone", "-module-name", "Spot"] + paths + ["-o", program.path], limit: 300, base: TestEnvironment.values)
        return program
    }

    private func staying(_ program: URL, data: URL, tools: URL) -> ScriptProcess {
        ScriptProcess(url: program, name: spotFolder.appendingPathComponent("confetti.swift").path, mode: .stays, variables: ["OPENSPOT_DATA": data.path], base: ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": data.path])
    }

    private func answer(_ blocks: String, from script: ScriptProcess, until end: String) async throws -> [String] {
        let frames = script.start()
        script.send(text: blocks)
        var seen: [String] = []
        for try await frame in frames {
            seen.append(frame)
            if FrameRoot(text: frame).end == end { break }
        }
        return seen
    }

    func testItIsAStayingSwiftSpotWhosePlayIsACommandAndNoEventStartsIt() throws {
        let spot = try confetti

        XCTAssertEqual(spot.mode, .stay)
        XCTAssertFalse(spot.triggers.shows)
        XCTAssertEqual(spot.commands.map(\.id), ["play"])
        XCTAssertEqual(spot.settings.map(\.id), ["look"])
        XCTAssertEqual(spot.sources, ["confetti"])
        XCTAssertEqual(spot.soleCommand, "play")
        XCTAssertTrue(spot.opensToKeys)
    }

    func testTheLookRowAsksForEachLookWithTheKeptOneChosenAndTheSampleShowsTheSameForm() async throws {
        let folder = try temporaryFolder()
        let script = staying(try await program(in: folder), data: folder, tools: folder)
        defer { script.stop() }

        let frames = try await answer("call=1\narg=look\nsetting.look=Gold\n\n", from: script, until: "1")
        let sample = try await ScriptProcess.output(url: spotFolder.appendingPathComponent("sample.sh"), base: TestEnvironment.values)

        let form = try XCTUnwrap(frames.compactMap { ItemForm(output: Frame(text: $0)) }.first)
        let choice = try XCTUnwrap(form.soleChoice)
        XCTAssertEqual(choice.value, "gold")
        XCTAssertEqual(choice.options.map(\.id), ["colorful", "gold", "metallic"])
        let sampled = try XCTUnwrap(ItemForm(output: Frame(text: sample))?.soleChoice)
        XCTAssertEqual(sampled.options, choice.options)
    }

    func testAPickedLookIsKeptByItsTitleInTheSettingAndALookThatCannotPlaySaysWhyWithNoWindow() async throws {
        let folder = try temporaryFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("looks"), withIntermediateDirectories: true)
        try "title=Broken\ncolor=nope\n".write(to: folder.appendingPathComponent("looks/broken.look"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/calls'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let script = staying(try await program(in: folder), data: folder, tools: folder.appendingPathComponent("tools"))
        defer { script.stop() }

        _ = try await answer("call=1\narg=look\ninput.look=broken\n\n", from: script, until: "1")

        XCTAssertEqual(try read("calls", in: folder), "setting set look Broken\ntoast Broken cannot play. Line 2: `nope` is not a colour. Write it as `#RRGGBB`, such as `#FF4D6D`.\n")
    }

    func testAPlayOfTheKeptLookThatCannotPlayEndsItsCallAndTheEndOfStdinEndsTheSpot() async throws {
        let folder = try temporaryFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("looks"), withIntermediateDirectories: true)
        try "title=Broken\nshape=moon\n".write(to: folder.appendingPathComponent("looks/broken.look"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/calls'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let script = staying(try await program(in: folder), data: folder, tools: folder.appendingPathComponent("tools"))

        _ = try await answer("call=1\narg=show\n\ncall=2\narg=play\nsetting.look=Broken\n\n", from: script, until: "2")
        script.end()

        XCTAssertTrue(try read("calls", in: folder).hasPrefix("toast Broken cannot play. Line 2: there is no shape `moon`."))
        try await wait("the end of the spot") { !script.isRunning }
    }
}
