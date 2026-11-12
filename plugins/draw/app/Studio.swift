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
    @Published var form = Figure.Form.rectangle
    @Published var zoom: CGFloat = 1
    private var past: [Board] = []
    private var future: [Board] = []
    private var pending: DispatchWorkItem?
    /// The title on disk when this board last read or wrote it, so a rename in Openspot shows here.
    private var knownTitle: String
    let file: URL

    init(file: URL) {
        self.file = file
        let board = (try? Board.load(from: file)) ?? Board()
        self.board = board
        knownTitle = board.title
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
            for id in selection where board[id]?.kind != .tie {
                board.update(id) { style.dress(&$0) }
            }
        }
    }

    /// Shows the style of the selection in the style panel.
    func pickUpStyle() {
        if let first = selection.lazy.compactMap({ self.board[$0] }).first(where: { $0.kind != .tie }) {
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
        if let title = try? Board.load(from: file).title, title != knownTitle { board.title = title }
        try? board.save(to: file)
        knownTitle = board.title
        if let picture = Painting(board: board, assets: assets).picture(width: 360, height: 240) {
            try? picture.write(to: file.deletingPathExtension().appendingPathExtension("png"), options: .atomic)
        }
    }

    /// Takes the title that Openspot gave the board, and closes a board that Openspot deleted.
    func reloadTitle() {
        guard FileManager.default.fileExists(atPath: file.path) else { return NSApp.terminate(nil) }
        if let title = try? Board.load(from: file).title, title != knownTitle {
            board.title = title
            knownTitle = title
        }
    }

    /// Gives the board a new title, and saves it at once so that Openspot lists it so.
    func rename(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != board.title else { return }
        board.title = title
        save()
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
