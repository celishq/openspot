import AppKit
import OpenspotCore

@MainActor
enum SpotCommandLine {
    private static let postedKeysPause: Duration = .milliseconds(100)

    static func run(_ call: CommandLineCall, words: [String]) -> Never {
        enterBundle()
        let output = CommandOutput { text, isError in (isError ? FileHandle.standardError : FileHandle.standardOutput).write(Data(text.utf8)) }
        if call.rule.flags.contains(.startsScripts), !(call.value is PlaygroundCommand) { TerminalStop.watch() }
        var info = stat()
        let isPiped = fstat(0, &info) == 0 && (info.st_mode & S_IFMT == S_IFIFO || info.st_mode & S_IFMT == S_IFREG)
        let request = CommandRequest(arguments: words, folder: FileManager.default.currentDirectoryPath, isPiped: isPiped)
        if let work = CommandAPI(mac: SpotMac().mac, places: .standard, rates: .standard).work(for: call, request: request, input: { standardInput }, output: output) {
            Task {
                let answer = await work()
                output.print(answer.output)
                output.report(answer.errors)
                if call.value as? ClipboardCall == .paste { try? await Task.sleep(for: postedKeysPause) }
                exit(answer.code)
            }
            if call.rule.flags.contains(.events) {
                NSApplication.shared.setActivationPolicy(.accessory)
                NSApplication.shared.run()
            }
            dispatchMain()
        }
        if call.value is RenderCall || call.value is PlaygroundCommand {
            let theme = ThemeFolder.standard(environment: ProcessInfo.processInfo.environment, builtIn: SpotMac().mac.theme).read()
            SpotLoadedTheme.shared.take(theme)
        }
        switch call.value {
        case SpotCall.show(let id) as SpotCall:
            SpotShowLink.send(id)
        case RenderCall.spot(let id, let size?, let path) as RenderCall:
            SpotCardPicture.run(spot: id, size: size, path: path)
        case RenderCall.spot(let id, nil, let path) as RenderCall:
            renderSheet(of: id, to: path)
        case PlaygroundCommand.open(let path) as PlaygroundCommand:
            SpotPlayground.run(path: path)
        case RenderCall.sheet(let path, let view) as RenderCall:
            SpotSheetPicture.run(text: standardInput, path: path, view: view)
        case RenderCall.card(let size, let path) as RenderCall:
            SpotCardPicture.run(text: standardInput, size: size, path: path)
        case RenderCall.panel(let path) as RenderCall:
            SpotPanelPicture.run(path: path)
        case RenderCall.store(let path) as RenderCall:
            SpotStorePicture.run(path: path)
        case HelperCall.capability(SpotTranslation.capability.name) as HelperCall:
            SpotTranslation.serve()
        case HelperCall.capability(SpotRecording.capability.name) as HelperCall:
            SpotRecording.serve()
        case HelperCall.glyphs(let side, let fontSize, let path) as HelperCall:
            let glyphs = standardInput.split(separator: "\n").map(String.init)
            exit(SpotGlyphBook.write(GlyphBook(glyphs: glyphs, side: side, fontSize: fontSize), to: path) ? 0 : 1)
        default:
            FileHandle.standardError.write(Data("openspot cannot do this: \(words.joined(separator: " "))\n\n\(CommandLineCall.usage)".utf8))
            exit(2)
        }
    }

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

    private static func renderSheet(of id: String, to path: String) -> Never {
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        var loaded = false
        Task {
            await model.reload()
            loaded = true
        }
        while !loaded { RunLoop.main.run(mode: .default, before: .distantFuture) }
        guard let spot = model.entries.first(where: { $0.id == id })?.spot else {
            FileHandle.standardError.write(Data("Openspot has no spot \(id). Run `openspot check spots` to see each file that does not load.\n".utf8))
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
        SpotSheetPicture.run(text: text, path: path, view: spot.view, spot: spot)
    }
}
