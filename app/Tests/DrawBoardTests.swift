import XCTest

/// Proves the board of the Draw spot: arrows that hold boxes, bundles, and the file of a board.
final class DrawBoardTests: XCTestCase {
    private func box(_ x: CGFloat, _ y: CGFloat) -> Figure {
        Figure(kind: .rectangle, points: [CGPoint(x: x, y: y), CGPoint(x: x + 100, y: y + 60)])
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

    func testAnArrowEndFollowsTheBoxThatItHolds() throws {
        let (board, target, arrows) = fan()
        var moved = board
        moved.move([target.id], by: CGPoint(x: 0, y: 300))

        let end = try XCTUnwrap(moved.path(of: arrows[0]).last)
        let grown = try XCTUnwrap(moved[target.id]).frame.insetBy(dx: -Board.gap - 1, dy: -Board.gap - 1)
        XCTAssertTrue(grown.contains(end))
        XCTAssertFalse(try XCTUnwrap(moved[target.id]).frame.contains(end))
    }

    func testAStrokeAcrossTwoArrowsToOneBoxMergesThemIntoOne() throws {
        var (board, target, arrows) = fan()

        let junction = try XCTUnwrap(board.bundle(along: [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)]))

        XCTAssertEqual(board.branches(of: junction).map(\.id), arrows.map(\.id))
        let trunk = try XCTUnwrap(board.trunk(of: junction))
        XCTAssertEqual(trunk.end, target.id)
        XCTAssertEqual(try XCTUnwrap(board[junction]).points[0].x, 300, accuracy: 1)
        XCTAssertEqual(board.figures.filter { $0.kind == .arrow }.count, 3)
    }

    func testAStrokeAcrossArrowsToDifferentBoxesMergesNothing() {
        let a = box(0, 0)
        let b = box(0, 200)
        var board = Board(figures: [a, b, box(400, 0), box(400, 200)])
        board.add(arrow(from: a, to: board.figures[2]))
        board.add(arrow(from: b, to: board.figures[3]))
        let before = board

        XCTAssertNil(board.bundle(along: [CGPoint(x: 250, y: -50), CGPoint(x: 250, y: 300)]))
        XCTAssertEqual(board, before)
    }

    func testAnArrowCrossedWithABundleJoinsItsJunction() throws {
        var (board, target, _) = fan()
        let junction = try XCTUnwrap(board.bundle(along: [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)]))
        let third = box(0, 400)
        board.add(third)
        let late = arrow(from: third, to: target)
        board.add(late)

        let joined = board.bundle(along: [CGPoint(x: 330, y: 100), CGPoint(x: 330, y: 500)])

        XCTAssertEqual(joined, junction)
        XCTAssertEqual(board.branches(of: junction).count, 3)
        XCTAssertEqual(board.figures.filter { $0.kind == .junction }.count, 1)
    }

    func testRemovingTheJunctionSendsEachArrowBackToTheBox() throws {
        var (board, target, arrows) = fan()
        let original = board
        let junction = try XCTUnwrap(board.bundle(along: [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)]))

        board.remove([junction])

        XCTAssertEqual(board.figures.map(\.id), original.figures.map(\.id))
        XCTAssertEqual(arrows.compactMap { board[$0.id]?.end }, [target.id, target.id])
    }

    func testRemovingTheArrowThatLeavesAJunctionSplitsTheBundle() throws {
        var (board, target, _) = fan()
        let junction = try XCTUnwrap(board.bundle(along: [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)]))

        board.remove([try XCTUnwrap(board.trunk(of: junction)).id])

        XCTAssertNil(board[junction])
        XCTAssertEqual(board.figures.filter { $0.kind == .arrow }.map(\.end), [target.id, target.id])
    }

    func testRemovingABoxLeavesTheArrowEndWhereItWas() throws {
        var (board, target, arrows) = fan()
        let end = try XCTUnwrap(board.path(of: arrows[0]).last)

        board.remove([target.id])

        let left = try XCTUnwrap(board[arrows[0].id])
        XCTAssertNil(left.end)
        XCTAssertEqual(left.points[1], end)
    }

    func testMovingAnArrowAloneLetsGoOfItsBoxes() throws {
        var (board, _, arrows) = fan()
        let before = board.path(of: arrows[0])

        board.move([arrows[0].id], by: CGPoint(x: 10, y: 20))

        let moved = try XCTUnwrap(board[arrows[0].id])
        XCTAssertNil(moved.start)
        XCTAssertNil(moved.end)
        XCTAssertEqual(moved.points[0], before[0] + CGPoint(x: 10, y: 20))
    }

    func testABoardSavesAndLoadsTheSame() throws {
        var (board, _, _) = fan()
        board.title = "Flows"
        board.bundle(along: [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 300)])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-draw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("board.json")

        try board.save(to: file)

        XCTAssertEqual(try Board.load(from: file), board)
    }

    func testAPressFindsTheTopFigureAndTheLineOfAnArrow() throws {
        let (board, target, arrows) = fan()
        let middle = board.path(of: arrows[0])[24]

        XCTAssertEqual(board.figure(at: CGPoint(x: 450, y: 130))?.id, target.id)
        XCTAssertEqual(board.figure(at: middle + CGPoint(x: 0, y: 3))?.id, arrows[0].id)
        XCTAssertNil(board.figure(at: CGPoint(x: 700, y: 700)))
    }
}
