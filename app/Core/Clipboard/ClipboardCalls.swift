import Foundation

struct ClipboardCalls {
    let mac: (any MacClipboard)?
    let folder: URL

    func copy(_ path: String?, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, folder] in
            let clipboard = try Mac.part(mac, "clipboard")
            if let path {
                try clipboard.copy(file: URL(fileURLWithPath: path, relativeTo: folder).standardizedFileURL)
            } else {
                try clipboard.copy(text: await input())
            }
            return ""
        }
    }

    func read() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in mac?.text() ?? "" }
    }

    func read(within limit: TimeInterval, runs: SpotRuns) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard await runs.isCopy(within: limit) else { return "" }
            return mac?.text() ?? ""
        }
    }

    func paste() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try Mac.part(mac, "clipboard").paste()
            return ""
        }
    }
}
