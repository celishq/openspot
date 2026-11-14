import AppKit
import OpenspotCore

@MainActor
enum SpotShowLink {
    nonisolated private static let ask = Notification.Name("dev.openspot.show")
    nonisolated private static let answer = Notification.Name("dev.openspot.shown")
    private static let firstWait: TimeInterval = 1
    private static let launchWait: TimeInterval = 15
    private static let askPause: TimeInterval = 0.5

    static var config: String {
        AppPlaces.standard.log.folder.deletingLastPathComponent().standardizedFileURL.path
    }

    static func listen(reveal: @escaping @MainActor (String) -> Bool) -> NSObjectProtocol {
        let config = config
        let center = DistributedNotificationCenter.default()
        return center.addObserver(forName: ask, object: nil, queue: .main) { note in
            guard let info = note.userInfo as? [String: String], info["config"] == config, let spot = info["spot"], let token = info["token"] else { return }
            let found = MainActor.assumeIsolated { reveal(spot) }
            center.postNotificationName(answer, object: nil, userInfo: ["token": token, "found": String(found)], deliverImmediately: true)
        }
    }

    static func send(_ id: String) -> Never {
        let center = DistributedNotificationCenter.default()
        let token = UUID().uuidString
        nonisolated(unsafe) var found: Bool?
        let observer = center.addObserver(forName: answer, object: nil, queue: .main) { note in
            guard let info = note.userInfo as? [String: String], info["token"] == token else { return }
            found = info["found"] == "true"
        }
        let info = ["spot": id, "config": config, "token": token]
        func askUntil(_ end: Date) {
            while found == nil, Date() < end {
                center.postNotificationName(ask, object: nil, userInfo: info, deliverImmediately: true)
                RunLoop.main.run(until: min(end, Date().addingTimeInterval(askPause)))
            }
        }
        askUntil(Date().addingTimeInterval(firstWait))
        if found == nil {
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
            askUntil(Date().addingTimeInterval(launchWait))
        }
        center.removeObserver(observer)
        switch found {
        case true?:
            print("Openspot shows \(id).")
            exit(0)
        case false?:
            FileHandle.standardError.write(Data("Openspot has no spot \(id). Run `openspot check` to see each file that does not load.\n".utf8))
            exit(1)
        case nil:
            FileHandle.standardError.write(Data("Openspot did not answer. Open Openspot, then run this again.\n".utf8))
            exit(1)
        }
    }
}
