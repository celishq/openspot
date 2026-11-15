import Foundation

struct ClipboardCalls {
    let mac: any Mac
    let folder: URL

    func copy(_ path: String?, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, folder] in
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
