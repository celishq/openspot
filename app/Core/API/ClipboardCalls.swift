import Foundation

/// The calls of `openspot clipboard`, which reach the clipboard through the Mac. A relative path starts in the working
/// folder of the caller.
struct ClipboardCalls {
    let mac: any Mac
    let environment: [String: String]

    func copy(_ path: String?, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        let folder = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
        return CommandAnswer.work { [mac] in
            if let path {
                try mac.copy(file: URL(fileURLWithPath: path, relativeTo: folder).standardizedFileURL)
            } else {
                try mac.copy(text: await input())
            }
            return ""
        }
    }

    func read() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in mac.clipboardText() }
    }

    func paste() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try mac.paste()
            return ""
        }
    }
}
