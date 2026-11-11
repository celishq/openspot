import Foundation

/// The acts that the app adds to each spot of the person: open its file in the text editor, copy a prompt for an agent to
/// change it, and delete it so that `⌘Z` puts it back.
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

    /// Opens the file of a spot in the text editor.
    func edit(_ entry: Entry) {
        let path = file(of: entry).path
        Task {
            do {
                _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", "-t", path])
            } catch {
                host.notify("Openspot cannot open \(path). \(Self.reason(error))")
            }
        }
    }

    /// The prompt that asks an agent to write or fix a spot.
    var agentPrompt: AgentPrompt? {
        entries.lazy.compactMap(\.command.agentPrompt).first
    }

    /// Copies a prompt that asks an agent to change the file of a spot, with the words of its last failed call.
    func copyPrompt(changing entry: Entry) {
        guard let prompt = agentPrompt else {
            host.notify("Openspot cannot write the prompt, because New spot is missing. Quit and open Openspot again.")
            return
        }
        let text = prompt.changing(file(of: entry), failure: entry.failure)
        Task {
            do {
                host.confirm(try await prompt.copy(text))
            } catch {
                host.notify("The prompt for \(entry.command.name) was not copied. \(Self.reason(error))")
            }
        }
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
