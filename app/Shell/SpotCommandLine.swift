import AppKit
import OpenspotCore

/// The `openspot` command. It does one call, prints plain text and exits, with no window of its own.
@MainActor
enum SpotCommandLine {
    static func run(_ call: CommandLineCall) -> Never {
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
        case .check(let path):
            check(path)
        case .checkSheet:
            checkSheet()
        case .translate(let from, let to):
            finish { try await SpotTranslation.answer(to: Self.standardInput, from: from, to: to) }
        case .translateLanguages:
            finish { await SpotTranslation.languages() }
        }
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

    /// Prints what the work returns and exits. A failure goes to stderr, with exit code 1.
    private static func finish(_ work: @escaping @Sendable () async throws -> String) -> Never {
        Task {
            do {
                print(try await work(), terminator: "")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }
}
