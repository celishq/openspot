import AppKit
import OpenspotCore

/// The `openspot` command. It does one call, prints plain text and exits, with no window of its own.
@MainActor
enum SpotCommandLine {
    static func run(_ call: CommandLineCall) -> Never {
        enterBundle()
        switch call {
        case .help:
            print(CommandLineCall.usage, terminator: "")
            exit(0)
        case .unknown(let words):
            FileHandle.standardError.write(Data("openspot cannot do this: \(words)\n\n\(CommandLineCall.usage)".utf8))
            exit(2)
        case .catalog:
            print(PartCatalog.text, terminator: "")
            exit(0)
        case .colorPick:
            SpotColorPick.run()
        case .folderPick:
            SpotFolderPick.run()
        case .settingGet(let spot, let key):
            answer { ConfigFile.standard().read().setting(key, of: spot).map { $0 + "\n" } ?? "" }
        case .settingSet(let spot, let key, let value):
            answer {
                try ConfigFile.standard().set(setting: key, of: spot, to: value)
                return ""
            }
        case .refused(let line):
            FileHandle.standardError.write(Data("\(line)\n".utf8))
            exit(1)
        case .clipboardCopy(let path?):
            SpotClipboard.copy(path)
        case .clipboardCopy(nil):
            SpotClipboard.copy(text: standardInput)
        case .clipboardPaste:
            SpotClipboard.paste()
        case .check(let path):
            check(path)
        case .checkJSON(let path):
            check(path, json: true)
        case .guide:
            answer {
                guard let guide = Bundle.main.url(forResource: "GUIDE", withExtension: "md") else { throw PluginError.fault("This copy of Openspot has no guide. Install Openspot again.") }
                return try String(contentsOf: guide, encoding: .utf8)
            }
        case .spotNew(let name, let starter):
            answer {
                let file = try starter.write(name: name, in: PluginFolder.standard().url)
                return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
            }
        case .spotRun(let id, let arguments):
            spotRun(id, arguments)
        case .spotShow(let id):
            SpotShowLink.send(id)
        case .spotLog(let id):
            answer {
                let text = SpotFiles.standard.log.text(of: id)
                return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
            }
        case .renderSpot(let id, let size?, let path):
            SpotCardPicture.run(spot: id, size: size, path: path)
        case .renderSpot(let id, nil, let path):
            renderSheet(of: id, to: path)
        case .sandbox(let path):
            SpotSandbox.run(path: path)
        case .render(let path, let view):
            SpotSheetPicture.run(text: standardInput, path: path, view: view)
        case .renderCard(let size, let path):
            SpotCardPicture.run(text: standardInput, size: size, path: path)
        case .checkSheet:
            checkSheet()
        case .translate(let from, let to):
            let text = standardInput
            finish { try SpotTranslation.call(text: text, from: from, to: to) }
        case .helper(SpotTranslation.capability.name):
            SpotTranslation.serve()
        case .helper(SpotRecording.capability.name):
            SpotRecording.serve()
        case .helper(let name):
            run(.unknown("helper \(name)"))
        case .glyphBook(let side, let fontSize, let path):
            let glyphs = standardInput.split(separator: "\n").map(String.init)
            exit(SpotGlyphBook.write(GlyphBook(glyphs: glyphs, side: side, fontSize: fontSize), to: path) ? 0 : 1)
        case .translateLanguages:
            finish { await SpotTranslation.languages() }
        case .emoji(let tone):
            finish { try EmojiCatalog().rows(tone: tone) }
        case .symbols:
            finish { try SymbolCatalog().rows() }
        case .windowFrame:
            answer { try SpotWindow.front().frameText }
        case .windowMove(let move):
            answer { try SpotWindow.front().move(move); return "" }
        case .screenSources:
            answer { SpotScreen.sources() }
        case .screenShot(let capture):
            SpotScreen.run { try await SpotScreen.shot(capture) }
        case .screenRecordStart(let capture):
            SpotScreen.run { try await SpotRecording.start(capture) }
        case .screenRecordStop:
            SpotScreen.run { try SpotRecording.stop() }
        case .screenRecordStatus:
            SpotScreen.run { try SpotRecording.status() }
        case .calendarEvents(let days, let hidden):
            finish { try await SpotAgendaStore.agenda().events(days: days, hiding: hidden) }
        case .calendarCalendars:
            finish { try await SpotAgendaStore.agenda().calendars() }
        case .remindersDue(let days, let hidden):
            finish { try await SpotAgendaStore.agenda().due(days: days, hiding: hidden) }
        case .remindersLists:
            finish { try await SpotAgendaStore.agenda().lists() }
        case .calendarAdd(let words, let isDry):
            finish { try await SpotAgendaStore.agenda().addEvent(words, isDry: isDry) }
        case .remindersAdd(let words, let isDry):
            finish { try await SpotAgendaStore.agenda().addReminder(words, isDry: isDry) }
        case .calendarShow(let id):
            finish { try SpotCalendarApp.show(try await SpotAgendaStore.agenda().day(of: id)) }
        case .remindersDone(let id, let isDone):
            finish { try await SpotAgendaStore.agenda().done(id, isDone) }
        case .remindersShow(let id):
            finish {
                let link = try await SpotAgendaStore.agenda().link(of: id)
                guard NSWorkspace.shared.open(link) else { throw PluginError.failed(1, "Openspot cannot open Reminders, so it cannot show \(id).") }
                return ""
            }
        }
    }

    /// Starts this command again from the program inside the app when a link started it, such as `Helpers/openspot`, so
    /// that it finds the guide and the core spots of the app, and the folder of a Debug build.
    private static func enterBundle() {
        guard Bundle.main.bundleIdentifier == nil else { return }
        var size = UInt32(PATH_MAX)
        var path = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&path, &size) == 0, let real = realpath(path, nil) else { return }
        defer { free(real) }
        guard strcmp(real, path) != 0 else { return }
        execv(real, CommandLine.unsafeArgv)
    }

    private static var standardInput: String {
        String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    }

    /// Reports the faults of a plugins folder, or of the standard one, in lines or as JSON, and exits with 1 when there are
    /// any.
    private static func check(_ path: String?, json: Bool = false) -> Never {
        let folder = path.map { PluginFolder(url: URL(fileURLWithPath: $0, isDirectory: true)) } ?? .standard()
        Task {
            let findings = await PluginCheck(folder: folder).findings()
            if json {
                print(PluginCheck.json(findings), terminator: "")
            } else {
                findings.forEach { print($0.line) }
                print(findings.isEmpty ? "No faults in \(folder.url.path)." : "\(findings.count) faults in \(folder.url.path).")
            }
            exit(findings.isEmpty ? 0 : 1)
        }
        dispatchMain()
    }

    /// The installed spot with this ID, which a scan of the standard folder finds.
    private static func spot(_ id: String) throws -> Spot {
        let folder = PluginFolder.standard()
        guard let spot = try folder.scan().scripts.first(where: { $0.id == id }) else {
            throw PluginError.fault("Openspot has no spot \(id) in \(folder.url.path). Run `openspot check` to see each file that does not load.")
        }
        return spot
    }

    /// Makes one call of a spot, prints each frame with a `---` line between frames and its stderr as it was, and exits with
    /// the code of the script. Stdin goes to the script when it is a file or a pipe.
    private static func spotRun(_ id: String, _ arguments: [String]) -> Never {
        var info = stat()
        let input = fstat(0, &info) == 0 && (info.st_mode & S_IFMT == S_IFIFO || info.st_mode & S_IFMT == S_IFREG) ? standardInput : nil
        Task {
            do {
                var first = true
                let end = await TerminalRun(spot: try spot(id), arguments: arguments, input: input).start { text in
                    FileHandle.standardOutput.write(Data(((first ? "" : "---\n") + text).utf8))
                    first = false
                }
                FileHandle.standardError.write(Data(end.errors.utf8))
                exit(end.code)
            } catch {
                FileHandle.standardError.write(Data("\(SpotsModel.reason(error))\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }

    /// Draws the sheet of a spot that the panel shows, such as an installed spot or one that ships with the app, from its
    /// read, with its view. It waits for the read on the main thread, which the window of the picture needs.
    private static func renderSheet(of id: String, to path: String) -> Never {
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        model.reload()
        guard let spot = model.entries.first(where: { $0.id == id })?.command else {
            FileHandle.standardError.write(Data("Openspot has no spot \(id). Run `openspot check` to see each file that does not load.\n".utf8))
            exit(1)
        }
        var answer: Result<String, Error>?
        Task {
            do { answer = .success(try await SpotRuns().answer(of: spot, .read, limit: 10)) } catch { answer = .failure(error) }
        }
        while answer == nil { RunLoop.main.run(mode: .default, before: .distantFuture) }
        guard case .success(let text)? = answer, !text.isEmpty else {
            let reason = if case .failure(let error)? = answer { SpotsModel.reason(error) } else { "\(spot.name) printed no sheet." }
            FileHandle.standardError.write(Data("\(reason)\n".utf8))
            exit(1)
        }
        guard !PluginOutput(text: text).parts.isEmpty else {
            FileHandle.standardError.write(Data("\(spot.name) shows rows, and `openspot render` draws only a sheet of parts. Run `openspot spot run \(id)` to see its rows, or add `--card wide` to draw its card.\n".utf8))
            exit(1)
        }
        SpotSheetPicture.run(text: text, path: path, view: spot.view, spot: spot)
    }

    /// Reports the faults of a sheet on standard input, and exits with 1 when there are any.
    private static func checkSheet() -> Never {
        let faults = PluginOutput(text: standardInput).sheetFaults
        faults.forEach { print($0) }
        print(faults.isEmpty ? "No faults." : "\(faults.count) faults.")
        exit(faults.isEmpty ? 0 : 1)
    }

    /// Prints what the work returns on the main thread and exits. A failure goes to stderr, with exit code 1.
    private static func answer(_ work: () throws -> String) -> Never {
        do {
            print(try work(), terminator: "")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\((error as? PluginError)?.reason ?? error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    /// Prints what the work returns and exits. A failure goes to stderr, with exit code 1, and the link to its fix on stdout.
    private static func finish(_ work: @escaping @Sendable () async throws -> String) -> Never {
        Task {
            do {
                print(try await work(), terminator: "")
                exit(0)
            } catch {
                if case PluginError.failedWithFix(_, _, let link) = error { print("link=\(link.absoluteString)") }
                FileHandle.standardError.write(Data("\((error as? PluginError)?.reason ?? error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }
}
