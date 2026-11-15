import XCTest

final class DrawStepTests: XCTestCase {
    private func box(_ x: CGFloat) -> Figure {
        Figure(kind: .shape, points: [CGPoint(x: x, y: 0), CGPoint(x: x + 100, y: 60)])
    }

    func testAStepHoldsOnlyTheFiguresThatChanged() throws {
        let old = Board(figures: (0..<100).map { box(CGFloat($0) * 200) })
        var new = old
        new.update(old.figures[40].id) { $0.text = "changed" }

        let step = try XCTUnwrap(Step(from: old, to: new))

        XCTAssertEqual(step.before, [old.figures[40]])
        XCTAssertEqual(step.after, [new.figures[40]])
    }

    func testTwoBoardsWithTheSameFiguresGiveNoStep() {
        let old = Board(title: "One", figures: [box(0)])
        var new = old
        new.title = "Other"

        XCTAssertNil(Step(from: old, to: new))
    }

    func testUndoAndRedoOfAChangedFigurePutItBackAndForth() throws {
        let old = Board(figures: [box(0), box(200), box(400)])
        var new = old
        new.move([old.figures[1].id], by: CGPoint(x: 0, y: 50))
        let step = try XCTUnwrap(Step(from: old, to: new))

        var board = new
        board.undo(step)
        XCTAssertEqual(board, old)
        board.redo(step)
        XCTAssertEqual(board, new)
    }

    func testUndoOfAnAddedFigureTakesItOffAndRedoPutsItBackInItsPlace() throws {
        let old = Board(figures: [box(0), box(200)])
        var new = old
        new.add(box(400))
        let step = try XCTUnwrap(Step(from: old, to: new))

        var board = new
        board.undo(step)
        XCTAssertEqual(board, old)
        board.redo(step)
        XCTAssertEqual(board, new)
        XCTAssertEqual(board[new.figures[2].id], new.figures[2])
    }

    func testUndoOfARemovedFigurePutsItBackWhereItLay() throws {
        let old = Board(figures: [box(0), box(200), box(400)])
        var new = old
        new.remove([old.figures[1].id])
        let step = try XCTUnwrap(Step(from: old, to: new))

        var board = new
        board.undo(step)
        XCTAssertEqual(board.figures.map(\.id), old.figures.map(\.id))
        XCTAssertEqual(board, old)
        board.redo(step)
        XCTAssertEqual(board, new)
    }

    func testUndoKeepsTheTitleThatTheBoardHasNow() throws {
        let old = Board(title: "First", figures: [box(0)])
        var new = old
        new.add(box(200))
        let step = try XCTUnwrap(Step(from: old, to: new))

        var board = new
        board.title = "Second"
        board.undo(step)

        XCTAssertEqual(board.title, "Second")
        XCTAssertEqual(board.figures, old.figures)
    }
}
