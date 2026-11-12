import AppKit
import OpenspotCore

/// The `openspot` command. It does one call, prints plain text and exits, with no window of its own.
@MainActor
enum SpotCommandLine {
    /// The time that posted key events need to leave the process. An exit before it drops them.
    private static let postPause: Duration = .milliseconds(100)

    /// Does the call: the work of the API when Core has it, or the work of the Shell, and exits.
    static func run(_ call: CommandLineCall) -> Never {
        enterBundle()
        let environment = ProcessInfo.processInfo.environment.merging(["PWD": FileManager.default.currentDirectoryPath]) { _, real in real }
        let output = CommandOutput { text, isError in (isError ? FileHandle.standardError : FileHandle.standardOutput).write(Data(text.utf8)) }
        if runsScripts(call) { TerminalStop.watch() }
        var info = stat()
        let isPiped = fstat(0, &info) == 0 && (info.st_mode & S_IFMT == S_IFIFO || info.st_mode & S_IFMT == S_IFREG)
        if let work = CommandAPI(mac: SpotMac()).work(for: call, input: { standardInput }, environment: environment, isPiped: isPiped, output: output) {
            Task {
                let answer = await work()
                output.print(answer.output)
                output.report(answer.errors)
                if call == .clipboardPaste { try? await Task.sleep(for: postPause) }
                exit(answer.code)
            }
            if needsEvents(call) {
                NSApplication.shared.setActivationPolicy(.accessory)
                NSApplication.shared.run()
            }
            dispatchMain()
        }
        switch call {
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

    /// Whether a call runs scripts, which Ctrl-C stops before the command exits with 130 (protocol: The openspot command).
    private static func runsScripts(_ call: CommandLineCall) -> Bool {
        switch call {
        case .check, .checkJSON, .spotRun: true
        default: false
        }
    }

    /// Whether a call needs the event loop of an app, for a pick or for an overlay over the screens.
    private static func needsEvents(_ call: CommandLineCall) -> Bool {
        switch call {
        case .colorPick, .folderPick, .screenShot, .screenRecordStart, .screenRecordStop, .screenRecordStatus: true
        default: false
        }
    }
}
