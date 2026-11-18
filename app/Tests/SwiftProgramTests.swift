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

    private func script(_ path: String, _ text: String, toml: String? = nil) throws {
        let url = folder.appendingPathComponent(path.inSpotFolder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let toml { try text.writeScript(to: url, toml: toml) } else { try text.writeScript(to: url) }
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

    private func program(of text: String, named name: String = "hello.swift", with more: [SwiftBuild.File] = []) -> String {
        SwiftProgram.path(beside: name, hash: SwiftProgram.name(of: Data(text.utf8), with: more))
    }

    private var carried: String {
        SwiftProgram.path(beside: "hello.swift", hash: SwiftProgram.name(of: source, with: []))
    }

    private var builds: Int {
        ((try? String(contentsOf: folder.appendingPathComponent("builds"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    private func source(_ text: String = "#!/bin/sh\necho text=source\n") throws -> URL {
        let url = folder.appendingPathComponent("hello.swift")
        try text.writeScript(to: url)
        return url
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
        XCTAssertEqual(compiled.files.map(\.path), ["home.spot/hello.swift", "home.spot/shared.swift", "home.spot/other.sh", "home.spot/\(carried)"])
        let added = try XCTUnwrap(compiled.files.last)
        XCTAssertTrue(added.isExecutable)
        XCTAssertEqual(added.contents, Data("built".utf8))
    }

    func testAProgramThatAlreadyTravelsIsNotBuiltAgain() async throws {
        let spot = try SpotPackage(files: [
            .init(path: "hello.spot/hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.spot/\(carried)", isExecutable: true, contents: Data("old".utf8))
        ])

        XCTAssertFalse(spot.needsCompile)
        let compiled = try await spot.compiled(by: tools(selector: "exit 2"))

        XCTAssertEqual(compiled, spot)
    }

    func testAShareLeavesOutEachProgramAndBuildsOneFromTheSourcesItShips() async throws {
        let built = program(of: "#!/bin/sh\n")
        try script("hello.swift", "#!/bin/sh\n", toml: "title = 'Hello'")
        try script(built, "#!/bin/sh\necho unproven\n")
        try script("hello.program", "#!/bin/sh\n")
        try script("hello.\(String(repeating: "0", count: 64)).program", "#!/bin/sh\n")
        let place = SpotsFolder(url: folder)
        let scan = try place.scan()

        let spot = try SpotPackage(sharing: try XCTUnwrap(scan.spots.first), from: scan)
        let compiled = try await spot.compiled(by: tools())

        XCTAssertEqual(spot.files.map(\.path), ["hello.spot/hello.swift", "hello.spot/spot.toml"])
        XCTAssertTrue(spot.needsCompile)
        XCTAssertEqual(compiled.files.map(\.path), ["hello.spot/hello.swift", "hello.spot/spot.toml", "hello.spot/\(built)"])
        XCTAssertEqual(compiled.files.last?.contents, Data("built".utf8))
    }

    func testAProgramIsNotASpotOfItsOwn() throws {
        try script("hello.swift", "#!/bin/sh\n", toml: "title = 'Hello'")
        try script(program(of: "#!/bin/sh\n"), "#!/bin/sh\n")

        let scan = try SpotsFolder(url: folder).scan()

        XCTAssertEqual(scan.spots.map(\.name), ["Hello"])
        XCTAssertEqual(scan.refused, [])
    }

    private func counting(selector: String = "exit 0", compiler: String? = nil, shipped: URL? = nil) throws -> SwiftProgram {
        _ = try caching()
        let place = folder.appendingPathComponent("tools")
        try "#!/bin/sh\necho x >> '\(folder.path)/asks'\n\(selector)\n".writeScript(to: place.appendingPathComponent("xcode-select"))
        if let compiler { try "#!/bin/sh\necho x >> '\(folder.path)/builds'\n\(compiler)\n".writeScript(to: place.appendingPathComponent("swiftc")) }
        let clock = clock
        return SwiftProgram(tools: place, cache: cache, shipped: shipped, now: { clock.now })
    }

    private var asks: Int {
        ((try? String(contentsOf: folder.appendingPathComponent("asks"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    private func carriedSpots() throws -> (several: Spot, single: Spot) {
        let several = try spotOfSeveralFiles()
        try script(program(of: main, with: severalFiles), "#!/bin/sh\necho text=carried\n")
        try script("one.swift", "#!/bin/sh\necho text=source\n", toml: "title = 'One'\non = ['sheet.open']")
        try script(program(of: "#!/bin/sh\necho text=source\n", named: "one.swift"), "#!/bin/sh\necho text=carried\n")
        let single = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first { $0.id == "one" })
        return (several, single)
    }

    func testOnAMacWithTheToolsASpotFromOutsideIsBuiltFromItsSourcesAndItsCarriedProgramDoesNotRun() async throws {
        let spots = try carriedSpots()
        let runs = SpotRuns(swift: try counting())
        defer { runs.quit() }

        let several = try await runs.answer(of: spots.several, .show)
        let single = try await runs.answer(of: spots.single, .show)

        XCTAssertEqual([several, single], ["text=program\n", "text=source\n"])
        try await wait("the build of the spot of one file") { self.builds == 2 }
    }

    func testOnAMacWithNoToolsASpotFromOutsideRunsItsCarriedProgram() async throws {
        let spots = try carriedSpots()
        let runs = SpotRuns(swift: try counting(selector: "exit 2", compiler: "exit 2"))
        defer { runs.quit() }

        let several = try await runs.answer(of: spots.several, .show)
        let single = try await runs.answer(of: spots.single, .show)
        let again = try await runs.answer(of: spots.several, .show)

        XCTAssertEqual([several, single, again], ["text=carried\n", "text=carried\n", "text=carried\n"])
        XCTAssertEqual(asks, 1)
    }

    func testASpotThatShipsInsideOpenspotRunsItsCarriedProgramOnAMacWithTheTools() async throws {
        let spots = try carriedSpots()
        let runs = SpotRuns(swift: try counting(shipped: folder))
        defer { runs.quit() }

        let several = try await runs.answer(of: spots.several, .show)
        let single = try await runs.answer(of: spots.single, .show)

        XCTAssertEqual([several, single], ["text=carried\n", "text=carried\n"])
        XCTAssertEqual(builds, 0)
        XCTAssertEqual(asks, 0)
    }

    private func fault(of swift: SwiftProgram, _ spot: Spot) async -> String? {
        do {
            _ = try await swift.built(spot.url, with: spot.sources)
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    func testASpotThatDoesNotCompileIsNotBuiltAgainUntilOneOfItsFilesChanges() async throws {
        let spot = try spotOfSeveralFiles()
        let swift = try counting(compiler: "echo '/tmp/x/more/more/Mark.swift:1:1: error: bad mark' >&2; exit 1")

        let first = await fault(of: swift, spot)
        let second = await fault(of: swift, spot)
        let built = builds
        try Data("func mark() -> String { \"?\" }\n".utf8).write(to: folder.appendingPathComponent("hello.spot/more/Mark.swift"))
        _ = await fault(of: swift, spot)

        XCTAssertEqual(first, "This Swift spot does not compile. Mark.swift:1:1: error: bad mark")
        XCTAssertEqual(second, first)
        XCTAssertEqual(built, 1)
        XCTAssertEqual(builds, 2)
        XCTAssertEqual(asks, 1)
    }

    func testAFailedBuildThatNamesNoSourceIsBuiltAgain() async throws {
        let spot = try spotOfSeveralFiles()
        let swift = try counting(compiler: "echo 'error: you have not agreed to the Xcode license' >&2; exit 1")

        _ = await fault(of: swift, spot)
        _ = await fault(of: swift, spot)

        XCTAssertEqual(builds, 2)
        XCTAssertEqual(asks, 1)
    }

    func testAMacWithNoToolsIsAskedForThemOncePerRun() async throws {
        let spot = try spotOfSeveralFiles()
        let swift = try counting(selector: "exit 1")

        let first = await fault(of: swift, spot)
        let second = await fault(of: swift, spot)

        XCTAssertEqual(first, "To build a Swift spot, install the Command Line Tools: xcode-select --install")
        XCTAssertEqual(second, first)
        XCTAssertEqual(asks, 1)
        XCTAssertEqual(builds, 0)
    }

    func testTheNameOfAProgramIsReadAgainOnlyWhenTheStampOfOneOfItsFilesChanges() throws {
        let spot = try spotOfSeveralFiles()
        let mark = folder.appendingPathComponent("hello.spot/more/Mark.swift")
        let first = try SwiftProgram.name(of: spot.url, with: spot.sources)
        var info = stat()
        XCTAssertEqual(stat(mark.path, &info), 0)
        let handle = try FileHandle(forWritingTo: mark)
        try handle.write(contentsOf: Data("func mark() -> String { \"?\" }\n".utf8))
        try handle.close()
        let times = [info.st_atimespec, info.st_mtimespec]
        XCTAssertEqual(utimensat(AT_FDCWD, mark.path, times, 0), 0)

        let unstamped = try SwiftProgram.name(of: spot.url, with: spot.sources)
        try Data("func mark() -> String { \"?!\" }\n".utf8).write(to: mark)
        let changed = try SwiftProgram.name(of: spot.url, with: spot.sources)

        XCTAssertEqual(first, SwiftProgram.name(of: Data(main.utf8), with: severalFiles))
        XCTAssertEqual(unstamped, first)
        XCTAssertNotEqual(changed, first)
    }

    func testTheStampOfASwiftSpotChangesWithAnEditOfEachSourceItNames() throws {
        let spot = try spotOfSeveralFiles()
        let kept = KeptScan()
        let spots = SpotsFolder(url: folder)
        let first = kept.load(spots)

        XCTAssertEqual(kept.load(spots).stamp(of: spot), first.stamp(of: spot))
        for (path, text) in [("hello.spot/words.swift", "let word = \"changed\"\n"), ("hello.spot/more/Mark.swift", "func mark() -> String { \"changed\" }\n")] {
            let before = kept.load(spots)
            try text.write(to: folder.appendingPathComponent(path), atomically: false, encoding: .utf8)
            let after = kept.load(spots)

            XCTAssertNotEqual(after.stamp(of: spot), before.stamp(of: spot), path)
            XCTAssertNotEqual(after.stamp, before.stamp, path)
            XCTAssertTrue(spots.reads(folder.appendingPathComponent(path).path), path)
        }
        XCTAssertFalse(spots.reads(folder.appendingPathComponent("hello.spot/more/notes.txt").path))
        XCTAssertFalse(spots.reads(folder.appendingPathComponent("hello.spot/.build/Mark.swift").path))
    }

    func testASourceThatIsNotAPlainPathIsRefusedByName() throws {
        for (index, source) in ["./words.swift", "more/", "more//Mark.swift", "."].enumerated() {
            try script("s\(index).swift", "#!/usr/bin/env swift\n", toml: "title = 'S\(index)'\nsource = ['\(source)']")
        }

        let refused = try SpotsFolder(url: folder).scan().refused

        XCTAssertEqual(refused.map(\.reason), ["./words.swift", "more/", "more//Mark.swift", "."].enumerated().map { index, source in
            "S\(index) has `source=\(source)`, which is not a plain path. Write it with no `.`, no `..` and no `/` at its start or end, such as `source=model`."
        })
    }

    func testAProgramRunsInPlaceOfItsSourceOnAMacWithNoTools() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        try script(program(of: "#!/bin/sh\necho source\n"), "#!/bin/sh\necho program\n")
        let command = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)

        let answer = try await SpotRuns(swift: try tools(selector: "exit 2", compiler: "exit 2")).answer(of: command, .open)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "program")
    }

    func testAProgramWhoseNameHoldsNoHashOfTheSourceDoesNotRun() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        try script("hello.program", "#!/bin/sh\necho program\n")
        try script(program(of: "#!/bin/sh\necho an older source\n"), "#!/bin/sh\necho old program\n")
        let command = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)

        let answer = try await SpotRuns(swift: try tools(compiler: "exit 1")).answer(of: command, .open)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "source")
    }

    func testASourceWithNoProgramRunsAsAScript() async throws {
        try script("hello.swift", "#!/bin/sh\necho source\n")
        let command = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)

        let answer = try await SpotRuns().answer(of: command, .open)

        XCTAssertEqual(answer.trimmingCharacters(in: .newlines), "source")
    }

    func testDeletingASpotAlsoTakesItsProgram() throws {
        try script("home/hello.swift", "#!/bin/sh\n", toml: "")
        try script("home/hello.\(String(repeating: "0", count: 64)).program", "#!/bin/sh\n")
        try script("home/other.sh", "#!/bin/sh\n", toml: "")
        let place = SpotsFolder(url: folder)
        let command = try XCTUnwrap(try place.scan().spots.first { $0.id == "home/hello" })
        var discarded: [String] = []

        try place.remove(command) { discarded.append($0.lastPathComponent) }

        XCTAssertEqual(discarded, ["hello.swift", "hello.\(String(repeating: "0", count: 64)).program"])
    }

    func testTheReviewSaysThatASourceMayNotMatchItsProgram() throws {
        let spot = try SpotPackage(files: [
            .init(path: "hello.spot/hello.swift", isExecutable: true, contents: source),
            .init(path: "hello.spot/\(carried)", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))
        ])

        let review = try ReviewSpot(spot: spot, folder: folder)

        XCTAssertEqual(review.name, "Hello")
        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let part = try XCTUnwrap(SpotOutput(text: try review.answer(["show"])).parts.first { $0.id == "review" })
        guard case .text(let text, _, _) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(text.hasPrefix("Hello\n\nProgram that Openspot cannot show\nhello.spot/\(carried)\nIt can do all that you can. Add it only if you trust the sender.\nThe source beside it may not match the program.\n\n"), text)
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

    private let main = "#!/usr/bin/env swift\nprint(\"text=\\(word)\\(mark())\")\n"

    private func spotOfSeveralFiles(word: String = "hello") throws -> Spot {
        try script("hello.swift", main, toml: "title = 'Hello'\non = ['sheet.open']\nsource = ['words.swift', 'more']")
        try Data("let word = \"\(word)\"\n".utf8).write(to: folder.appendingPathComponent("hello.spot/words.swift"))
        let more = folder.appendingPathComponent("hello.spot/more")
        try FileManager.default.createDirectory(at: more, withIntermediateDirectories: true)
        try Data("func mark() -> String { \"!\" }\n".utf8).write(to: more.appendingPathComponent("Mark.swift"))
        try Data("not Swift".utf8).write(to: more.appendingPathComponent("notes.txt"))
        let scan = try SpotsFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        return try XCTUnwrap(scan.spots.first)
    }

    private var severalFiles: [SwiftBuild.File] {
        [.init(name: "words.swift", data: Data("let word = \"hello\"\n".utf8)), .init(name: "more/Mark.swift", data: Data("func mark() -> String { \"!\" }\n".utf8))]
    }

    private func cachingWithTools(_ program: String = "int main(void) { return puts(\"text=program\") < 0; }") throws -> SwiftProgram {
        let swift = try caching(program)
        try "#!/bin/sh\nexit 0\n".writeScript(to: folder.appendingPathComponent("tools/xcode-select"))
        try "#!/bin/sh\nfirst=$2\nwhile [ $# -gt 0 ]; do [ \"$1\" = -output ] && /bin/cp \"$first\" \"$2\"; shift; done\n".writeScript(to: folder.appendingPathComponent("tools/lipo"))
        return swift
    }

    private func stayingSpot() throws -> Spot {
        try script("slow.swift", "#!/usr/bin/env swift\nprint(mark())\n", toml: "title = 'Slow'\nmode = 'stay'\non = ['sheet.open']\nsource = ['more']")
        let more = folder.appendingPathComponent("slow.spot/more")
        try FileManager.default.createDirectory(at: more, withIntermediateDirectories: true)
        try Data("func mark() -> String { \"!\" }\n".utf8).write(to: more.appendingPathComponent("Mark.swift"))
        return try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first)
    }

    func testTheSheetOfAStayingSpotThatIsBeingBuiltOpensAfterAPauseAndSaysSo() async throws {
        let release = folder.appendingPathComponent("release").path
        _ = try tools(compiler: "n=0; while [ ! -f '\(release)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done\necho 'main.swift:1:1: error: stopped' >&2\nexit 1")
        let clock = FakeClock()
        let runs = SpotRuns(clock: clock.value, swift: SwiftProgram(tools: folder.appendingPathComponent("tools"), cache: cache))
        defer { runs.quit() }
        let sheet = runs.sheet(for: try stayingSpot())
        var isReady = false
        var failures: [String] = []
        sheet.onReport = { report in
            if case .failure(let text) = report { failures.append(text) }
        }

        runs.panelOpened()
        sheet.open { isReady = true }
        try await wait("the pause before the sheet says that the spot is being built") { clock.isSleeping(for: 0.5) }
        XCTAssertFalse(isReady)
        XCTAssertNil(sheet.list.loadingWords)
        clock.advance(by: 0.5)
        try await wait("the open sheet") { isReady }

        XCTAssertTrue(sheet.list.isLoading)
        XCTAssertEqual(sheet.list.loadingWords, "Openspot is building Slow. This takes about half a minute, once.")

        FileManager.default.createFile(atPath: release, contents: Data())
        try await wait("the end of the build") { !sheet.list.isLoading }
        XCTAssertNil(sheet.list.loadingWords)
    }

    func testTheSheetOfAStayingSpotThatIsBuiltStaysHeldForItsAnswerAndSaysNothing() async throws {
        let swift = try cachingWithTools("int main(void) { char line[64]; while (fgets(line, sizeof line, stdin)) {} return 0; }")
        let clock = FakeClock()
        let runs = SpotRuns(clock: clock.value, swift: swift)
        defer { runs.quit() }
        let spot = try stayingSpot()
        _ = try await swift.built(spot.url, with: spot.sources)
        let sheet = runs.sheet(for: spot)
        var isReady = false

        runs.panelOpened()
        sheet.open { isReady = true }
        try await wait("the pause after which a spot that is being built says so") { clock.isSleeping(for: 0.5) }
        try await wait("the start of the built program") { runs.processes.contains(where: \.isRunning) }
        clock.advance(by: 0.5)
        try await wait("the end of the pause") { sheet.pauses[SpotRun.buildKey] == nil }

        XCTAssertFalse(isReady)
        XCTAssertNil(sheet.list.loadingWords)
    }

    func testASwiftSpotIsBuiltFromItsFileAndEachSourceItsHeaderNames() async throws {
        let spot = try spotOfSeveralFiles()
        let runs = SpotRuns(swift: SwiftProgram(cache: cache))
        defer { runs.quit() }

        let answer = try await runs.answer(of: spot, .show)

        XCTAssertEqual(spot.sources, ["words.swift", "more"])
        XCTAssertEqual(answer, "text=hello!\n")
    }

    func testASpotOfSeveralFilesIsBuiltOnceAndAgainWhenOneOfThemChanges() async throws {
        let swift = try cachingWithTools()
        let spot = try spotOfSeveralFiles()
        let runs = SpotRuns(swift: swift)
        defer { runs.quit() }

        let first = try await runs.answer(of: spot, .show)
        let second = try await runs.answer(of: spot, .show)
        let built = builds
        try Data("func mark() -> String { \"?\" }\n".utf8).write(to: folder.appendingPathComponent("hello.spot/more/Mark.swift"))
        let third = try await runs.answer(of: spot, .show)

        XCTAssertEqual([first, second, third], ["text=program\n", "text=program\n", "text=program\n"])
        XCTAssertEqual(built, 1)
        XCTAssertEqual(builds, 2)
        let line = try XCTUnwrap(String(contentsOf: folder.appendingPathComponent("builds"), encoding: .utf8).split(separator: "\n").first)
        XCTAssertTrue(line.contains("/main.swift ") && line.contains("/more/words.swift ") && line.contains("/more/more/Mark.swift "), String(line))
        XCTAssertFalse(line.contains("notes.txt"), String(line))
    }

    func testTwoCallsAtOnceOfASpotOfSeveralFilesShareOneBuild() async throws {
        let swift = try cachingWithTools()
        let spot = try spotOfSeveralFiles()

        async let first = swift.built(spot.url, with: spot.sources)
        async let second = swift.built(spot.url, with: spot.sources)
        let programs = try await [first, second]

        XCTAssertEqual(programs[0], programs[1])
        XCTAssertEqual(builds, 1)
    }

    func testASpotOfSeveralFilesThatDoesNotCompileFailsWithTheFirstError() async throws {
        let spot = try spotOfSeveralFiles()
        let runs = SpotRuns(swift: try tools(compiler: "echo '/tmp/x/main.swift:6:7: error: cannot find mark' >&2; echo 'more' >&2; exit 1"))
        defer { runs.quit() }

        do {
            _ = try await runs.answer(of: spot, .show)
            XCTFail("It must not run.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "This Swift spot does not compile. main.swift:6:7: error: cannot find mark")
        }
    }

    func testASpotOfSeveralFilesOnAMacWithNoToolsSaysHowToGetThem() async throws {
        let spot = try spotOfSeveralFiles()
        let runs = SpotRuns(swift: try tools(selector: "exit 2"))
        defer { runs.quit() }

        do {
            _ = try await runs.answer(of: spot, .show)
            XCTFail("It must not run.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "To build a Swift spot, install the Command Line Tools: xcode-select --install")
        }
    }

    func testASourceThatIsMissingIsNamed() async throws {
        let spot = try spotOfSeveralFiles()
        try FileManager.default.removeItem(at: folder.appendingPathComponent("hello.spot/words.swift"))

        do {
            _ = try await SwiftProgram(cache: cache).built(spot.url, with: spot.sources)
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "hello.swift names the source words.swift, which Openspot cannot find.")
        }
    }

    func testTheCheckNamesASpotOfSeveralFilesThatDoesNotBuild() async throws {
        _ = try spotOfSeveralFiles()
        try FileManager.default.removeItem(at: folder.appendingPathComponent("hello.spot/words.swift"))

        let faults = await SpotCheck(folder: SpotsFolder(url: folder), programs: SwiftProgram(cache: cache)).faults()

        XCTAssertEqual(faults, ["hello: hello.swift names the source words.swift, which Openspot cannot find."])
    }

    func testOnlyASwiftSpotTakesASourceAndOnlyFromItsFolder() throws {
        try script("shell.sh", "#!/bin/sh\n", toml: "title = 'Shell'\nsource = ['words.swift']")
        try script("up.swift", "#!/usr/bin/env swift\n", toml: "title = 'Up'\nsource = ['../other/words.swift']")
        try script("root.swift", "#!/usr/bin/env swift\n", toml: "title = 'Root'\nsource = ['/tmp/words.swift']")

        let refused = try SpotsFolder(url: folder).scan().refused

        XCTAssertEqual(refused.map(\.reason), [
            "Root has source=/tmp/words.swift, which is outside its folder. Name a Swift file or a folder beside the spot, such as source=model",
            "Shell has source=words.swift, which only a Swift spot takes. Remove it, or write the spot in a .swift file",
            "Up has source=../other/words.swift, which is outside its folder. Name a Swift file or a folder beside the spot, such as source=model"
        ])
    }

    func testEachSwiftSpotUnderAFolderIsBuiltBesideItsSourceForBothKindsOfMac() async throws {
        let swift = try tools(compiler: "echo \"$*\" >> '\(folder.path)/builds'")
        _ = try spotOfSeveralFiles()
        let spot = folder.appendingPathComponent("hello.spot")
        let old = spot.appendingPathComponent("hello.\(String(repeating: "0", count: 64)).program")
        try Data("old".utf8).write(to: old)

        let built = try await swift.buildPrograms(under: folder)

        let name = program(of: main, with: severalFiles)
        XCTAssertEqual(built.map(\.lastPathComponent), [name])
        XCTAssertEqual(try Data(contentsOf: spot.appendingPathComponent(name)), Data("built".utf8))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spot.appendingPathComponent(name).path))
        XCTAssertFalse(exists(old))
        XCTAssertEqual(builds, 2)
    }

    func testAReleaseAppRunsASwiftSpotOnAMacWithNoDeveloperTools() async throws {
        let spot = try spotOfSeveralFiles()
        try script("one.swift", "#!/usr/bin/env swift\nprint(\"text=one\")\n", toml: "title = 'One'\non = ['sheet.open']")
        let one = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first { $0.id == "one" })
        _ = try await cachingWithTools().buildPrograms(under: folder)
        let built = builds
        let none = folder.appendingPathComponent("no-tools")
        try FileManager.default.createDirectory(at: none, withIntermediateDirectories: true)
        for tool in ["xcode-select", "swiftc", "lipo"] { try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/builds'\nexit 2\n".writeScript(to: none.appendingPathComponent(tool)) }
        let runs = SpotRuns(swift: SwiftProgram(tools: none, cache: folder.appendingPathComponent("empty-cache"), shipped: folder))
        defer { runs.quit() }

        let several = try await runs.answer(of: spot, .show)
        let single = try await runs.answer(of: one, .show)

        XCTAssertEqual([several, single], ["text=program\n", "text=program\n"])
        XCTAssertEqual(builds, built)
    }

    func testASharedSpotOfSeveralFilesTravelsWithAProgramNamedByAllOfThem() async throws {
        let files: [SpotPackage.File] = [
            .init(path: "hello.spot/hello.swift", isExecutable: true, contents: Data(main.utf8)),
            .init(path: "hello.spot/words.swift", isExecutable: false, contents: severalFiles[0].data),
            .init(path: "hello.spot/more/Mark.swift", isExecutable: false, contents: severalFiles[1].data),
            .init(path: "hello.spot/more/notes.txt", isExecutable: false, contents: Data("not Swift".utf8)),
            .init(path: "hello.spot/spot.toml", isExecutable: false, contents: Data("source = ['words.swift', 'more']\n".utf8))
        ]
        let swift = try tools(compiler: "echo \"$*\" >> '\(folder.path)/builds'")

        let compiled = try await SpotPackage(files: files).compiled(by: swift)
        let changed = try SpotPackage(files: compiled.files.map { $0.path.hasSuffix("Mark.swift") ? .init(path: $0.path, isExecutable: false, contents: Data("func mark() -> String { \"?\" }\n".utf8)) : $0 })

        XCTAssertEqual(compiled.files.last?.path, "hello.spot/" + program(of: main, with: severalFiles))
        XCTAssertFalse(compiled.needsCompile)
        XCTAssertTrue(changed.needsCompile)
        let line = try XCTUnwrap(String(contentsOf: folder.appendingPathComponent("builds"), encoding: .utf8).split(separator: "\n").first)
        XCTAssertTrue(line.contains("/main.swift ") && line.contains("/more/words.swift ") && line.contains("/more/more/Mark.swift "), String(line))
    }

    func testAPruneKeepsTheBuildOfASpotOfSeveralFiles() async throws {
        let swift = try cachingWithTools()
        let spot = try spotOfSeveralFiles()
        let program = try await swift.built(spot.url, with: spot.sources)

        await swift.prune(keeping: [spot.url], with: [spot.url: spot.sources])?.value

        XCTAssertTrue(exists(program))
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
}
