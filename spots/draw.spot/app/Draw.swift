import AppKit

/// Draw as Openspot runs it: one process that answers each call of the sheet, and shows the board window. The call
/// that opens the window waits until the window closes, which is what keeps the process when the sheet is gone. Draw
/// ends when the window closes, when that call is stopped, when Openspot closes stdin, and when it is told to end.
/// Each of them saves the changed boards first.
@MainActor
final class Draw: NSObject, NSApplicationDelegate {
    /// What Draw says when another Draw holds the boards.
    static let busy = "Another Draw has these boards open, so nothing changed. Close it, then try again."

    private let shelf: Shelf
    private let home: URL
    private let host: Host
    private let ends: () -> Void
    /// Whether a board shows in a window. A test sends the call `windowless` first, and then none does.
    private var shows = true
    private(set) var desk: Desk?
    private var lock: Lock?
    private var term: DispatchSourceSignal?
    /// The call that waits while the window shows.
    private var held: Int?
    /// How many calls have held the window, which numbers the ids of the sheet.
    private var turn = 0

    /// Draw over the boards in a folder. `ends` is what ends the process.
    init(boards: URL, home: URL, host: Host = Host(), ends: @escaping () -> Void = { exit(0) }) {
        shelf = Shelf(folder: boards)
        self.home = home
        self.host = host
        self.ends = ends
    }

    /// Makes the folder of the boards, removes the program and the build log that the Draw before this one kept in
    /// its data folder, and saves before it ends when it is told to end, as Openspot does to a spot that is slow to go.
    func ready() {
        try? FileManager.default.createDirectory(at: shelf.folder, withIntermediateDirectories: true)
        for old in ["Draw", "Draw.new", "build.log"] {
            try? FileManager.default.removeItem(at: shelf.folder.deletingLastPathComponent().appendingPathComponent(old))
        }
        signal(SIGTERM, SIG_IGN)
        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        term.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
        term.resume()
        self.term = term
    }

    /// Starts to answer the calls of Openspot.
    func listen() {
        ready()
        host.listen { [weak self] call in self?.take(call) }
    }

    /// Whether this Draw may change the boards. One Draw at a time holds them, from its first change until it ends,
    /// so no second process writes a board that the first one has open.
    private func holds() -> Bool {
        if lock == nil { lock = Lock.claim(shelf.folder) }
        return lock != nil
    }

    private var sheet: Sheet {
        Sheet(shelf: shelf, turn: turn)
    }

    /// Answers one call, or ends Draw when the calls are over.
    func take(_ call: Call?) {
        switch call {
        case .ask(let id, let arguments, let input):
            let argument = arguments.dropFirst().first ?? input["input.item"]
            let row = argument.map(Sheet.name(in:))
            let word = Sheet.name(in: arguments.first ?? "")
            let changes = ["press", "new", "delete"].contains(word) || (word == "rename" && input["input.name"] != nil)
            guard !changes || holds() else { return end(id, saying: Draw.busy) }
            switch word {
            case "show": host.send(sheet.frame(head: ["end=\(id)"]))
            case "press": open(row == "new" ? nil : row, call: id)
            case "new": open(nil, call: id)
            case "rename": rename(row, to: input["input.name"], call: id, argument: argument ?? "")
            case "delete": delete(row, call: id)
            case "reveal":
                reveal()
                host.send("end=\(id)")
            case "windowless":
                shows = false
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
            guard let found = sheet.file(named: name) else { return end(call, saying: "This board is gone.") }
            file = found
        } else {
            guard let made = try? shelf.make(in: nil) else { return end(call, saying: "Draw cannot make a board in \(shelf.folder.path).") }
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
            return end(call, saying: Desk.unreadable)
        }
        desk.listChanged()
        guard held == nil else { return host.send("end=\(call)") }
        held = call
        turn += 1
        host.send(sheet.frame(head: ["call=\(call)"]))
    }

    /// Asks for the new name of a board, or gives it the name that the person typed.
    private func rename(_ name: String?, to title: String?, call: Int, argument: String) {
        guard let file = name.flatMap(sheet.file(named:)) else { return end(call, saying: "This board is gone.") }
        let title = (title ?? "").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            return host.send(Sheet.renameForm(title: Titles.shared.title(of: file), head: ["end=\(call)"]))
        }
        if let open = desk?.tabs.studio(for: file) {
            open.rename(title)
            Saves.shared.wait()
        } else if (try? shelf.rename(file, to: title)) == nil {
            return end(call, saying: "Draw cannot rename it, so it keeps its name.")
        }
        desk?.listChanged()
        host.call(["select", argument])
        host.send("end=\(call)")
    }

    /// Moves a board with its picture and its images to the Trash, and closes its tab.
    private func delete(_ name: String?, call: Int) {
        guard let file = name.flatMap(sheet.file(named:)) else { return end(call, saying: "This board is gone.") }
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
            host.call(["toast", "Draw cannot move \(title) to the Trash, so it stays."])
            return host.send(sheet.frame(head: ["end=\(call)"]))
        }
        desk?.listChanged()
        host.call(["toast", "Moved \(title) to the Trash."])
        host.send(sheet.frame(head: ["end=\(call)"]))
    }

    /// Ends a call with a toast that says why.
    private func end(_ call: Int, saying toast: String) {
        host.call(["toast", toast])
        host.send("end=\(call)")
    }

    /// Shows the folder of the boards in Finder.
    private func reveal() {
        let finder = Process()
        finder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        finder.arguments = ["open", shelf.folder.path]
        try? finder.run()
    }

    /// Saves each board that changed, ends the call that waits, lets the boards go, and ends Draw.
    private func end() {
        finish()
        lock?.release()
        lock = nil
        ends()
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
