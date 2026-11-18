import XCTest

@MainActor
final class DrawProcessTests: XCTestCase {
    private var data: URL!
    private var boards: URL!
    private var words: URL!

    override func setUp() async throws {
        data = try emptyFolder()
        words = try emptyFolder()
        boards = data.appendingPathComponent("boards")
        try FileManager.default.createDirectory(at: boards, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        Saves.shared.wait()
        try? FileManager.default.removeItem(at: data)
        try? FileManager.default.removeItem(at: words)
    }

    private func box() -> Figure {
        Figure(kind: .shape, points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 60)])
    }

    private func board(_ name: String, title: String = "Flows") throws -> URL {
        let file = boards.appendingPathComponent("\(name).json")
        try Board(title: title).save(to: file)
        return file
    }

    /// A Draw with no window, which prints its frames into a file of this name, and the words of each call of
    /// `openspot` into another.
    private func draw(_ name: String, ends: @escaping () -> Void = {}) throws -> Draw {
        let file = data.appendingPathComponent("\(name).out")
        let said = words.appendingPathComponent("\(name).said")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        FileManager.default.createFile(atPath: said.path, contents: nil)
        let log = try FileHandle(forWritingTo: said)
        let host = Host(output: try FileHandle(forWritingTo: file)) { log.write(Data(($0.joined(separator: " ") + "\n").utf8)) }
        let draw = Draw(boards: boards, home: data, host: host, ends: ends)
        draw.take(.ask(id: 0, arguments: ["windowless"], input: [:]))
        return draw
    }

    private func frames(of name: String) throws -> [String] {
        try String(contentsOf: data.appendingPathComponent("\(name).out"), encoding: .utf8).components(separatedBy: "---\n").filter { !$0.isEmpty }
    }

    private func said(by name: String) throws -> [String] {
        try String(contentsOf: words.appendingPathComponent("\(name).said"), encoding: .utf8).split(separator: "\n").map(String.init)
    }

    private var files: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: boards.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }

    func testASecondDrawChangesNoBoardWhileTheFirstHoldsThem() throws {
        let file = try board("flows")
        let first = try draw("first")
        first.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        XCTAssertNotNil(first.desk?.studio)
        let second = try draw("second")

        second.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        second.take(.ask(id: 2, arguments: ["0:new"], input: [:]))
        second.take(.ask(id: 3, arguments: ["open", "0:new"], input: [:]))
        second.take(.ask(id: 4, arguments: ["delete", "0:flows"], input: [:]))

        XCTAssertNil(second.desk)
        XCTAssertEqual(files, ["flows.json"])
        XCTAssertEqual(try Board.title(at: file), "Flows")
        XCTAssertEqual(Array(try frames(of: "second").dropFirst()), (1...4).map { "end=\($0)\n" })
        XCTAssertEqual(try said(by: "second"), Array(repeating: "toast \(Draw.busy)", count: 4))
    }

    func testARenameFromASecondDrawIsRefusedWithAToastAndTheBoardKeepsItsTitle() throws {
        let file = try board("flows")
        let first = try draw("first")
        first.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        let second = try draw("second")

        second.take(.ask(id: 1, arguments: ["rename", "0:flows"], input: ["input.name": "Other"]))
        first.desk?.studio?.change { $0.add(self.box()) }
        first.desk?.finish()

        XCTAssertEqual(try frames(of: "second").last, "end=1\n")
        XCTAssertEqual(try said(by: "second"), ["toast \(Draw.busy)"])
        XCTAssertEqual(try Board.load(from: file).title, "Flows")
        XCTAssertEqual(try Board.load(from: file).figures.count, 1)
    }

    func testASecondDrawStillListsTheBoardsAndAsksForANewName() throws {
        _ = try board("flows")
        let first = try draw("first")
        first.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        let second = try draw("second")

        second.take(.ask(id: 1, arguments: ["show"], input: [:]))
        second.take(.ask(id: 2, arguments: ["rename", "0:flows"], input: [:]))

        let frames = try frames(of: "second")
        XCTAssertTrue(frames[1].hasPrefix("recents=false\nend=1\n"))
        XCTAssertTrue(frames[1].contains("row=0:flows\ntitle=Flows\n"))
        XCTAssertTrue(frames[2].hasPrefix("end=2\ntitle=Rename board\n"))
    }

    func testTheBoardsAreFreeWhenTheDrawThatHeldThemEnds() throws {
        let file = try board("flows")
        let first = try draw("first")
        first.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        let second = try draw("second")
        second.take(.ask(id: 1, arguments: ["rename", "0:flows"], input: ["input.name": "Other"]))

        first.take(nil)
        second.take(.ask(id: 2, arguments: ["rename", "0:flows"], input: ["input.name": "Other"]))

        XCTAssertEqual(try Board.title(at: file), "Other")
    }

    func testADrawThatOnlyListedTheBoardsHoldsNone() throws {
        let file = try board("flows")
        let first = try draw("first")
        first.take(.ask(id: 1, arguments: ["show"], input: [:]))
        let second = try draw("second")

        second.take(.ask(id: 1, arguments: ["rename", "0:flows"], input: ["input.name": "Other"]))

        XCTAssertEqual(try Board.title(at: file), "Other")
    }

    func testReadyRemovesTheProgramAndTheBuildLogOfTheDrawBeforeThisOne() throws {
        for old in ["Draw", "build.log"] { try Data("old".utf8).write(to: data.appendingPathComponent(old)) }
        _ = try board("flows")

        try draw("first").ready()

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: data.path).sorted(), ["boards", "first.out"])
        XCTAssertEqual(files, ["flows.json"])
    }

    func testATermSignalSavesAChangedBoardBeforeDrawEnds() async throws {
        let file = try board("flows")
        let ended = expectation(description: "Draw ends")
        let draw = try draw("first") { ended.fulfill() }
        draw.ready()
        draw.take(.ask(id: 1, arguments: ["open", "0:flows"], input: [:]))
        draw.desk?.studio?.change { $0.add(self.box()) }
        XCTAssertEqual(try Board.load(from: file).figures.count, 0)

        kill(getpid(), SIGTERM)

        await fulfillment(of: [ended], timeout: 600)
        XCTAssertEqual(try Board.load(from: file).figures.count, 1)
        XCTAssertEqual(try frames(of: "first").last, "end=1\n")
    }
}
