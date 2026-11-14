import Foundation

/// The calls of `openspot spot`: the spots that the app loads, the ones that come with it, and those that `spot add` put in
/// the spots folder.
struct SpotCalls {
    let environment: [String: String]
    let app: (any RunningApp)?
    /// The runs of the app, whose counts of today are live, or nil in a process with no app to reach.
    let runs: SpotRuns?

    func list(core: Bool, frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let list = SpotList(folder: SpotsFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
            switch (core, frame) {
            case (true, true): return list.coreFrame()
            case (true, false): return try list.core()
            case (false, true): return try list.loadedFrame()
            case (false, false): return try list.loaded()
            }
        }
    }

    func turn(_ ids: [String], on isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            try SpotsFolder.standard(environment: environment).turn(ids, on: isOn, in: ConfigFile.standard(environment: environment))
            await app?.configChanged(.spots(ids))
            return ""
        }
    }

    func add(_ source: String, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
            let folder = SpotsFolder.standard(environment: environment, enabled: [], disabled: [])
            return try await SpotLock.standard(environment: environment).add(SpotSource(text: source, place: place), to: folder.url, isConfirmed: isConfirmed)
        }
    }

    func restore(isConfirmed: Bool) -> CommandAPI.Work {
        { [environment] in
            do {
                return try await SpotLock.standard(environment: environment).restore(to: SpotsFolder.standard(environment: environment, enabled: [], disabled: []).url, isConfirmed: isConfirmed)
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }

    func remove(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let folder = SpotsFolder.standard(environment: environment, enabled: [], disabled: [])
            return "Removed \(try SpotLock.standard(environment: environment).remove(id, from: folder.url).name).\n"
        }
    }

    func open(_ id: String, page: String?) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot open \(id)") }
        return CommandAnswer.work {
            guard await app.open(id, page: page) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    /// Asks the person for files for a spot that takes them, as a press of its card does.
    func choose(for id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot choose \(id)") }
        return CommandAnswer.work {
            guard await app.choose(for: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)` that takes files. Add drop= to its header.") }
            return ""
        }
    }

    /// Does what the row of a card's actions menu does to a spot, in the running app.
    func act(_ act: CardAct, _ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot \(act.rawValue) \(id)") }
        return CommandAnswer.work {
            guard await app.act(act, on: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    func store() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot store") }
        return CommandAnswer.work {
            await app.openStore()
            return ""
        }
    }

    /// Opens the panel with the spot selected, or returns nil when no app runs, so that a process of its own asks for it.
    func show(_ id: String) -> CommandAPI.Work? {
        guard let app else { return nil }
        return CommandAnswer.work {
            guard await app.reveal(id) else { throw SpotError.failed(1, "Openspot has no spot \(id). Run `openspot check` to see each file that does not load.") }
            return "Openspot shows \(id).\n"
        }
    }

    /// Makes one call of an installed spot, prints each frame as it comes with a `---` line between frames and its stderr
    /// at its end, and exits with the code of the script. It runs with the working folder and the variables of the caller,
    /// and `input` is its stdin, or nil when the caller's stdin is no pipe or file. `careful` is the most uses that Careful
    /// mode leaves the script, or nil to run it as the person (protocol: Trust).
    func run(_ id: String, _ arguments: [String], input: (@Sendable () async -> String)?, careful: Set<SpotUse>?, output: CommandOutput) -> CommandAPI.Work {
        { [environment, runs] in
            let folder = SpotsFolder.standard(environment: environment)
            let found: Spot?
            do {
                found = try folder.scan().scripts.first { $0.id == id }
            } catch {
                return CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1)
            }
            guard var spot = found else {
                return CommandAnswer(errors: "Openspot has no spot \(id) in \(folder.url.path). Run `openspot check` to see each file that does not load.\n", code: 1)
            }
            if let careful { spot.uses.formIntersection(careful) }
            let text = await input?()
            let place = environment["PWD"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            let run = TerminalRun(spot: spot, arguments: arguments, input: text, careful: careful == nil ? nil : spot.uses, tokens: runs?.tokens, environment: environment, folder: place)
            var first = true
            let end = await run.start { frame in
                output.print((first ? "" : "---\n") + frame)
                first = false
            }
            return CommandAnswer(errors: end.errors, code: end.code)
        }
    }

    func back(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot back \(id)") }
        return CommandAnswer.work {
            guard await app.back(id) else { throw SpotError.failed(1, "The panel shows no page of `\(id)` to go back from.") }
            return ""
        }
    }

    func review(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot review \(id)") }
        return CommandAnswer.work {
            guard await app.review(id) else { throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.") }
            return ""
        }
    }

    func new(_ name: String, from starter: SpotStarter) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let file = try starter.write(name: name, in: SpotsFolder.standard(environment: environment).url)
            return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
        }
    }

    func log(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let text = AppPlaces(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).log.text(of: id)
            return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
        }
    }

    /// The counts of the last days: today's live from the running app, or with none each day from its file (protocol: Stats).
    func stats(days: Int, spot: String?, format: StatsReport.Format) -> CommandAPI.Work {
        CommandAnswer.work { [environment, runs] in
            let counts: [SpotUsage.Day]
            if let runs {
                let now = await MainActor.run { runs.now() }
                counts = runs.usage.days(days, at: now)
            } else {
                counts = SpotUsage.days(days, at: Date(), in: AppPlaces(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).stats)
            }
            return try StatsReport(days: counts, spot: spot).text(format)
        }
    }
}
