import XCTest
@testable import OpenspotCore

@MainActor
final class TimelineTests: PanelCase {
    private var clock = FakeClock()

    private var store: URL {
        folder.appendingPathComponent("config/timeline", isDirectory: true)
    }

    override func setUp() async throws {
        try await super.setUp()
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: stopPause, timeline: store))
        host.model = model
        takeCalls()
        try script("notes", toml: "title = 'Notes'\nuses = ['timeline']", "printf 'item=a\\ntitle=A\\n'")
        try script("other", toml: "title = 'Other'\nuses = ['timeline']", "printf 'item=o\\ntitle=O\\n'")
        try script("reader", toml: "title = 'Reader'\nuses = ['timeline', 'read']", """
        printf 'show\\n' >> '\(folder.appendingPathComponent("shows").path)'
        printf 'item=r\\ntitle=R\\n'
        """)
        await model.reload()
    }

    private func call(_ words: [String], of id: String = "notes", input: String = "") async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets[id]?.spot))
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["timeline"] + words, folder: folder.path, caller: caller), input: { input }))
        return await work()
    }

    private func listed(_ words: [String] = [], of id: String = "notes") async throws -> [TextBlock] {
        let answer = try await call(["list"] + words, of: id)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return TextBlock.blocks(in: answer.output)
    }

    private func add(_ words: [String], of id: String = "notes") async throws -> String {
        let answer = try await call(["add"] + words, of: id)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return answer.output.trimmingCharacters(in: .newlines)
    }

    func testAnAddedEntryListsNewestFirstWithItsTitleSpotAndValue() async throws {
        _ = try await add(["text=first line\nsecond", "app=com.apple.Notes"])
        clock.advance(by: 5)
        let id = try await add(["url=https://a.com", "title=A page", "detail=Pull request #12"])

        let blocks = try await listed()

        XCTAssertEqual(blocks.map { $0.value("title") }, ["A page", "first line"])
        XCTAssertEqual(blocks.first?.value("item"), id)
        XCTAssertEqual(blocks.first?.value("url"), "https://a.com")
        XCTAssertEqual(blocks.map { $0.value("kind") }, ["url", "text"])
        XCTAssertEqual(blocks.first?.value("detail"), "Pull request #12")
        XCTAssertNil(blocks.last?.value("detail"))
        XCTAssertEqual(blocks.last?.value("text"), "first line\nsecond")
        XCTAssertEqual(blocks.last?.value("app"), "com.apple.Notes")
        XCTAssertEqual(blocks.last?.value("spot"), "notes")
    }

    func testTheLinesOnStdinAddAnEntryAndNoValueAddsNone() async throws {
        let empty = try await call(["add"], input: "title=Nothing\n")
        XCTAssertEqual(empty.code, 0, empty.errors)
        XCTAssertEqual(empty.output, "")

        let added = try await call(["add"], input: "text=hello\ntitle=Greeting\n")
        XCTAssertEqual(added.code, 0, added.errors)

        let blocks = try await listed()
        XCTAssertEqual(blocks.map { $0.value("title") }, ["Greeting"])
    }

    func testTwoKindsOrAnUnknownKeyFail() async throws {
        let two = try await call(["add", "text=a", "url=https://a.com"])
        let unknown = try await call(["add", "colour=red"])

        XCTAssertEqual(two.code, 2)
        XCTAssertEqual(unknown.code, 2)
        XCTAssertTrue(unknown.errors.contains("colour=red"), unknown.errors)
    }

    func testAnEntryOfTheSameKeyMovesTheOldOneToTheTop() async throws {
        _ = try await add(["text=a", "key=k"])
        clock.advance(by: 1)
        _ = try await add(["text=b"])
        clock.advance(by: 1)
        _ = try await add(["text=a again", "key=k"])

        let blocks = try await listed()

        XCTAssertEqual(blocks.map { $0.value("text") }, ["a again", "b"])
    }

    func testAForgottenEntryLeavesTheListAndARestoreBringsItBack() async throws {
        let id = try await add(["text=secret"])

        let forgot = try await call(["forget", id])
        XCTAssertEqual(forgot.code, 0, forgot.errors)
        let hidden = try await listed()
        XCTAssertEqual(hidden.count, 0)

        let restored = try await call(["restore", id])
        XCTAssertEqual(restored.code, 0, restored.errors)
        let shown = try await listed()
        XCTAssertEqual(shown.map { $0.value("text") }, ["secret"])
    }

    func testAnEntryForgottenLongAgoCannotBeRestored() async throws {
        let id = try await add(["text=secret"])
        _ = try await call(["forget", id])
        clock.advance(by: 11 * 60)
        _ = try await listed()

        let restored = try await call(["restore", id])

        XCTAssertEqual(restored.code, 1)
    }

    func testAForgottenEntryLeavesTheDiskTenMinutesLaterWithNoCall() async throws {
        let id = try await add(["text=secret"])
        _ = try await call(["forget", id])
        let day = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: store.appendingPathComponent("notes"), includingPropertiesForKeys: nil).first { $0.pathExtension == "jsonl" })

        clock.advance(by: 11 * 60)

        try await wait("the forgotten entry leaves the disk", until: { !FileManager.default.fileExists(atPath: day.path) })
    }

    func testTheTimelineLetsGoOfItsEntriesAMinuteAfterItsLastCallAndReadsThemAgain() async throws {
        _ = try await add(["text=kept"])
        XCTAssertTrue(model.runs.timeline.holdsEntries)

        clock.advance(by: SpotRuns.timelineHold + 1)

        try await wait("the timeline lets go of its entries", until: { !self.model.runs.timeline.holdsEntries })
        let blocks = try await listed()
        XCTAssertEqual(blocks.map { $0.value("text") }, ["kept"])
    }

    func testAKeptFileOutlivesItsOriginal() async throws {
        let original = folder.appendingPathComponent("report.txt")
        try "the report".write(to: original, atomically: true, encoding: .utf8)
        _ = try await add(["file=\(original.path)"])
        try FileManager.default.removeItem(at: original)

        let blocks = try await listed()

        let kept = try XCTUnwrap(blocks.first?.value("file"))
        XCTAssertNotEqual(kept, original.path)
        XCTAssertEqual(try String(contentsOfFile: kept, encoding: .utf8), "the report")
        XCTAssertEqual(blocks.first?.value("title"), "report.txt")
    }

    func testAFileOverTheCloneLimitKeepsOnlyALink() async throws {
        let original = folder.appendingPathComponent("movie.mov")
        FileManager.default.createFile(atPath: original.path, contents: nil)
        let handle = try FileHandle(forWritingTo: original)
        try handle.truncate(atOffset: UInt64(Timeline.entryLimit + 1))
        try handle.close()

        _ = try await add(["file=\(original.path)"])

        let blocks = try await listed()
        XCTAssertEqual(blocks.first?.value("file"), original.path)
    }

    func testAFolderKeepsOnlyALink() async throws {
        let original = folder.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)

        _ = try await add(["file=\(original.path)"])

        let blocks = try await listed()
        XCTAssertEqual(blocks.first?.value("file"), original.path)
        let kept = try FileManager.default.contentsOfDirectory(atPath: store.appendingPathComponent("notes").path)
        XCTAssertEqual(kept.filter { !$0.hasSuffix(".jsonl") }, [])
    }

    func testAKeyedAddThatFailsKeepsTheOldEntry() async throws {
        _ = try await add(["text=a", "key=k"])

        let bad = try await call(["add", "text=", "key=k"])

        XCTAssertEqual(bad.code, 2)
        let blocks = try await listed()
        XCTAssertEqual(blocks.map { $0.value("text") }, ["a"])
    }

    func testAnEntryOlderThanTheKeptDaysIsDroppedWithItsDay() async throws {
        let old = ISO8601DateFormatter().string(from: clock.time.addingTimeInterval(-40 * 86_400))
        _ = try await add(["text=old", "at=\(old)"])
        _ = try await add(["text=new"])

        let blocks = try await listed()

        XCTAssertEqual(blocks.map { $0.value("text") }, ["new"])
        let days = try FileManager.default.contentsOfDirectory(atPath: store.appendingPathComponent("notes").path).filter { $0.hasSuffix(".jsonl") }
        XCTAssertEqual(days.count, 1)
    }

    func testTheByteLimitDropsTheOldestEntries() throws {
        let timeline = Timeline(folder: store, byteLimit: 10)
        let now = Date()
        _ = try timeline.add(Timeline.Draft(kind: .text, values: ["12345678"]), of: "notes", at: now)
        _ = try timeline.add(Timeline.Draft(kind: .text, values: ["abcdefgh"]), of: "notes", at: now.addingTimeInterval(1))

        let entries = timeline.list(Timeline.Query(), at: now.addingTimeInterval(2))

        XCTAssertEqual(entries.map(\.value), ["abcdefgh"])
    }

    func testTheEntriesLastThroughARelaunch() throws {
        let now = Date()
        _ = try Timeline(folder: store).add(Timeline.Draft(kind: .text, values: ["kept"]), of: "notes", at: now)

        let entries = Timeline(folder: store).list(Timeline.Query(), at: now)

        XCTAssertEqual(entries.map(\.value), ["kept"])
    }

    func testTheTextQueryFindsEachWordFoldedAndTheLimitCuts() async throws {
        _ = try await add(["text=Café au lait"])
        clock.advance(by: 1)
        _ = try await add(["text=Tea"])
        clock.advance(by: 1)
        _ = try await add(["text=cafe latte"])

        let found = try await listed(["--text", "CAFE"])
        let limited = try await listed(["--limit", "1"])

        XCTAssertEqual(found.map { $0.value("text") }, ["cafe latte", "Café au lait"])
        XCTAssertEqual(limited.map { $0.value("text") }, ["cafe latte"])
    }

    func testASpotReadsOnlyItsOwnTimelineAndAnotherNeedsRead() async throws {
        _ = try await add(["text=mine"])
        _ = try await add(["text=theirs"], of: "other")

        let own = try await listed(of: "other")
        let refused = try await call(["list", "--spot", "notes"], of: "other")
        let all = try await listed(["--all"], of: "reader")

        XCTAssertEqual(own.map { $0.value("text") }, ["theirs"])
        XCTAssertNotEqual(refused.code, 0)
        XCTAssertEqual(Set(all.compactMap { $0.value("text") }), ["mine", "theirs"])
    }

    func testAnAddRunsTheShowOfAnOpenSheetThatReadsTheTimeline() async throws {
        _ = try await listed(["--all"], of: "reader")
        model.isShown = true
        model.panelWillShow()
        model.press("reader")
        try await wait("the open sheet") { self.model.transition.phase == .open && self.shows >= 1 }
        try await wait("the end of each call") { self.model.sheets["reader"]?.calls.isEmpty == true }
        let before = shows

        _ = try await add(["text=fresh"])

        try await wait("the show after the add") { self.shows == before + 1 }
    }

    func testAForgetRunsTheShowOfAnOpenSheetThatReadsTheTimelineAgain() async throws {
        let id = try await add(["text=gone"])
        _ = try await listed(["--all"], of: "reader")
        model.isShown = true
        model.panelWillShow()
        model.press("reader")
        try await wait("the open sheet") { self.model.transition.phase == .open && self.shows >= 1 }
        try await wait("the end of each call") { self.model.sheets["reader"]?.calls.isEmpty == true }
        let before = shows

        let answer = try await call(["forget", id], of: "reader")

        XCTAssertEqual(answer.code, 0, answer.errors)
        try await wait("the show after the forget") { self.shows == before + 1 }
    }

    func testARemovedSpotNoLongerReadsTheTimeline() async throws {
        _ = try await listed(["--all"], of: "reader")
        XCTAssertEqual(model.runs.timeline.readers(of: "notes"), ["reader"])

        try FileManager.default.removeItem(at: spots.appendingPathComponent("reader.spot"))
        await model.reload()

        XCTAssertEqual(model.runs.timeline.readers(of: "notes"), [])
    }

    func testAnAddRunsNoShowOfAClosedSheet() async throws {
        _ = try await listed(["--all"], of: "reader")

        _ = try await add(["text=fresh"])
        _ = try await listed(["--all"], of: "reader")

        XCTAssertEqual(shows, 0)
    }

    private var shows: Int {
        ((try? String(contentsOf: folder.appendingPathComponent("shows"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }
}
