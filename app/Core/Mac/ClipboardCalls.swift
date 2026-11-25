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

    func paste(opening: Bool, sending: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try Mac.part(mac, "clipboard").paste(opening: opening, sending: sending)
            return ""
        }
    }
}
