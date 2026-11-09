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
        case .helper(let name):
            run(.unknown("helper \(name)"))
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

    /// Reports the faults of a plugins folder, or of the standard one, and exits with 1 when there are any.
    private static func check(_ path: String?) -> Never {
        let folder = path.map { PluginFolder(url: URL(fileURLWithPath: $0, isDirectory: true)) } ?? .standard()
        Task {
            let faults = await PluginCheck(folder: folder).faults()
            faults.forEach { print($0) }
            print(faults.isEmpty ? "No faults in \(folder.url.path)." : "\(faults.count) faults in \(folder.url.path).")
            exit(faults.isEmpty ? 0 : 1)
        }
        dispatchMain()
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

    /// Prints what the work returns and exits. A failure goes to stderr, with exit code 1.
    private static func finish(_ work: @escaping @Sendable () async throws -> String) -> Never {
        Task {
            do {
                print(try await work(), terminator: "")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("\((error as? PluginError)?.reason ?? error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }
}
