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

    func blocks(images: URL, clock: RunClock, within limit: TimeInterval? = nil, runs: SpotRuns? = nil) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            if let limit, let runs, await !runs.isCopy(within: limit) { return "" }
            guard let mac else { return "" }
            switch ClipboardContents(of: mac) {
            case .none:
                return ""
            case .files(let urls):
                return TextBlock(fields: AttachmentValue.Kind.file.fields(urls.map(\.path))).text
            case .text:
                let text = autoreleasepool { mac.text() }
                guard text.utf8.count <= Timeline.entryLimit, text.contains(where: { !$0.isWhitespace }) else { return "" }
                let value = TextBlock(fields: Clipboard.link(in: text).map { AttachmentValue.Kind.url.fields([$0]) } ?? AttachmentValue.Kind.text.fields([text]))
                let peek = text.count > HexColor.cssLimit ? [] : HexColor(css: text)?.peek ?? []
                return ([value] + peek).map(\.text).joined(separator: "\n")
            case .image(let kind):
                guard let data = autoreleasepool(invoking: { mac.image() }) else { return "" }
                let folder = images.appendingPathComponent("blocks", isDirectory: true)
                let hourAgo = clock.now().addingTimeInterval(-3_600)
                for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                    if let made = try? old.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, made < hourAgo { try? FileManager.default.removeItem(at: old) }
                }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent("Copied image \(mac.count()) \(UUID().uuidString.prefix(8)).\(kind)")
                try data.write(to: file, options: .atomic)
                return TextBlock(fields: AttachmentValue.Kind.file.fields([file.path]) + [.init(key: "title", value: "Copied image")]).text
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
