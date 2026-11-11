import AppKit
import Combine

/// The board in its window: the figures, the selection, the tool, the style, the steps to undo, and the file it saves to.
/// Each change is one step to undo, and a change saves the board and its picture shortly after.
@MainActor
final class Studio: ObservableObject {
    @Published var board: Board
    @Published var selection: Set<UUID> = []
    @Published var tool = Tool.select
    @Published var style = Style()
    @Published var zoom: CGFloat = 1
    private var past: [Board] = []
    private var future: [Board] = []
    private var pending: DispatchWorkItem?
    let file: URL

    init(file: URL) {
        self.file = file
        board = (try? Board.load(from: file)) ?? Board()
    }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Keeps `before` as a step to undo when the board changed since it.
    func record(_ before: Board) {
        guard before != board else { return }
        past.append(before)
        if past.count > 300 { past.removeFirst() }
        future = []
        saveSoon()
    }

    func change(_ body: (inout Board) -> Void) {
        let before = board
        body(&board)
        record(before)
    }

    func undo() {
        guard let last = past.popLast() else { return }
        future.append(board)
        board = last
        selection = selection.filter { board[$0] != nil }
        saveSoon()
    }

    func redo() {
        guard let next = future.popLast() else { return }
        past.append(board)
        board = next
        selection = selection.filter { board[$0] != nil }
        saveSoon()
    }

    /// Sets the style of new figures and gives it to the selected ones.
    func restyle(_ change: (inout Style) -> Void) {
        change(&style)
        guard !selection.isEmpty else { return }
        let style = style
        self.change { board in
            for id in selection where board[id]?.kind != .junction {
                board.update(id) { style.dress(&$0) }
            }
        }
    }

    /// Shows the style of the selection in the style panel.
    func pickUpStyle() {
        if let first = selection.lazy.compactMap({ self.board[$0] }).first(where: { $0.kind != .junction }) {
            style = Style(of: first)
        }
    }

    func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        change { $0.remove(ids) }
        selection = []
    }

    // MARK: Saving

    private func saveSoon() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Writes the board and its picture. A board whose file is gone was deleted in Openspot, so it closes.
    func save() {
        pending?.cancel()
        pending = nil
        guard FileManager.default.fileExists(atPath: file.path) else {
            NSApp.terminate(nil)
            return
        }
        if let title = try? Board.load(from: file).title { board.title = title }
        try? board.save(to: file)
        if let picture = Painting(board: board).picture(width: 360, height: 240) {
            try? picture.write(to: file.deletingPathExtension().appendingPathExtension("png"), options: .atomic)
        }
    }

    /// Takes the title that Openspot gave the board, and closes a board that Openspot deleted.
    func reloadTitle() {
        guard FileManager.default.fileExists(atPath: file.path) else { return NSApp.terminate(nil) }
        if let title = try? Board.load(from: file).title, title != board.title { board.title = title }
    }
}
