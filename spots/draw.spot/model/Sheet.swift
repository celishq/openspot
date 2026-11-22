import Foundation

/// What Draw shows in Openspot: an item that makes a board, then each board, newest first, with the buttons of an item.
struct Sheet {
    let shelf: Shelf
    /// The number that starts the id of each thing that opens the studio. A press of the call that holds the studio
    /// would send it a stop, and Draw ends at that stop, so the number changes each time a call starts to hold the
    /// studio, and no press repeats that call.
    var turn = 0
    var now = Date()

    /// The frame of the sheet, with these lines in its root.
    func frame(head: [String] = []) -> String {
        var blocks = [(["frame=", "recents=false"] + head).joined(separator: "\n")]
        blocks.append("button=open\ntitle=Open")
        blocks.append("button=\(turn):new\ntitle=New board\nshortcut=cmd+n\nscope=spot")
        blocks.append("button=rename\ntitle=Rename\nshortcut=cmd+r\nform=true\nclose=false")
        blocks.append("button=delete\ntitle=Delete\nshortcut=cmd+backspace\nconfirm=Press again to move it to the Trash\nclose=false")
        blocks.append("button=reveal\ntitle=Show boards in Finder\nshortcut=cmd+o\nscope=spot")
        blocks.append("text=\(turn):new\ntitle=New board\ndetail=A blank board\nicon=plus.square.dashed\nhides=rename\nhides=delete")
        for entry in shelf.entries {
            let name = Self.name(of: entry.file, in: shelf.folder)
            let place = (name as NSString).deletingLastPathComponent
            let picture = FileManager.default.fileExists(atPath: entry.picture.path) ? entry.picture.path : "scribble.variable"
            let lines = ["text=\(turn):\(name)", "title=\(entry.title)", "detail=\(place.isEmpty ? "" : "\(place) · ")\(edited(entry.edited))", "icon=\(picture)"]
            blocks.append(lines.map(Self.line).joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    /// The form that asks for the new name of a board.
    static func renameForm(title: String, head: [String]) -> String {
        (["frame=", "type=form"] + head + ["title=Rename board"]).joined(separator: "\n") + "\n\n" + ["field=name", "title=Name", "value=\(title)", "required=true"].map(line).joined(separator: "\n") + "\n"
    }

    /// What an argument of a call names, without the number that starts it: `new`, or the place of a board.
    static func name(in argument: String) -> String {
        guard let cut = argument.firstIndex(of: ":"), !argument[..<cut].isEmpty, argument[..<cut].allSatisfy(\.isNumber) else { return argument }
        return String(argument[argument.index(after: cut)...])
    }

    /// The file of the board that an item names, or nil when it is gone or lies outside the folder of the boards.
    func file(named name: String) -> URL? {
        guard !name.isEmpty, !name.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return nil }
        let file = shelf.folder.appendingPathComponent(name).appendingPathExtension("json")
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue ? file : nil
    }

    /// The place of a board under the folder of the boards, without its ending, such as `Work/plan`.
    private static func name(of file: URL, in folder: URL) -> String {
        let path = file.resolvingSymlinksInPath().deletingPathExtension().path
        let root = folder.resolvingSymlinksInPath().path
        return path.hasPrefix(root + "/") ? String(path.dropFirst(root.count + 1)) : file.deletingPathExtension().lastPathComponent
    }

    /// One line of a block, with its value written so that a new line stays in it.
    private static func line(_ line: String) -> String {
        guard let cut = line.firstIndex(of: "=") else { return line }
        return line[...cut] + Call.written(String(line[line.index(after: cut)...]))
    }

    /// When a board last changed, such as `Edited 5 min ago`.
    private func edited(_ date: Date) -> String {
        let age = Int(now.timeIntervalSince(date))
        if age < 60 { return "Edited just now" }
        if age < 3600 { return "Edited \(age / 60) min ago" }
        if age < 86400 { return "Edited \(age / 3600) h ago" }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "MMM d"
        return "Edited \(day.string(from: date))"
    }
}
