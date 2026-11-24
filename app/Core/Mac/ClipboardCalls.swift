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

    func read(newer limit: TimeInterval, runs: SpotRuns) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let age = await runs.copyAge(), age < limit else { return "" }
            return mac?.text() ?? ""
        }
    }

    func files() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in Self.paths(mac) }
    }

    func files(newer limit: TimeInterval, runs: SpotRuns) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let age = await runs.copyAge(), age < limit else { return "" }
            return Self.paths(mac)
        }
    }

    private static func paths(_ mac: (any MacClipboard)?) -> String {
        guard case .files(let urls) = mac?.contents() else { return "" }
        return urls.map { "\($0.path)\n" }.joined()
    }

    func paste() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try Mac.part(mac, "clipboard").paste()
            return ""
        }
    }
}
