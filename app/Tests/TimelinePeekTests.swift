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

    private func peek(after blocks: [TextBlock]) -> [TextBlock] {
        Array(blocks.dropFirst().prefix { $0.fields.first?.key != "item" })
    }

    private var frames: [String] {
        FileManager.default.enumerator(atPath: store.path)?.compactMap { $0 as? String }.filter { $0.hasSuffix(".frame") } ?? []
    }

    func testThePeekAfterTheValueIsListedAfterItsEntryWithNoCallBack() async throws {
        let added = try await call(["add"], input: red)
        XCTAssertEqual(added.code, 0, added.errors)
        let id = added.output.trimmingCharacters(in: .newlines)

        let blocks = try await listed()
        let peek = peek(after: blocks)

        XCTAssertEqual(blocks.first?.value("text"), "#ff0000")
        XCTAssertNil(blocks.first?.value("peek.file"))
        XCTAssertEqual(peek.map(\.firstLine), ["peek=peek-\(id)", "text=hex", "button=rgb"])
        XCTAssertEqual(peek.first?.value("parent"), id)
        XCTAssertEqual(peek.first?.value("class"), "gap-part")
        XCTAssertEqual(peek.dropFirst().map { $0.value("parent") }, ["peek-\(id)", "peek-\(id)"])
    }

    func testTheListedEntryAndItsPeekAreARowWithItsPeek() async throws {
        _ = try await call(["add"], input: red)
        let output = try await call(["list"]).output

        let row = Frame(text: output).items.first

        guard case .blocks(let tree) = row.flatMap({ Peek(item: $0) })?.look else { return XCTFail("no blocks") }
        XCTAssertEqual(tree.node("hex")?.block.value("title"), "#FF0000")
        XCTAssertEqual(row.map { PeekAct.actions(of: $0.peek).map(\.title) }, ["Copy RGB"])
    }

    func testAPeekOverItsLimitKeepsTheEntryWithoutItAndSaysSo() async throws {
        let long = String(repeating: "a", count: Timeline.peekLimit)

        let added = try await call(["add"], input: "text=big\n\npeek=p\n\ntext=t\nparent=p\ntitle=\(long)\n")

        XCTAssertEqual(added.code, 1)
        XCTAssertEqual(added.errors, "The peek is over 8 KB, so the timeline keeps the entry without it.\n")
        let blocks = try await listed()
        XCTAssertEqual(blocks.first?.value("text"), "big")
        XCTAssertEqual(peek(after: blocks), [])
    }

    func testAPictureOfThePeekIsKeptAsACopyThatOutlivesItsOriginal() async throws {
        let original = folder.appendingPathComponent("red.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: original)

        _ = try await call(["add"], input: "text=#ff0000\n\npeek=p\n\npicture=shot\nparent=p\nicon=\(original.path)\n")
        try FileManager.default.removeItem(at: original)

        let blocks = try await listed()
        let kept = try XCTUnwrap(peek(after: blocks).last?.value("icon"))
        XCTAssertNotEqual(kept, original.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept))
    }

    func testAForgottenEntryTakesItsPeekWithIt() async throws {
        let id = try await call(["add"], input: red).output.trimmingCharacters(in: .newlines)
        XCTAssertEqual(frames.count, 1)

        _ = model.runs.timeline.forget(id, at: Date().addingTimeInterval(-Timeline.forgottenAge - 5))
        _ = model.runs.timeline.cut(at: Date())

        XCTAssertEqual(frames, [])
    }
}
