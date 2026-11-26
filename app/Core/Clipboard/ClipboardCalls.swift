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

    func blocks(images: URL, within limit: TimeInterval? = nil, runs: SpotRuns? = nil) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            if let limit, let runs, await !runs.isCopy(within: limit) { return "" }
            guard let mac, let value = try? Clipboard(board: mac).value(count: mac.count(), images: images)?.whole(from: mac),
                  value.texts.allSatisfy({ $0.utf8.count <= Timeline.cloneLimit }) else { return "" }
            var fields = value.kind.fields(value.texts)
            if value.kind == .file, let title = value.title { fields.append(.init(key: "title", value: title)) }
            return TextBlock(fields: fields).text
        }
    }

    func paste() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try Mac.part(mac, "clipboard").paste()
            return ""
        }
    }
}
