import Foundation

extension SpotsModel {
    struct Removal {
        let id: String
        let words: String
        let moves: [(from: URL, to: URL)]
        var secrets: SecretStore.Values = [:]
    }

    static let undoKey = ActionKey(name: "z", isCommand: true)

    private func file(of entry: Entry) -> URL {
        entry.spot.fault?.file ?? entry.spot.url
    }

    public func act(_ act: CardAct, on id: String) -> Bool {
        guard let entry = cards.first(where: { $0.id == id && $0.item == nil }) else { return false }
        switch act {
        case .settings:
            if !isShown { host.show() }
            if !openSettings(of: entry) { host.notify("\(entry.state.title) has nothing to set.") }
        case .edit:
            if openEdit(of: entry) {
                if !isShown { host.show() }
            } else {
                if isShown { host.dismiss() }
                edit(entry)
            }
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
                _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", "-t", path], base: runs.environment)
            } catch {
                host.notify("Openspot cannot open \(path). \(Self.reason(error))")
            }
        }
    }

    func copyPrompt(changing entry: Entry) {
        let prompt = host.agentPrompt(for: folder.url)
        let file = file(of: entry)
        Task {
            let evidence = await SpotEvidence.read(of: entry.id, runs: runs, environment: runs.environment, app: prompt.app)
            let text = prompt.changing(file, failure: entry.failure, evidence: evidence)
            do {
                host.confirm(try await prompt.copy(text, base: runs.environment))
            } catch {
                host.notify("The prompt for \(entry.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    func remove(_ entry: Entry) {
        closeSheet(moving: isShown)
        let command = entry.spot.fault.map { Spot(id: entry.id, name: $0.name, url: $0.file) } ?? entry.spot
        let count = entry.kind == .widget ? entries.filter { $0.spot.url == entry.spot.url }.count : 1
        let words = count > 1 ? "\(count) widgets" : command.name
        let id = entry.id
        let folder = folder
        let ids = Set(entries.filter { $0.spot.url == entry.spot.url }.map(\.spot.id) + [entry.id])
        removal = nil
        removals += 1
        let turn = removals
        let trash = files.trash
        let log = files.log
        let secrets = files.secrets
        Task {
            let (moves, kept, failure) = await Self.discard(command, in: folder, trash: trash, log: log, secrets: secrets, of: ids)
            if turn == removals { removal = failure == nil || !moves.isEmpty ? Removal(id: id, words: words, moves: moves, secrets: kept) : nil }
            await reload()
            if let failure {
                host.notify("\(command.name) was not removed. \(failure)")
            } else {
                host.confirm("Moved \(words) to the Trash. Press `⌘Z` to put \(count > 1 ? "them" : "it") back.")
            }
        }
    }

    @concurrent
    private nonisolated static func discard(
        _ spot: Spot, in folder: SpotsFolder, trash: @Sendable (URL) throws -> URL, log: CallLog, secrets: SecretStore, of ids: Set<String>
    ) async -> (moves: [(from: URL, to: URL)], secrets: SecretStore.Values, failure: String?) {
        var moves: [(from: URL, to: URL)] = []
        do {
            try folder.remove(spot) { url in moves.append((url, try trash(url))) }
            log.remove(spot.id)
            return (moves, try secrets.remove { ids.contains($0) }, nil)
        } catch {
            return (moves, [:], reason(error))
        }
    }

    func undoRemoval() -> Bool {
        guard let removal else { return false }
        self.removal = nil
        let chosen = selectedEntry?.id
        Task {
            guard await Self.putBack(removal.moves, secrets: removal.secrets, in: files.secrets) else {
                return host.notify("Openspot cannot put \(removal.words) back, because a file left the Trash. Find it in the Trash, and move it to the spots folder.")
            }
            await reload()
            if selectedEntry?.id == chosen, let place = visible.firstIndex(where: { $0.id == removal.id }) { selected = place }
            host.confirm("Put \(removal.words) back.")
        }
        return true
    }

    @concurrent
    private nonisolated static func putBack(_ moves: [(from: URL, to: URL)], secrets: SecretStore.Values, in store: SecretStore) async -> Bool {
        do {
            for move in moves.reversed() { try FileManager.default.moveItem(at: move.to, to: move.from) }
            try store.putBack(secrets)
            return true
        } catch {
            return false
        }
    }
}
