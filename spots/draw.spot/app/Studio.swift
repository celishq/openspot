import AppKit
import Combine

/// The board in its window: the figures, the selection, the tool, the style, the steps to undo, and the file it saves to.
/// Each change is one step to undo, and a change saves the board and its picture shortly after. There is a studio only
/// for a board that loaded, so a file that Draw cannot read is never written.
@MainActor
final class Studio: ObservableObject {
    @Published var board: Board
    @Published var selection: Set<UUID> = []
    @Published var tool = Tool.select
    @Published var style = Style()
    @Published var form = Figure.Form.rectangle
    @Published var zoom: CGFloat = 1
    private var past: [Step] = []
    private var future: [Step] = []
    private var pending: DispatchWorkItem?
    /// The board as the disk holds it, or nil after a write that failed.
    private var saved: Board?
    private let saves: Saves
    /// What to do when the board's file is gone, because it was deleted outside the window.
    var gone: (() -> Void)?
    private(set) var file: URL

    init(file: URL, saves: Saves = .shared) throws {
        self.file = file
        self.saves = saves
        let board = try Board.load(from: file)
        self.board = board
        saved = board
    }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// The figures that the steps to undo hold.
    var kept: Int { past.reduce(0) { $0 + $1.before.count + $1.after.count } }

    /// Keeps the change since `before` as a step to undo.
    func record(_ before: Board) {
        guard let step = Step(from: before, to: board) else { return }
        past.append(step)
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
        future.append(last)
        board.undo(last)
        selection = selection.filter { board[$0] != nil }
        saveSoon()
    }

    func redo() {
        guard let next = future.popLast() else { return }
        past.append(next)
        board.redo(next)
        selection = selection.filter { board[$0] != nil }
        saveSoon()
    }

    /// Sets the style of new figures and gives it to the selected ones.
    func restyle(_ change: (inout Style) -> Void) {
        change(&style)
        guard !selection.isEmpty else { return }
        let style = style
        self.change { board in
            for id in selection {
                board.update(id) { figure in
                    if figure.kind == .tie { figure.ink = style.ink } else { style.dress(&figure) }
                }
            }
        }
    }

    /// Shows the style of the selection in the style panel.
    func pickUpStyle() {
        if let first = selection.lazy.compactMap({ self.board[$0] }).first {
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

    /// Writes the board and its picture when the board changed since the last write. The files are written off the
    /// main thread. A board whose file is gone was deleted, so its tab closes and nothing is written.
    func save() {
        if saveBoard() { savePicture() }
    }

    /// Writes the board alone when it changed since the last write, and returns whether it did.
    func saveBoard() -> Bool {
        pending?.cancel()
        pending = nil
        guard board != saved else { return false }
        guard FileManager.default.fileExists(atPath: file.path) else {
            gone?()
            return false
        }
        saved = board
        saves.write(board, to: file) { [weak self] in
            DispatchQueue.main.async { self?.saved = nil }
        }
        return true
    }

    /// Draws the picture of the board as it is now, and writes it after the board.
    func savePicture() {
        guard let picture = Painting(board: board, assets: assets).picture(width: 360, height: 240) else { return }
        saves.write(picture: picture, of: file)
    }

    /// Gives the board a new title, and saves it at once so that Openspot lists it so.
    func rename(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != board.title else { return }
        board.title = title
        save()
    }

    /// Follows the file to where it moved.
    func moved(to file: URL) {
        self.file = file
    }

    /// The folder of this board's images, beside its file.
    var assets: URL {
        file.deletingPathExtension().appendingPathExtension("assets")
    }

    /// Copies an image file into the board's folder of images and adds it.
    func insert(picture: URL, at center: CGPoint) {
        guard let data = try? Data(contentsOf: picture) else { return }
        insert(data, ending: picture.pathExtension.isEmpty ? "png" : picture.pathExtension.lowercased(), at: center)
    }

    func insert(png: Data, at center: CGPoint) {
        insert(png, ending: "png", at: center)
    }

    /// Writes an image into the board's folder of images and adds it, at most 640 points on its long side.
    private func insert(_ data: Data, ending: String, at center: CGPoint) {
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else { return }
        let name = "\(UUID().uuidString.lowercased()).\(ending)"
        do {
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
            try data.write(to: assets.appendingPathComponent(name), options: .atomic)
        } catch {
            return
        }
        let scale = min(1, 640 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        var figure = Figure(kind: .image, points: [center - CGPoint(x: size.width / 2, y: size.height / 2), center + CGPoint(x: size.width / 2, y: size.height / 2)])
        figure.source = name
        change { $0.add(figure) }
        selection = [figure.id]
        tool = .select
    }

    /// Sets where the words of the selected shapes and texts sit across their box.
    func align(_ align: Figure.Align) {
        change { board in
            for id in selection where board[id]?.kind == .shape || board[id]?.kind == .text {
                board.update(id) { $0.align = align }
            }
        }
    }

    /// Sets where the words of the selected shapes and texts sit up and down their box.
    func place(_ place: Figure.Place) {
        change { board in
            for id in selection where board[id]?.kind == .shape || board[id]?.kind == .text {
                board.update(id) { $0.place = place }
            }
        }
    }

    func arrange(_ arrangement: Board.Arrangement) {
        change { $0.arrange(selection, arrangement) }
    }

    /// The first selected figure that holds words.
    var wording: Figure? {
        selection.compactMap { board[$0] }.first { $0.kind == .shape || $0.kind == .text }
    }

    /// Picks the form of the shape tool, and gives it to the selected shapes.
    func pick(_ form: Figure.Form) {
        self.form = form
        tool = .shape
        let shapes = selection.filter { board[$0]?.kind == .shape }
        guard !shapes.isEmpty else { return }
        change { board in
            for id in shapes { board.update(id) { $0.form = form } }
        }
    }
}
