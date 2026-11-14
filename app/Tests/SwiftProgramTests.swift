import CryptoKit
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

    private func tools(selector: String = "exit 0", compiler: String = "exit 0") throws -> SwiftProgram {
        let place = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(selector)\n".writeScript(to: place.appendingPathComponent("xcode-select"))
        try "#!/bin/sh\n\(compiler)\n".writeScript(to: place.appendingPathComponent("swiftc"))
        try "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -output ] && printf built > \"$2\"; shift; done\n".writeScript(to: place.appendingPathComponent("lipo"))
        return SwiftProgram(tools: place)
    }

    private func script(_ path: String, _ text: String) throws {
        let url = folder.appendingPathComponent(path.inSpotFolder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.writeScript(to: url)
    }

    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var date = Date()

        var now: Date { lock.withLock { date } }

        func move(days: Double) {
            lock.withLock { date += days * 86_400 }
        }
    }

    private let clock = Clock()
    private var cache: URL { folder.appendingPathComponent("cache") }

    private func caching(_ program: String = "int main(void) { return puts(\"text=program\") < 0; }", cache: URL? = nil) throws -> SwiftProgram {
        let place = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        let c = place.appendingPathComponent("program.c")
        try ("#include <stdio.h>\n" + program + "\n").write(to: c, atomically: true, encoding: .utf8)
        try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/builds'\nwhile [ $# -gt 1 ]; do [ \"$1\" = -o ] && /usr/bin/cc -x c '\(c.path)' -o \"$2\"; shift; done\n"
            .writeScript(to: place.appendingPathComponent("swiftc"))
        let clock = clock
        return SwiftProgram(tools: place, cache: cache ?? self.cache, now: { clock.now })
    }

    private var builds: Int {
        ((try? String(contentsOf: folder.appendingPathComponent("builds"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    private func source(_ text: String = "#!/bin/sh\necho text=source\n") throws -> URL {
        let url = folder.appendingPathComponent("hello.swift")
        try text.writeScript(to: url)
        return url
    }

    private func wait(_ what: String, until fact: () -> Bool) async throws {
        for _ in 0..<1000 {
            if fact() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    func testASwiftScriptRunsItsSourceWhileItBuildsOnceAndThenItsProgram() async throws {
        let program = try caching()
        let source = try source()
        let runs = SpotRuns(swift: program)
        defer { runs.quit() }
        let spot = Spot(id: "hello", name: "Hello", url: source)

        let first = try await runs.answer(of: spot, .open)
        try await wait("the build") { program.runnable(for: source) != source }
        let later = try await runs.answer(of: spot, .open)

        XCTAssertEqual(first, "text=source\n")
        XCTAssertEqual(later, "text=program\n")
        XCTAssertEqual(builds, 1)
    }

    func testAChangedSourceBuildsAgain() async throws {
        let program = try caching()
        let source = try source()
        _ = program.runnable(for: source)
        try await wait("the first build") { program.runnable(for: source) != source }

        try "#!/bin/sh\necho text=changed\n".writeScript(to: source)

        XCTAssertEqual(program.runnable(for: source), source)
        try await wait("the second build") { program.runnable(for: source) != source }
        XCTAssertEqual(builds, 2)
    }

    func testABadCachedProgramIsBuiltAgain() async throws {
        let program = try caching()
        let source = try source()
        _ = program.runnable(for: source)
        try await wait("the first build") { program.runnable(for: source) != source }
        let cached = program.runnable(for: source)

        try Data("bad".utf8).write(to: cached)

        XCTAssertEqual(program.runnable(for: source), source)
        try await wait("the second build") { program.runnable(for: source) != source }
        XCTAssertEqual(builds, 2)
        let printed = try await ScriptProcess.output(url: cached)
        XCTAssertEqual(printed, "text=program\n")
    }

    func test_P6_aSourceBuildsAProgramThatRunsForBothKindsOfMac() async throws {
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
            XCTAssertEqual((error as? SpotError)?.reason, "To share a Swift spot, install the Command Line Tools: xcode-select --install")
        }
    }

    func testASourceThatDoesNotCompileSaysWhy() async throws {
        let program = try tools(compiler: "echo 'a.swift:1: bad line' >&2; exit 1")

        do {
            _ = try await program.build(source: source)
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "This Swift spot does not compile. a.swift:1: bad line")
        }
    }

    func testASharedSwiftScriptTravelsWithItsProgram() async throws {
        let spot = try SpotPackage(files: [
            .init(path: "home.spot/hello.swift", isExecutable: true, contents: source),
            .init(path: "home.spot/shared.swift", isExecutable: false, contents: source),
            .init(path: "home.spot/other.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))
        ])

        XCTAssertTrue(spot.needsCompile)
        let compiled = try await spot.compiled(by: tools())

        XCTAssertFalse(compiled.needsCompile)
        XCTAssertEqual(compiled.files.map(\.path), ["home.spot/hello.swift", "home.spot/shared.swift", "home.spot/other.sh", "home.spot/hello.program"])
        let added = try XCTUnwrap(compiled.files.last)
        XCTAssertTrue(added.isExecutable)
        XCTAssertEqual(added.contents, Data("built".utf8))
    }

    func testAProgramThatAlreadyTravelsIsNotBuiltAgain() async throws {
        let spot = try SpotPackage(files: [
            .init(path: "hello.spot/hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.spot/hello.program", isExecutable: true, contents: Data("old".utf8))
        ])

        XCTAssertFalse(spot.needsCompile)
        let compiled = try await spot.compiled(by: tools(selector: "exit 2"))

        XCTAssertEqual(compiled, spot)
    }

    func testSharingTakesTheProgramBesideATopLevelScript() throws {
        try script("hello.swift", "#!/bin/sh\n# title=Hello\n")
        try script("hello.program", "#!/bin/sh\n")
        let place = SpotsFolder(url: folder)
        let scan = try place.scan()

        let spot = try SpotPackage(sharing: try XCTUnwrap(scan.spots.first), from: scan)

        XCTAssertEqual(spot.files.map(\.path), ["hello.spot/hello.program", "hello.spot/hello.swift"])
    }

    func testAProgramIsNotASpotOfItsOwn() throws {
        try script("hello.swift", "#!/bin/sh\n# title=Hello\n")
        try script("hello.program", "#!/bin/sh\n")

        let scan = try SpotsFolder(url: folder).scan()

        XCTAssertEqual(scan.spots.map(\.name), ["Hello"])
        XCTAssertEqual(scan.refused, [])
    }

    func test_P6_aProgramRunsInPlaceOfItsSource() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        try script("hello.program", "#!/bin/sh\necho program\n")
        let command = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)

        let answer = try await SpotRuns().answer(of: command, .open)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "program")
    }

    func testASourceWithNoProgramRunsAsAScript() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        let command = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)

        let answer = try await SpotRuns().answer(of: command, .open)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "source")
    }

    func testDeletingASpotAlsoTakesItsProgram() throws {
        try script("home/hello.swift", "#!/bin/sh\n")
        try script("home/hello.program", "#!/bin/sh\n")
        try script("home/other.sh", "#!/bin/sh\n")
        let place = SpotsFolder(url: folder)
        let command = try XCTUnwrap(try place.scan().spots.first { $0.id == "home/hello" })
        var discarded: [String] = []

        try place.remove(command) { discarded.append($0.lastPathComponent) }

        XCTAssertEqual(discarded, ["hello.swift", "hello.program"])
    }

    func testTheReviewSaysThatASourceMayNotMatchItsProgram() throws {
        let spot = try SpotPackage(files: [
            .init(path: "hello.spot/hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.spot/hello.program", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))
        ])

        let review = try ReviewSpot(spot: spot, folder: folder)

        XCTAssertEqual(review.name, "Hello")
        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let part = try XCTUnwrap(SpotOutput(text: try review.answer(["read"])).parts.first { $0.id == "review" })
        guard case .text(let text, _, _) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(text.hasPrefix("Hello\n\nProgram that Openspot cannot show\nhello.spot/hello.program\nIt can do all that you can. Add it only if you trust the sender.\nThe source beside it may not match the program.\n\n"), text)
    }

    func testABuiltProgramGetsThePathOfItsScriptAsItsFirstArgument() async throws {
        let program = try caching("int main(int count, char **words) { return printf(\"text=%s\\n\", words[0]) < 0; }")
        let source = try source()
        let runs = SpotRuns(swift: program)
        defer { runs.quit() }
        _ = program.runnable(for: source)
        try await wait("the build") { program.runnable(for: source) != source }

        let answer = try await runs.answer(of: Spot(id: "hello", name: "Hello", url: source), .open)

        XCTAssertEqual(answer, "text=\(source.path)\n")
    }

    private func built(_ sources: [URL], by program: SwiftProgram) async throws -> [URL] {
        var programs: [URL] = []
        for source in sources {
            _ = program.runnable(for: source)
            try await wait("the build") { program.runnable(for: source) != source }
            programs.append(program.runnable(for: source))
        }
        return programs
    }

    private func age(_ file: URL, days: Double) throws {
        try FileManager.default.setAttributes([.modificationDate: clock.now.addingTimeInterval(-days * 86_400)], ofItemAtPath: file.path)
    }

    private func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }

    func testAPruneRemovesEachBuildOfNoSourceAndEachNotRunFor30Days() async throws {
        let program = try caching()
        let used = try source()
        let idle = folder.appendingPathComponent("idle.swift")
        try "#!/bin/sh\necho text=idle\n".writeScript(to: idle)
        let builds = try await built([used, idle], by: program)
        let orphan = cache.appendingPathComponent(String(repeating: "a", count: 64))
        try FileManager.default.copyItem(at: builds[0], to: orphan)
        try builds.forEach { try age($0, days: 31) }
        _ = program.runnable(for: used)

        await program.prune(keeping: [used, idle])?.value

        XCTAssertEqual([exists(builds[0]), exists(builds[1]), exists(orphan)], [true, false, false])
    }

    func testAPruneRunsAtMostOnceADay() async throws {
        let program = try caching()
        let source = try source()
        let builds = try await built([source], by: program)
        await program.prune(keeping: [source])?.value

        XCTAssertNil(program.prune(keeping: []))
        XCTAssertTrue(exists(builds[0]))
        clock.move(days: 1.1)
        await program.prune(keeping: [])?.value
        XCTAssertFalse(exists(builds[0]))
    }

    func testAPruneKeepsABuildWhileItRuns() async throws {
        let program = try caching("int main(void) { return getchar() == EOF ? 0 : 1; }")
        let source = try source()
        let builds = try await built([source], by: program)
        let process = Process()
        let input = Pipe()
        process.executableURL = builds[0]
        process.standardInput = input
        try process.run()

        await program.prune(keeping: [])?.value
        XCTAssertTrue(exists(builds[0]))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        clock.move(days: 1.1)
        await program.prune(keeping: [])?.value

        XCTAssertFalse(exists(builds[0]))
    }

    private var root: URL { folder.appendingPathComponent("swift", isDirectory: true) }

    private func caching(config: String) throws -> SwiftProgram {
        try caching(cache: SwiftProgram.folder(of: folder.appendingPathComponent(config), in: root))
    }

    private func sha(_ file: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    }

    func testEachConfigFolderKeepsItsBuildsInAFolderOfItsOwn() throws {
        let home = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home"), isDirectory: true)
        let release = SwiftProgram.folder(of: home.appendingPathComponent(".config/openspot"), in: root)
        let debug = SwiftProgram.folder(of: folder.appendingPathComponent(".temp/openspot"), in: root)

        XCTAssertNotEqual(release, debug)
        XCTAssertEqual([release.deletingLastPathComponent(), debug.deletingLastPathComponent()], [root, root])
        XCTAssertEqual(release.lastPathComponent.count, 12)
        XCTAssertEqual(SwiftProgram().cache, SwiftProgram.folder(of: home.appendingPathComponent(".config/openspot"), in: home.appendingPathComponent("Library/Caches/dev.openspot/swift")))
    }

    func testAPruneOfOneConfigFolderKeepsTheBuildsOfAnother() async throws {
        let debug = try caching(config: "debug")
        let release = try caching(config: "release")
        let source = try source()
        let kept = try await built([source], by: release)
        try age(kept[0], days: 31)

        await debug.prune(keeping: [])?.value

        XCTAssertTrue(exists(kept[0]))
    }

    func testABuildInTheOldSharedFolderMovesIntoTheFolderOfItsConfig() async throws {
        let program = try caching(config: "release")
        let source = try source()
        let other = try await built([source], by: try caching(config: "other"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let old = root.appendingPathComponent(try sha(source))
        try FileManager.default.moveItem(at: other[0], to: old)

        let runnable = program.runnable(for: source)

        XCTAssertEqual(runnable, SwiftProgram.folder(of: folder.appendingPathComponent("release"), in: root).appendingPathComponent(try sha(source)))
        XCTAssertFalse(exists(old))
        XCTAssertEqual(builds, 1)
    }

    func testAPruneRemovesAnOldSharedBuildThatDidNotRunFor30Days() async throws {
        let program = try caching(config: "release")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stale = root.appendingPathComponent(String(repeating: "a", count: 64))
        let fresh = root.appendingPathComponent(String(repeating: "b", count: 64))
        try Data("x".utf8).write(to: stale)
        try Data("x".utf8).write(to: fresh)
        try age(stale, days: 31)

        await program.prune(keeping: [])?.value

        XCTAssertEqual([exists(stale), exists(fresh)], [false, true])
    }
}
