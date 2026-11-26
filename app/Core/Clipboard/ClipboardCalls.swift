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
            guard let mac, mac.types().isDisjoint(with: ClipboardContents.unkeptTypes) else { return "" }
            switch ClipboardContents(of: mac) {
            case .none:
                return ""
            case .files(let urls):
                return TextBlock(fields: urls.map { .init(key: "file", value: $0.path) }).text
            case .text:
                let text = autoreleasepool { mac.text() }
                guard text.contains(where: { !$0.isWhitespace }) else { return "" }
                let line = text.trimmingCharacters(in: .newlines)
                let isLink = (line.hasPrefix("https://") || line.hasPrefix("http://")) && !line.contains(where: \.isWhitespace)
                return TextBlock(fields: [isLink ? .init(key: "url", value: line) : .init(key: "text", value: text)]).text
            case .image(let kind):
                guard let data = autoreleasepool(invoking: { mac.image() }) else { return "" }
                let folder = images.appendingPathComponent("blocks", isDirectory: true)
                let hourAgo = Date().addingTimeInterval(-3_600)
                for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                    if let made = try? old.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, made < hourAgo { try? FileManager.default.removeItem(at: old) }
                }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent("Copied image \(mac.count()) \(UUID().uuidString.prefix(8)).\(kind)")
                try data.write(to: file, options: .atomic)
                return TextBlock(fields: [.init(key: "picture", value: file.path), .init(key: "title", value: "Copied image")]).text
            }
        }
    }

    func paste() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try Mac.part(mac, "clipboard").paste()
            return ""
        }
    }
}
