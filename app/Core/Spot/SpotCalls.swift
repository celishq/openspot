import Foundation

struct SpotCalls {
    let places: AppPlaces
    let folder: URL
    let app: (any RunningApp)?
    let runs: SpotRuns?
    let secrets: SecretStore
    let caller: Spot?

    init(_ context: CallContext) {
        caller = context.caller
        places = context.places
        folder = context.folder
        app = context.app
        runs = context.runs
        secrets = context.secrets
    }

    func list(core: Bool, form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            let config = places.config.read()
            let list = SpotList(folder: places.spots, config: config)
            return try core ? list.core(form) : list.loaded(form)
        }
    }

    func add(_ source: String, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, folder, app] in
            let answer = try await places.lock.add(SpotSource(text: source, place: folder), to: places.spots.url, isConfirmed: isConfirmed)
            await app?.spotsChanged()
            return answer
        }
    }

    func restore(isConfirmed: Bool) -> CommandAPI.Work {
        { [places, app] in
            do {
                let answer = try await places.lock.restore(to: places.spots.url, isConfirmed: isConfirmed)
                await app?.spotsChanged()
                return answer
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }

    func remove(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app, secrets] in
            try Self.refuseCore(id, .delete, in: places)
            let removed = try places.lock.remove(id, from: places.spots.url).name
            try secrets.remove { SpotID($0).isSameFolder(as: SpotID(removed)) }
            await app?.spotsChanged()
            return "Removed \(removed).\n"
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
            guard await app.choose(for: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)` that takes files. Add drop to its spot.toml.") }
            return ""
        }
    }

    func act(_ act: CardAct, _ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot \(act.rawValue) \(id)") }
        return CommandAnswer.work { [places] in
            try Self.refuseCore(id, act, in: places)
            guard await app.act(act, on: id) else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
            return ""
        }
    }

    private static func refuseCore(_ id: String, _ act: CardAct, in places: AppPlaces) throws {
        guard [.edit, .prompt, .delete].contains(act), places.spots.isCore(id: id) else { return }
        throw SpotError.failed(1, act == .delete ? SpotsFolder.unremovable(id) : SpotsFolder.uneditable(id))
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

    func run(_ id: String, _ arguments: [String], input: (@Sendable () async -> String)?, careful: Set<SpotUse>?, output: CommandOutput) -> CommandAPI.Work {
        { [places, folder, runs, caller] in
            let spots = places.spots
            let found: Spot?
            do {
                found = try spots.scan().scripts.first { $0.id == id }
            } catch {
                return CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 1)
            }
            guard var spot = found else {
                return CommandAnswer(errors: "Openspot has no spot \(id) in \(spots.url.path). Run `openspot check spots` to see each file that does not load.\n", code: 1)
            }
            if let careful { spot.uses.formIntersection(careful) }
            let handler: (name: String?, inputs: [TextBlock.Field])
            do {
                handler = try Self.handler(arguments, of: spot)
            } catch {
                return CommandAnswer(errors: SpotRuns.reason(error) + "\n", code: 2)
            }
            let text = await input?()
            let usage = caller == nil || spot.reachesAccountKey ? nil : runs?.usage
            var chosen: [String: [String: String]] = [:]
            for setting in places.config.read().settings where setting.spot == spot.id { chosen[spot.id, default: [:]][setting.key] = setting.value }
            let settings = FieldValues(of: spot, in: chosen, secrets: places.secrets.values(of: spot.id)).settings
            let run = TerminalRun(
                spot: spot, handler: handler.name, input: text, inputs: handler.inputs, settings: settings, careful: careful == nil ? nil : spot.uses,
                callers: runs?.callers, environment: places.environment, folder: folder, usage: usage
            )
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

    private static func handler(_ arguments: [String], of spot: Spot) throws -> (name: String?, inputs: [TextBlock.Field]) {
        guard let name = arguments.first else { return (nil, []) }
        let given = try Manifest.InputCheck.fields(of: Array(arguments.dropFirst()), as: .input)
        guard let action = try? spot.action(name) else { return (name, given) }
        return (name, try action.check.checked(given))
    }

    func push(_ id: String, route: String?, title: String?, replace: Bool) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("spot push \(id)") }
        return CommandAnswer.work {
            guard await app.push(id, route: route, title: title, replace: replace) else {
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
            guard await app.review(id) else { throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot or a spot of a store. Run `openspot store list` to see each one.") }
            return ""
        }
    }

    func new(_ name: String, from starter: SpotStarter) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let file = try starter.write(name: name, in: places.spots.url)
            await app?.spotsChanged()
            return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
        }
    }

    func actions(_ id: String?) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            let spots = try places.spots.scan().scripts.filter { id == nil || $0.id == id }
            if let id, spots.isEmpty {
                throw SpotError.failed(1, "Openspot has no spot \(id). Run `openspot check spots` to see each file that does not load.")
            }
            return ManifestSchema.json(spots.map(CallShape.listing(of:)))
        }
    }

    func log(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            let text = places.log.text(of: id)
            return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
        }
    }

    func stats(days: Int, spot: String?, format: Stats.Form, byVersion: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, runs] in
            let counts = await StatsLog.days(days, runs: runs, stats: places.stats)
            return try Stats(days: counts, spot: spot, byVersion: byVersion).text(format)
        }
    }
}
