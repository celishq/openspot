import XCTest
@testable import OpenspotCore

@MainActor
final class SwiftProgramTests: XCTestCase {
    private var folder: URL!
    private let source = Data("#!/usr/bin/env swift\n// title=Hello\nprint(\"hello\")\n".utf8)

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-swift-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    /// A folder of stand-ins for the build commands, which writes `built` as the program.
    private func tools(selector: String = "exit 0", compiler: String = "exit 0") throws -> SwiftProgram {
        let place = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(selector)\n".writeScript(to: place.appendingPathComponent("xcode-select"))
        try "#!/bin/sh\n\(compiler)\n".writeScript(to: place.appendingPathComponent("swiftc"))
        try "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -output ] && printf built > \"$2\"; shift; done\n".writeScript(to: place.appendingPathComponent("lipo"))
        return SwiftProgram(tools: place)
    }

    private func script(_ path: String, _ text: String) throws {
        let url = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.writeScript(to: url)
    }

    func testASourceBuildsAProgramThatRunsForBothKindsOfMac() async throws {
        let built = try await SwiftProgram().build(source: source)

        let program = folder.appendingPathComponent("hello")
        try built.write(to: program)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)
        let printed = try await ScriptProcess.output(url: program)
        XCTAssertEqual(printed, "hello\n")
        let kinds = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/lipo"), arguments: ["-archs", program.path])
        XCTAssertTrue(kinds.contains("arm64") && kinds.contains("x86_64"), kinds)
    }

    func testAMacWithNoToolsSaysHowToGetThem() async throws {
        let program = try tools(selector: "exit 2")

        do {
            _ = try await program.build(source: source)
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? PluginError)?.reason, "To share a Swift spot, install the Command Line Tools: xcode-select --install")
        }
    }

    func testASourceThatDoesNotCompileSaysWhy() async throws {
        let program = try tools(compiler: "echo 'a.swift:1: bad line' >&2; exit 1")

        do {
            _ = try await program.build(source: source)
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? PluginError)?.reason, "This Swift spot does not compile. a.swift:1: bad line")
        }
    }

    func testASharedSwiftScriptTravelsWithItsProgram() async throws {
        let spot = try SharedSpot(files: [
            .init(path: "home/hello.swift", isExecutable: true, contents: source),
            .init(path: "home/shared.swift", isExecutable: false, contents: source),
            .init(path: "home/other.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))
        ])

        XCTAssertTrue(spot.needsCompile)
        let compiled = try await spot.compiled(by: tools())

        XCTAssertFalse(compiled.needsCompile)
        XCTAssertEqual(compiled.files.map(\.path), ["home/hello.swift", "home/shared.swift", "home/other.sh", "home/hello.program"])
        let added = try XCTUnwrap(compiled.files.last)
        XCTAssertTrue(added.isExecutable)
        XCTAssertEqual(added.contents, Data("built".utf8))
    }

    func testAProgramThatAlreadyTravelsIsNotBuiltAgain() async throws {
        let spot = try SharedSpot(files: [
            .init(path: "hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.program", isExecutable: true, contents: Data("old".utf8))
        ])

        XCTAssertFalse(spot.needsCompile)
        let compiled = try await spot.compiled(by: tools(selector: "exit 2"))

        XCTAssertEqual(compiled, spot)
    }

    func testSharingTakesTheProgramBesideATopLevelScript() throws {
        try script("hello.swift", "#!/bin/sh\n# title=Hello\n")
        try script("hello.program", "#!/bin/sh\n")
        let place = PluginFolder(url: folder)
        let scan = try place.scan()

        let spot = try SharedSpot(sharing: try XCTUnwrap(scan.commands.first), from: scan)

        XCTAssertEqual(spot.files.map(\.path), ["hello.swift", "hello.program"])
    }

    func testAProgramIsNotASpotOfItsOwn() throws {
        try script("hello.swift", "#!/bin/sh\n# title=Hello\n")
        try script("hello.program", "#!/bin/sh\n")

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.commands.map(\.name), ["Hello"])
        XCTAssertEqual(scan.refused, [])
    }

    func testAProgramRunsInPlaceOfItsSource() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        try script("hello.program", "#!/bin/sh\necho program\n")
        let command = try XCTUnwrap(try PluginFolder(url: folder).scan().commands.first)

        let answer = try await SpotRuns().answer(of: command, .run)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "program")
    }

    func testASourceWithNoProgramRunsAsAScript() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        let command = try XCTUnwrap(try PluginFolder(url: folder).scan().commands.first)

        let answer = try await SpotRuns().answer(of: command, .run)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "source")
    }

    func testDeletingASpotAlsoTakesItsProgram() throws {
        try script("hello.swift", "#!/bin/sh\n")
        try script("hello.program", "#!/bin/sh\n")
        try script("other.sh", "#!/bin/sh\n")
        let place = PluginFolder(url: folder)
        let command = try XCTUnwrap(try place.scan().commands.first { $0.id == "hello" })
        var discarded: [String] = []

        try place.remove(command) { discarded.append($0.lastPathComponent) }

        XCTAssertEqual(discarded, ["hello.swift", "hello.program"])
    }

    func testTheReviewSaysThatASourceMayNotMatchItsProgram() throws {
        let spot = try SharedSpot(files: [
            .init(path: "hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.program", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))
        ])

        let review = try ReviewSpot(spot: spot, folder: folder)

        XCTAssertEqual(review.name, "Hello")
        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let part = try XCTUnwrap(PluginOutput(text: try review.answer(["read"])).parts.first { $0.id == "review" })
        guard case .text(let text, _, _) = part.control else { throw PluginError.badForm }
        XCTAssertTrue(text.hasPrefix("Program that Openspot cannot show\nhello.program\nIt can do all that you can. Add it only if you trust the sender.\nThe source beside it may not match the program.\n\n"), text)
    }
}
