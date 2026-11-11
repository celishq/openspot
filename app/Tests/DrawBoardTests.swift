import XCTest

/// Proves the board of the Draw spot: arrows that hold shapes, ties that hold arrows together, forms, and the file of a board.
final class DrawBoardTests: XCTestCase {
    private func box(_ x: CGFloat, _ y: CGFloat, _ form: Figure.Form = .rectangle) -> Figure {
        var figure = Figure(kind: .shape, points: [CGPoint(x: x, y: y), CGPoint(x: x + 100, y: y + 60)])
        figure.form = form
        return figure
    }

    private func arrow(from start: Figure, to end: Figure) -> Figure {
        var arrow = Figure(kind: .arrow, points: [.zero, .zero])
        arrow.start = start.id
        arrow.end = end.id
        return arrow
    }

    /// Two sources on the left with arrows to one target on the right.
    private func fan() -> (board: Board, target: Figure, arrows: [Figure]) {
        let top = box(0, 0)
        let bottom = box(0, 200)
        let target = box(400, 100)
        let arrows = [arrow(from: top, to: target), arrow(from: bottom, to: target)]
        return (Board(figures: [top, bottom, target] + arrows), target, arrows)
    }

    private let cut = [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)]

    func testAnArrowEndFollowsTheShapeThatItHolds() throws {
        let (board, target, arrows) = fan()
        var moved = board
        moved.move([target.id], by: CGPoint(x: 0, y: 300))

        let end = try XCTUnwrap(moved.path(of: arrows[0]).last)
        let grown = try XCTUnwrap(moved[target.id]).frame.insetBy(dx: -Board.gap - 1, dy: -Board.gap - 1)
        XCTAssertTrue(grown.contains(end))
        XCTAssertFalse(try XCTUnwrap(moved[target.id]).frame.contains(end))
    }

    func testAStrokeAcrossTwoArrowsTiesThemAndEachKeepsItsOwnEnds() throws {
        var (board, target, arrows) = fan()

        let tie = try XCTUnwrap(board.bundle(along: cut))

        XCTAssertEqual(board.figures.filter { $0.kind == .arrow }.count, 2)
        XCTAssertEqual(try XCTUnwrap(board[tie]).members.sorted(), arrows.map(\.id).sorted())
        for arrow in arrows {
            let tied = try XCTUnwrap(board[arrow.id])
            XCTAssertEqual(tied.ties, [tie])
            XCTAssertEqual(tied.end, target.id)
            XCTAssertNotNil(tied.start)
        }
        let center = try XCTUnwrap(board[tie]).points[0]
        XCTAssertEqual(center.x, 300, accuracy: 1)
        let near = arrows.map { arrow in board.path(of: board[arrow.id]!).map { $0.distance(to: center) }.min()! }
        XCTAssertLessThan(near.max()!, 10)
        XCTAssertGreaterThan(near.max()!, 1)
    }

    func testArrowsToDifferentShapesTieToo() throws {
        let a = box(0, 0)
        let b = box(0, 200)
        var board = Board(figures: [a, b, box(400, 0), box(400, 200)])
        board.add(arrow(from: a, to: board.figures[2]))
        board.add(arrow(from: b, to: board.figures[3]))

        let tie = try XCTUnwrap(board.bundle(along: [CGPoint(x: 250, y: -50), CGPoint(x: 250, y: 300)]))

        XCTAssertEqual(try XCTUnwrap(board[tie]).members.count, 2)
    }

    func testAStrokeAcrossOneArrowTiesNothing() {
        var (board, _, _) = fan()
        let before = board

        XCTAssertNil(board.bundle(along: [CGPoint(x: 120, y: -20), CGPoint(x: 120, y: 60)]))
        XCTAssertEqual(board, before)
    }

    func testAnArrowPassesItsTiesInOrderFromItsStart() throws {
        var (board, _, arrows) = fan()
        let late = try XCTUnwrap(board.bundle(along: cut))
        let early = try XCTUnwrap(board.bundle(along: [CGPoint(x: 200, y: 0), CGPoint(x: 200, y: 300)]))

        XCTAssertEqual(board[arrows[0].id]?.ties, [early, late])
        XCTAssertEqual(board[arrows[1].id]?.ties, [early, late])
    }

    func testRemovingATieUntiesItsArrows() throws {
        var (board, _, arrows) = fan()
        let original = board
        let tie = try XCTUnwrap(board.bundle(along: cut))

        board.remove([tie])

        XCTAssertEqual(board, original)
        XCTAssertEqual(arrows.compactMap { board[$0.id]?.ties }, [[], []])
    }

    func testRemovingAnArrowOfATieOfTwoRemovesTheTie() throws {
        var (board, _, arrows) = fan()
        let tie = try XCTUnwrap(board.bundle(along: cut))

        board.remove([arrows[0].id])

        XCTAssertNil(board[tie])
        XCTAssertEqual(board[arrows[1].id]?.ties, [])
    }

    func testRemovingAShapeLeavesTheArrowEndWhereItWas() throws {
        var (board, target, arrows) = fan()
        let end = try XCTUnwrap(board.path(of: arrows[0]).last)

        board.remove([target.id])

        let left = try XCTUnwrap(board[arrows[0].id])
        XCTAssertNil(left.end)
        XCTAssertEqual(left.points[1], end)
    }

    func testMovingAnArrowAloneLetsGoOfItsShapes() throws {
        var (board, _, arrows) = fan()
        let before = board.path(of: arrows[0])

        board.move([arrows[0].id], by: CGPoint(x: 10, y: 20))

        let moved = try XCTUnwrap(board[arrows[0].id])
        XCTAssertNil(moved.start)
        XCTAssertNil(moved.end)
        XCTAssertEqual(moved.points[0], before[0] + CGPoint(x: 10, y: 20))
    }

    func testAPressInsideAFormFindsItAndAPressInItsEmptyCornerDoesNot() {
        let triangle = box(0, 0, .triangle)
        let board = Board(figures: [triangle])

        XCTAssertEqual(board.figure(at: CGPoint(x: 50, y: 40))?.id, triangle.id)
        XCTAssertNil(board.figure(at: CGPoint(x: 3, y: 3), tolerance: 0))
    }

    func testEveryFormHasAnOutlineInsideItsFrame() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 60)
        for form in Figure.Form.allCases {
            let outline = form.path(in: frame).boundingBoxOfPath
            XCTAssertTrue(frame.insetBy(dx: -1, dy: -1).contains(outline), "\(form)")
            XCTAssertGreaterThan(outline.width * outline.height, 1000, "\(form)")
        }
    }

    func testABoardSavesAndLoadsTheSame() throws {
        var (board, _, _) = fan()
        board.title = "Flows"
        board.bundle(along: cut)
        board.figures[0].form = .star
        board.figures[3].heads = .both
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-draw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("board.json")

        try board.save(to: file)

        XCTAssertEqual(try Board.load(from: file), board)
    }

    func testAnOldBoardLoadsItsBoxesLinesAndMergedArrowsAsShapesAndTies() throws {
        let old = """
        {"title":"Old","figures":[
          {"id":"00000000-0000-0000-0000-00000000000A","kind":"rectangle","points":[[0,0],[100,60]]},
          {"id":"00000000-0000-0000-0000-00000000000B","kind":"ellipse","points":[[0,200],[100,260]]},
          {"id":"00000000-0000-0000-0000-00000000000C","kind":"rectangle","points":[[400,100],[500,160]]},
          {"id":"00000000-0000-0000-0000-000000000001","kind":"arrow","points":[[0,0],[300,130]],"start":"00000000-0000-0000-0000-00000000000A","end":"00000000-0000-0000-0000-0000000000F0"},
          {"id":"00000000-0000-0000-0000-000000000002","kind":"arrow","points":[[0,0],[300,130]],"start":"00000000-0000-0000-0000-00000000000B","end":"00000000-0000-0000-0000-0000000000F0"},
          {"id":"00000000-0000-0000-0000-0000000000F0","kind":"junction","points":[[300,130]]},
          {"id":"00000000-0000-0000-0000-0000000000F1","kind":"arrow","points":[[300,130],[400,130]],"start":"00000000-0000-0000-0000-0000000000F0","end":"00000000-0000-0000-0000-00000000000C"},
          {"id":"00000000-0000-0000-0000-000000000003","kind":"line","points":[[0,400],[90,400]]}
        ]}
        """
        let board = try JSONDecoder().decode(Board.self, from: Data(old.utf8))

        XCTAssertEqual(board.figures.filter { $0.kind == .shape }.map(\.form), [.rectangle, .ellipse, .rectangle])
        let arrows = board.figures.filter { $0.kind == .arrow }
        XCTAssertEqual(arrows.count, 3)
        XCTAssertEqual(arrows.last?.heads, Figure.Heads.none)
        let target = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")
        XCTAssertEqual(arrows.prefix(2).map(\.end), [target, target])
        let tie = try XCTUnwrap(board.figures.first { $0.kind == .tie })
        XCTAssertEqual(tie.members.count, 2)
        XCTAssertEqual(arrows.prefix(2).map(\.ties), [[tie.id], [tie.id]])
    }

    func testAPressFindsTheTopFigureAndTheLineOfAnArrow() throws {
        let (board, target, arrows) = fan()
        let middle = board.path(of: arrows[0])[24]

        XCTAssertEqual(board.figure(at: CGPoint(x: 450, y: 130))?.id, target.id)
        XCTAssertEqual(board.figure(at: middle + CGPoint(x: 0, y: 3))?.id, arrows[0].id)
        XCTAssertNil(board.figure(at: CGPoint(x: 700, y: 700)))
    }
}
