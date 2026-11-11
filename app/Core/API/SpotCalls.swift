import Foundation

/// The calls of `openspot spot`: the spots that the app loads, the ones that come with it, and those that `spot add` put in
/// the plugins folder.
struct SpotCalls {
    let environment: [String: String]
    let app: (any RunningApp)?
    /// The runs of the app, whose counts of today are live, or nil in a process with no app to reach.
    let runs: SpotRuns?

    func list(core: Bool, frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let list = SpotList(folder: SpotFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
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
            try SpotFolder.standard(environment: environment).turn(ids, on: isOn, in: ConfigFile.standard(environment: environment))
            await app?.configChanged(.spots(ids))
            return ""
        }
    }

    func add(_ source: String, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
            let folder = SpotFolder.standard(environment: environment, enabled: [], disabled: [])
            return try await SpotLock.standard(environment: environment).add(SpotSource(text: source, place: place), to: folder.url, isConfirmed: isConfirmed)
        }
    }

    func restore(isConfirmed: Bool) -> CommandAPI.Work {
        { [environment] in
            do {
                return try await SpotLock.standard(environment: environment).restore(to: SpotFolder.standard(environment: environment, enabled: [], disabled: []).url, isConfirmed: isConfirmed)
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }

    func remove(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let folder = SpotFolder.standard(environment: environment, enabled: [], disabled: [])
            return "Removed \(try SpotLock.standard(environment: environment).remove(id, from: folder.url).name).\n"
        }
    }

    func open(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning }
        return CommandAnswer.work {
            guard await app.open(id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    func review(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning }
        return CommandAnswer.work {
            guard await app.review(id) else { throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.") }
            return ""
        }
    }

    func new(_ name: String, from starter: SpotStarter) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let file = try starter.write(name: name, in: SpotFolder.standard(environment: environment).url)
            return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
        }
    }

    func log(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let text = SpotFiles(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).log.text(of: id)
            return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
        }
    }

    /// The counts of the last days: today's live from the running app, or with none each day from its file (Z11).
    func stats(days: Int, spot: String?, format: StatsReport.Format) -> CommandAPI.Work {
        CommandAnswer.work { [environment, runs] in
            let counts: [SpotUsage.Day]
            if let runs {
                let now = await MainActor.run { runs.now() }
                counts = runs.usage.days(days, at: now)
            } else {
                counts = SpotUsage.days(days, at: Date(), in: SpotFiles(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).stats)
            }
            return try StatsReport(days: counts, spot: spot).text(format)
        }
    }
}
