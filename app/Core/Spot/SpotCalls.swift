import Foundation

struct SpotCalls {
    let environment: [String: String]
    let folder: URL
    let app: (any RunningApp)?
    let runs: SpotRuns?
    let secrets: SecretStore
    let caller: CallerTokens.Caller?

    init(_ context: CallContext) {
        caller = context.caller
        environment = context.environment
        folder = context.folder
        app = context.app
        runs = context.runs
        secrets = context.secrets
    }

    func list(core: Bool, form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let list = SpotList(folder: SpotsFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
            return try core ? list.core(form) : list.loaded(form)
        }
    }

    func turn(_ ids: [String], on isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let config = try SpotsFolder.standard(environment: environment).turn(ids, on: isOn, in: ConfigFile.standard(environment: environment))
            await app?.configChanged(.spots(ids), to: config)
            return ""
        }
    }

    func add(_ source: String, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, folder, app] in
            let spots = SpotsFolder.standard(environment: environment, enabled: [], disabled: [])
            let answer = try await SpotLock.standard(environment: environment).add(SpotSource(text: source, place: folder), to: spots.url, isConfirmed: isConfirmed)
            await app?.spotsChanged()
            return answer
        }
    }

    func restore(isConfirmed: Bool) -> CommandAPI.Work {
        { [environment, app] in
            do {
                let answer = try await SpotLock.standard(environment: environment).restore(to: SpotsFolder.standard(environment: environment, enabled: [], disabled: []).url, isConfirmed: isConfirmed)
                await app?.spotsChanged()
                return answer
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }

    func remove(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app, secrets] in
            let folder = SpotsFolder.standard(environment: environment, enabled: [], disabled: [])
            let removed = try SpotLock.standard(environment: environment).remove(id, from: folder.url).name
            _ = try secrets.remove { SpotID($0).isSameFolder(as: SpotID(removed)) }
            await app?.spotsChanged()
            return "Removed \(removed).\n"
        }
    }

    func trust(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            guard let entry = try SpotLock.standard(environment: environment).entries().first(where: { $0.holds(id) }) else {
                throw SpotError.failed(1, "`openspot spot add` did not add \(id), so it runs as you made it.")
            }
            let grant = Trust.grant(of: entry)
            _ = try ConfigFile.standard(environment: environment).change { $0.add(grant) }
            return entry.key == nil ? "TrustGrant \(entry.name).\n" : "TrustGrant the author of \(entry.name).\n"
        }
    }

    func open(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot open \(id)") }
        return CommandAnswer.work {
            guard await app.open(id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    func choose(for id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot choose \(id)") }
        return CommandAnswer.work {
            guard await app.choose(for: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)` that takes files. Add drop= to its header.") }
            return ""
        }
    }

    func act(_ act: CardAct, _ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot \(act.rawValue) \(id)") }
        return CommandAnswer.work {
            guard await app.act(act, on: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    func editGrid() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("grid edit") }
        return CommandAnswer.work {
            await app.editGrid()
            return ""
        }
    }

    func show(_ id: String) -> CommandAPI.Work? {
        guard let app else { return nil }
        return CommandAnswer.work {
            guard await app.reveal(id) else { throw SpotError.failed(1, "Openspot has no spot \(id). Run `openspot check spots` to see each file that does not load.") }
            return "Openspot shows \(id).\n"
        }
    }

    func run(_ id: String, _ arguments: [String], input: (@Sendable () async -> String)?, output: CommandOutput) -> CommandAPI.Work {
        { [environment, folder, runs, caller] in
            let spots = SpotsFolder.standard(environment: environment)
            let found: Spot?
            do {
                found = try spots.scan().scripts.first { $0.id == id }
            } catch {
                return CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1)
            }
            guard let spot = found.map((runs?.tokens.trust ?? Trust()).applied) else {
                return CommandAnswer(errors: "Openspot has no spot \(id) in \(spots.url.path). Run `openspot check spots` to see each file that does not load.\n", code: 1)
            }
            let text = await input?()
            let usage = caller == nil || spot.reachesAccountKey ? nil : runs?.usage
            let run = TerminalRun(spot: spot, arguments: arguments, input: text, sandbox: spot.isRestricted ? spot.uses : nil, tokens: runs?.tokens, environment: environment, folder: folder, usage: usage)
            let begin = Date()
            var first = true
            let end = await run.start { frame in
                output.print((first ? "" : "---\n") + frame)
                first = false
            }
            if let usage, let caller {
                let failure: StatsLog.Failure? = switch end.code {
                case 0: nil
                case 124: .timeout
                default: .exit
                }
                usage.ran(spot, by: caller.id, CallOutcome(seconds: Date().timeIntervalSince(begin), failure: failure), at: usage.now())
            }
            return CommandAnswer(errors: end.errors, code: end.code)
        }
    }

    func push(_ id: String, page: String?, title: String?, replace: Bool) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot push \(id)") }
        return CommandAnswer.work {
            guard await app.push(id, page: page, title: title, replace: replace) else {
                throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.")
            }
            return ""
        }
    }

    func pop(_ id: String, all: Bool) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot pop \(id)") }
        return CommandAnswer.work {
            guard await app.pop(id, all: all) else { throw SpotError.failed(1, "The panel shows no sheet of `\(id)` to go back from.") }
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
        CommandAnswer.work { [environment, app] in
            let file = try starter.write(name: name, in: SpotsFolder.standard(environment: environment).url)
            await app?.spotsChanged()
            return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
        }
    }

    func log(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let text = AppPlaces(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).log.text(of: id)
            return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
        }
    }

    func stats(days: Int, spot: String?, format: Stats.Form, byVersion: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, runs] in
            let counts = await StatsLog.days(days, runs: runs, environment: environment)
            let cards = (try? SpotsFolder.standard(environment: environment).scan().spots) ?? []
            return try Stats(days: counts, spot: spot, cards: cards, byVersion: byVersion).text(format)
        }
    }
}
