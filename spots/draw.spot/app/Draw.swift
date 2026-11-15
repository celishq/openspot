import AppKit

/// Draw as Openspot runs it: one process that answers each call of the sheet, and shows the board window. The call
/// that opens the window waits until the window closes, which is what keeps the process when the sheet is gone. Draw
/// ends when the window closes, when that call is stopped, and when Openspot closes stdin.
@MainActor
final class Draw: NSObject, NSApplicationDelegate {
    private let shelf: Shelf
    private let home: URL
    private let shows: Bool
    private let host = Host()
    private var desk: Desk?
    /// The call that waits while the window shows.
    private var held: Int?
    /// How many calls have held the window, which numbers the ids of the sheet.
    private var turn = 0

    /// Draw over the boards in a folder. `shows` is false where no window may show, such as in a test.
    init(boards: URL, home: URL, shows: Bool) {
        shelf = Shelf(folder: boards)
        self.home = home
        self.shows = shows
    }

    /// Starts to answer the calls of Openspot.
    func listen() {
        try? FileManager.default.createDirectory(at: shelf.folder, withIntermediateDirectories: true)
        host.listen { [weak self] call in self?.take(call) }
    }

    private var sheet: Sheet {
        Sheet(shelf: shelf, turn: turn)
    }

    private func take(_ call: Call?) {
        switch call {
        case .ask(let id, let arguments, let input):
            let row = arguments.dropFirst().first.map(Sheet.name(in:))
            switch Sheet.name(in: arguments.first ?? "") {
            case "read": host.send(sheet.frame(head: ["end=\(id)"]))
            case "open": open(row == "new" ? nil : row, call: id)
            case "new": open(nil, call: id)
            case "rename": rename(row, to: input["name"], call: id, argument: arguments.dropFirst().first ?? "")
            case "delete": delete(row, call: id)
            case "reveal":
                reveal()
                host.send("end=\(id)")
            default: host.send("end=\(id)")
            }
        case .stop(let id):
            if id == held { end() }
        case nil:
            end()
        }
    }

    /// Shows a board, or a new one, in the window. The first call to do so waits for the window to close.
    private func open(_ name: String?, call: Int) {
        let file: URL
        if let name {
            guard let found = sheet.file(named: name) else { return host.send("end=\(call)\ntoast=This board is gone.") }
            file = found
        } else {
            guard let made = try? shelf.make(in: nil) else { return host.send("end=\(call)\ntoast=Draw cannot make a board in \(shelf.folder.path).") }
            file = made
        }
        let desk = desk ?? Desk(folder: shelf.folder, shows: shows)
        if self.desk == nil {
            desk.closed = { [weak self] in self?.end() }
            self.desk = desk
        }
        do {
            try desk.open(file)
        } catch {
            return host.send("end=\(call)\ntoast=\(Desk.unreadable)")
        }
        desk.listChanged()
        guard held == nil else { return host.send("end=\(call)") }
        held = call
        turn += 1
        host.send(sheet.frame(head: ["call=\(call)"]))
    }

    /// Asks for the new name of a board, or gives it the name that the person typed.
    private func rename(_ name: String?, to title: String?, call: Int, argument: String) {
        guard let file = name.flatMap(sheet.file(named:)) else { return host.send("end=\(call)\ntoast=This board is gone.") }
        let title = (title ?? "").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            return host.send(Sheet.renameForm(title: Titles.shared.title(of: file), head: ["end=\(call)"]))
        }
        if let open = desk?.tabs.studio(for: file) {
            open.rename(title)
            Saves.shared.wait()
        } else if (try? shelf.rename(file, to: title)) == nil {
            return host.send("end=\(call)\ntoast=Draw cannot rename it, so it keeps its name.")
        }
        desk?.listChanged()
        host.send("end=\(call)\nselect=\(Call.written(argument))")
    }

    /// Moves a board with its picture and its images to the Trash, and closes its tab.
    private func delete(_ name: String?, call: Int) {
        guard let file = name.flatMap(sheet.file(named:)) else { return host.send("end=\(call)\ntoast=This board is gone.") }
        let title = Titles.shared.title(of: file)
        desk?.close(boardsAt: [file])
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        let stem = "\(title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-"))-\(Int(Date().timeIntervalSince1970))"
        do {
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            try shelf.discard(file) { part in
                try FileManager.default.moveItem(at: part, to: trash.appendingPathComponent(stem).appendingPathExtension(part.pathExtension))
            }
        } catch {
            return host.send(sheet.frame(head: ["end=\(call)", "toast=\(Call.written("Draw cannot move \(title) to the Trash, so it stays."))"]))
        }
        desk?.listChanged()
        host.send(sheet.frame(head: ["end=\(call)", "toast=\(Call.written("Moved \(title) to the Trash."))"]))
    }

    /// Shows the folder of the boards in Finder.
    private func reveal() {
        let finder = Process()
        finder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        finder.arguments = ["open", shelf.folder.path]
        try? finder.run()
    }

    /// Saves each board that changed, ends the call that waits, and ends Draw.
    private func end() -> Never {
        finish()
        exit(0)
    }

    private func finish() {
        desk?.finish()
        if let held { host.send("end=\(held)") }
        held = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        finish()
    }
}
