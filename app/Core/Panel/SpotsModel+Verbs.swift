import Foundation

extension SpotsModel {
    struct Removal {
        let id: String
        let words: String
        let moves: [(from: URL, to: URL)]
    }

    static let undoKey = ActionKey(name: "z", isCommand: true)

    private func file(of entry: Entry) -> URL {
        entry.spot.fault?.file ?? entry.spot.url
    }

    public func act(_ act: CardAct, on id: String) -> Bool {
        guard let entry = cards.first(where: { $0.id == id && $0.item == nil }) else { return false }
        switch act {
        case .edit:
            if isShown { host.dismiss() }
            edit(entry)
        case .prompt: copyPrompt(changing: entry)
        case .share: share(entry)
        case .delete: remove(entry)
        }
        return true
    }

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

    func copyPrompt(changing entry: Entry) {
        let prompt = host.agentPrompt(for: folder.url)
        let text = prompt.changing(file(of: entry), failure: entry.failure)
        Task {
            do {
                host.confirm(try await prompt.copy(text))
            } catch {
                host.notify("The prompt for \(entry.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    func remove(_ entry: Entry) {
        closeList(moving: isShown)
        let command = entry.spot.fault.map { Spot(id: entry.id, name: $0.name, url: $0.file) } ?? entry.spot
        let count = entry.kind == .widget ? entries.filter { $0.spot.url == entry.spot.url }.count : 1
        let words = count > 1 ? "\(count) widgets" : command.name
        var moves: [(from: URL, to: URL)] = []
        do {
            try folder.remove(command) { url in moves.append((url, try files.trash(url))) }
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

    func undoRemoval() -> Bool {
        guard let removal else { return false }
        self.removal = nil
        do {
            for move in removal.moves.reversed() {
                try FileManager.default.moveItem(at: move.to, to: move.from)
            }
        } catch {
            host.notify("Openspot cannot put \(removal.words) back, because a file left the Trash. Find it in the Trash, and move it to the spots folder.")
            return true
        }
        reload()
        if let place = visible.firstIndex(where: { $0.id == removal.id }) { selected = place }
        host.confirm("Put \(removal.words) back.")
        return true
    }
}
