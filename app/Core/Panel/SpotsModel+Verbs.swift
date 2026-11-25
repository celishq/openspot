import Foundation

extension SpotsModel {
    private func file(of entry: Entry) -> URL {
        entry.spot.fault?.file ?? entry.spot.url
    }

    public func act(_ act: CardAct, on id: String) -> Bool {
        guard let entry = cards.first(where: { $0.id == id && $0.item == nil }) else { return false }
        switch act {
        case .settings:
            if !openSettings(of: entry) { toast(.failure("\(entry.state.title) has nothing to set.")) }
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
                toast(.failure("Openspot cannot open \(path). \(Self.reason(error))"))
            }
        }
    }

    func copyPrompt(changing entry: Entry) {
        let prompt = host.agentPrompt(for: folder.url)
        let file = file(of: entry)
        Task {
            let evidence = await SpotEvidence.read(of: entry.id, runs: runs, stats: files.stats, app: prompt.app)
            let text = prompt.changing(file, failure: entry.failure, evidence: evidence)
            do {
                toast(ToastNote(words: try await prompt.copy(text, base: runs.environment)))
            } catch {
                toast(.failure("The prompt for \(entry.spot.name) was not copied. \(Self.reason(error))"))
            }
        }
    }

    func remove(_ entry: Entry) {
        closeSheet(moving: isShown)
        let command = entry.spot.fault.map { Spot(id: entry.id, name: $0.name, url: $0.file) } ?? entry.spot
        let folder = folder
        let ids = Set(entries.filter { $0.spot.url == entry.spot.url }.map(\.spot.id) + [entry.id])
        let trash = files.trash
        let log = files.log
        let secrets = files.secrets
        Task {
            let failure = await Self.discard(command, in: folder, trash: trash, log: log, secrets: secrets, of: ids)
            await reload()
            if let failure {
                toast(.failure("\(command.name) was not removed. \(failure)"))
            } else {
                toast("Moved \(command.name) to the Trash.")
            }
        }
    }

    @concurrent
    private nonisolated static func discard(
        _ spot: Spot, in folder: SpotsFolder, trash: @Sendable (URL) throws -> Void, log: CallLog, secrets: SecretStore, of ids: Set<String>
    ) async -> String? {
        do {
            try folder.remove(spot, discard: trash)
            log.remove(spot.id)
            try secrets.remove { ids.contains($0) }
            return nil
        } catch {
            return reason(error)
        }
    }
}
