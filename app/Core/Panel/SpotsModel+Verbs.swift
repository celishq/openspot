import Foundation

/// The acts that the app adds to each spot of the person: open its file in the text editor or in Finder, start an agent on
/// it, copy it under a new name, and delete it so that `⌘Z` puts it back.
extension SpotsModel {
    /// The files of a spot that Delete moved to the Trash, and where each went.
    struct Removal {
        let id: String
        let words: String
        let moves: [(from: URL, to: URL)]
    }

    static let undoKey = ActionKey(name: "z", isCommand: true)

    /// The file that the card stands for: the file of a spot, or the file of a card of faults.
    private func file(of entry: Entry) -> URL {
        entry.command.fault?.file ?? entry.command.url
    }

    /// Opens the file of a spot in the text editor, or shows it in Finder.
    func open(_ entry: Entry, revealing: Bool) {
        let path = file(of: entry).path
        Task {
            do {
                _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", revealing ? "-R" : "-t", path])
            } catch {
                host.notify("Openspot cannot open \(path). \(Self.reason(error))")
            }
        }
    }

    /// Starts the agent of the New spot sheet on the file of a spot, with the words of its last failed call.
    func change(_ entry: Entry) {
        guard let new = entries.lazy.compactMap({ if case .new(let new)? = $0.command.shipped { new } else { nil } }).first else {
            host.notify("Openspot cannot start an agent, because New spot is missing. Quit and open Openspot again.")
            return
        }
        let text = new.handoff.prompt.changing(file(of: entry), failure: entry.failure)
        let choice = new.config.read().setting(NewSpot.agentPart, of: ShippedSpot.newID)
        if isShown { host.dismiss() }
        Task {
            do {
                host.confirm(try await new.handoff.hand(text, choice: choice, doing: "changing it"))
            } catch {
                host.notify("\(entry.command.name) did not reach an agent. \(Self.reason(error))")
            }
        }
    }

    /// Copies the file of a spot under the first free name `<name> copy`, with that title and with no key, and selects the
    /// copy.
    func duplicate(_ entry: Entry) {
        let source = entry.command.url
        let folder = source.deletingLastPathComponent()
        let name = SpotStarter.freeName("\(entry.command.name) copy", in: folder)
        let file = folder.appendingPathComponent(SpotStarter.slug(of: name)).appendingPathExtension(source.pathExtension)
        do {
            let text = try String(contentsOf: source, encoding: .utf8)
            try Self.renamed(text, to: name).write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
            reload()
            let id = file.deletingPathExtension().lastPathComponent
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
            host.confirm("Made \(name).")
        } catch {
            host.notify("\(entry.command.name) was not copied. \(Self.reason(error))")
        }
    }

    /// The text of a script with this title in its header and no `shortcut`, which only the first spot keeps.
    private static func renamed(_ text: String, to title: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let marks = ["#", "//", "--"]
        let header = Array(lines.indices.dropFirst().prefix { index in marks.contains { lines[index].hasPrefix($0) } })
        let mark = header.first.flatMap { index in marks.first { lines[index].hasPrefix($0) } } ?? "#"
        func key(of line: String) -> String {
            let words = marks.first { line.hasPrefix($0) }.map { String(line.dropFirst($0.count)) } ?? line
            return words.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1).first.map(String.init) ?? ""
        }
        let titled = "\(mark) title=\(title)"
        let keys = Set(header.filter { key(of: lines[$0]) == "shortcut" })
        let named = header.first { key(of: lines[$0]) == "title" }
        if let named { lines[named] = titled }
        lines = lines.enumerated().filter { !keys.contains($0.offset) }.map(\.element)
        if named == nil { lines.insert(titled, at: min(1, lines.count)) }
        return lines.joined(separator: "\n")
    }

    /// Moves the files of a spot to the Trash with no question, keeps the panel open, and says that `⌘Z` puts them back. A
    /// card of faults takes its file. What the spot keeps in `$OPENSPOT_DATA` stays, and its log goes.
    func remove(_ entry: Entry) {
        closeList(moving: isShown)
        let command = entry.command.fault.map { Spot(id: entry.id, name: $0.name, url: $0.file) } ?? entry.command
        let count = entry.kind == .widget ? entries.filter { $0.command.url == entry.command.url }.count : 1
        let words = count > 1 ? "\(count) widgets" : command.name
        var moves: [(from: URL, to: URL)] = []
        do {
            try files.folder.remove(command) { url in moves.append((url, try files.trash(url))) }
            removal = Removal(id: entry.id, words: words, moves: moves)
            files.log.remove(entry.id)
            reload()
            host.confirm("Moved \(words) to the Trash. Press `⌘Z` to put \(count > 1 ? "them" : "it") back.")
        } catch {
            removal = moves.isEmpty ? nil : Removal(id: entry.id, words: words, moves: moves)
            reload()
            host.notify("\(command.name) was not removed. \(Self.reason(error))")
        }
    }

    /// Puts back the files of the last spot that Delete moved to the Trash, and selects its card. Returns false when there
    /// is nothing to put back.
    func undoRemoval() -> Bool {
        guard let removal else { return false }
        self.removal = nil
        do {
            for move in removal.moves.reversed() {
                try FileManager.default.moveItem(at: move.to, to: move.from)
            }
        } catch {
            host.notify("Openspot cannot put \(removal.words) back, because a file left the Trash. Find it in the Trash, and move it to the plugins folder.")
            return true
        }
        reload()
        if let place = visible.firstIndex(where: { $0.id == removal.id }) { selected = place }
        host.confirm("Put \(removal.words) back.")
        return true
    }
}
