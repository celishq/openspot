import AppKit
import OpenspotCore

/// The `openspot` command. It does one call, prints plain text and exits, with no window of its own.
@MainActor
enum SpotCommandLine {
    /// Does the call: the work of the API when Core has it, or the work of the Shell, and exits.
    static func run(_ call: CommandLineCall) -> Never {
        enterBundle()
        if let work = CommandAPI(host: SpotCommandHost()).work(for: call, input: { standardInput }, environment: ProcessInfo.processInfo.environment) {
            Task {
                let answer = await work()
                FileHandle.standardOutput.write(Data(answer.output.utf8))
                FileHandle.standardError.write(Data(answer.errors.utf8))
                exit(answer.code)
            }
            dispatchMain()
        }
        switch call {
        case .colorPick:
            SpotColorPick.run()
        case .folderPick:
            SpotFolderPick.run()
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
        case .spotRun(let id, let arguments):
            spotRun(id, arguments)
        case .spotShow(let id):
            SpotShowLink.send(id)
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
        case .translate(let from, let to):
            let text = standardInput
            finish { try SpotTranslation.call(text: text, from: from, to: to) }
        case .helper(SpotTranslation.capability.name):
            SpotTranslation.serve()
        case .helper(SpotRecording.capability.name):
            SpotRecording.serve()
        case .helper(CalcRateCache.capability.name):
            CalcRateCache.serve()
        case .helper(let name):
            run(.unknown("helper \(name)"))
        case .glyphBook(let side, let fontSize, let path):
            let glyphs = standardInput.split(separator: "\n").map(String.init)
            exit(SpotGlyphBook.write(GlyphBook(glyphs: glyphs, side: side, fontSize: fontSize), to: path) ? 0 : 1)
        case .translateLanguages:
            finish { await SpotTranslation.languages() }
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
        default:
            preconditionFailure("CommandAPI answers \(call).")
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

    nonisolated private static var standardInput: String {
        String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    }

    /// Reports the faults of a plugins folder, or of the standard one, in lines or as JSON, and exits with 1 when there are
    /// any.
    private static func check(_ path: String?, json: Bool = false) -> Never {
        let folder = path.map { SpotFolder(url: URL(fileURLWithPath: $0, isDirectory: true)) } ?? .standard()
        Task {
            let findings = await SpotCheck(folder: folder).findings()
            if json {
                print(SpotCheck.json(findings), terminator: "")
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
        let folder = SpotFolder.standard()
        guard let spot = try folder.scan().scripts.first(where: { $0.id == id }) else {
            throw SpotError.fault("Openspot has no spot \(id) in \(folder.url.path). Run `openspot check` to see each file that does not load.")
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
        guard let spot = model.entries.first(where: { $0.id == id })?.spot else {
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
        guard !SpotOutput(text: text).parts.isEmpty else {
            FileHandle.standardError.write(Data("\(spot.name) shows rows, and `openspot render` draws only a sheet of parts. Run `openspot spot run \(id)` to see its rows, or add `--card wide` to draw its card.\n".utf8))
            exit(1)
        }
        SpotSheetPicture.run(text: text, path: path, view: spot.view, spot: spot)
    }

    /// Prints what the work returns on the main thread and exits. A failure goes to stderr, with exit code 1.
    private static func answer(_ work: () throws -> String) -> Never {
        do {
            print(try work(), terminator: "")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\((error as? SpotError)?.reason ?? error.localizedDescription)\n".utf8))
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
                if case SpotError.failedWithFix(_, _, let link) = error { print("link=\(link.absoluteString)") }
                FileHandle.standardError.write(Data("\((error as? SpotError)?.reason ?? error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }
}
