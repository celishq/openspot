import XCTest
@testable import OpenspotCore

@MainActor
final class TimelinePeekTests: PanelCase {
    private var store: URL {
        folder.appendingPathComponent("config/timeline", isDirectory: true)
    }

    private let red = """
    text=#ff0000

    peek=p
    class=gap-part

    text=hex
    parent=p
    title=#FF0000

    button=rgb
    parent=p
    title=Copy RGB
    action=clipboard copy --text 'rgb(255 0 0)'

    button=name
    parent=p
    title=Rename

    """

    override func setUp() async throws {
        try await super.setUp()
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: stopPause, timeline: store))
        host.model = model
        takeCalls()
        try script("notes", toml: "title = 'Notes'\nuses = ['timeline']", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
    }

    private func call(_ words: [String], input: String = "") async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets["notes"]?.spot))
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["timeline"] + words, folder: folder.path, caller: caller), input: { input }))
        return await work()
    }

    private func listed() async throws -> [TextBlock] {
        let answer = try await call(["list"])
        XCTAssertEqual(answer.code, 0, answer.errors)
        return TextBlock.blocks(in: answer.output)
    }

    private func peek(of block: TextBlock?) throws -> [TextBlock] {
        let file = try XCTUnwrap(block?.value("peek.file"), "no peek.file")
        return TextBlock.blocks(in: try String(contentsOfFile: file, encoding: .utf8))
    }

    func testThePeekAfterTheValueIsKeptAsAFrameOfTheEntryWithNoCallBack() async throws {
        let added = try await call(["add"], input: red)
        XCTAssertEqual(added.code, 0, added.errors)
        let id = added.output.trimmingCharacters(in: .newlines)

        let entry = try await listed().first
        let peek = try peek(of: entry)

        XCTAssertEqual(entry?.value("text"), "#ff0000")
        XCTAssertTrue(try XCTUnwrap(entry?.value("peek.file")).hasSuffix(".frame"))
        XCTAssertEqual(peek.map(\.firstLine), ["peek=peek-\(id)", "text=hex", "button=rgb"])
        XCTAssertEqual(peek.first?.value("parent"), id)
        XCTAssertEqual(peek.first?.value("class"), "gap-part")
        XCTAssertEqual(peek.dropFirst().map { $0.value("parent") }, ["peek-\(id)", "peek-\(id)"])
    }

    func testThePeekOfAListedEntryIsThePeekOfItsRow() async throws {
        _ = try await call(["add"], input: red)
        let first = try await listed().first
        let entry = try XCTUnwrap(first)
        let text = try String(contentsOfFile: try XCTUnwrap(entry.value("peek.file")), encoding: .utf8)

        let row = Frame(text: "item=\(entry.value("item") ?? "")\ntitle=Red\ntext=#ff0000\n\n" + text).items.first

        guard case .blocks(let tree) = row.flatMap { Peek(item: $0) }?.look else { return XCTFail("no blocks") }
        XCTAssertEqual(tree.node("hex")?.block.value("title"), "#FF0000")
        XCTAssertEqual(row.map { PeekAct.actions(of: $0.peek).map(\.title) }, ["Copy RGB"])
    }

    func testAPeekOverItsLimitKeepsTheEntryWithoutItAndSaysSo() async throws {
        let long = String(repeating: "a", count: Timeline.peekLimit)

        let added = try await call(["add"], input: "text=big\n\npeek=p\n\ntext=t\nparent=p\ntitle=\(long)\n")

        XCTAssertEqual(added.code, 1)
        XCTAssertEqual(added.errors, "The peek is over 64 KB, so the timeline keeps the entry without it.\n")
        let entry = try await listed().first
        XCTAssertEqual(entry?.value("text"), "big")
        XCTAssertNil(entry?.value("peek.file"))
    }

    func testAPictureOfThePeekIsKeptAsACopyThatOutlivesItsOriginal() async throws {
        let original = folder.appendingPathComponent("red.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: original)

        _ = try await call(["add"], input: "text=#ff0000\n\npeek=p\n\npicture=shot\nparent=p\nicon=\(original.path)\n")
        try FileManager.default.removeItem(at: original)

        let first = try await listed().first
        let kept = try XCTUnwrap(try peek(of: first).last?.value("icon"))
        XCTAssertNotEqual(kept, original.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept))
    }

    func testAForgottenEntryTakesItsPeekWithIt() async throws {
        let id = try await call(["add"], input: red).output.trimmingCharacters(in: .newlines)
        let first = try await listed().first
        let file = try XCTUnwrap(first?.value("peek.file"))

        _ = model.runs.timeline.forget(id, at: Date().addingTimeInterval(-Timeline.forgottenAge - 5))
        _ = model.runs.timeline.cut(at: Date())

        XCTAssertFalse(FileManager.default.fileExists(atPath: file))
    }
}
