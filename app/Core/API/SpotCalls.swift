import Foundation

/// The calls of `openspot spot`: the spots that the app loads, the ones that come with it, and those that `spot add` put in
/// the plugins folder.
struct SpotCalls {
    let environment: [String: String]
    let app: (any RunningApp)?
    /// The rows of `openspot spot stats` in the running app, or nil in a process with no app to reach.
    let stats: (@Sendable () -> String)?

    func list(core: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let list = SpotList(folder: SpotFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
            return try core ? list.core() : list.loaded()
        }
    }

    func turn(_ ids: [String], on isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            try SpotFolder.standard(environment: environment).turn(ids, on: isOn, in: ConfigFile.standard(environment: environment))
            await app?.configChanged()
            return ""
        }
    }

    func add(_ source: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
            let folder = SpotFolder.standard(environment: environment, enabled: [], disabled: [])
            return try await SpotLock.standard(environment: environment).add(SpotSource(text: source, place: place), to: folder.url).added
        }
    }

    func restore() -> CommandAPI.Work {
        { [environment] in
            do {
                return try await SpotLock.standard(environment: environment).restore(to: SpotFolder.standard(environment: environment, enabled: [], disabled: []).url)
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

    func statsText() -> CommandAPI.Work {
        guard let stats else {
            return { CommandAnswer(errors: "Openspot is not running, so it has counted no calls. Open Openspot, then run this again.\n", code: 1) }
        }
        return { CommandAnswer(output: stats()) }
    }
}
