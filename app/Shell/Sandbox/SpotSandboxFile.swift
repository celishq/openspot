import Foundation

/// The file of the sandbox window, which it reads and writes away from the main thread. It tells its own writes from a
/// change that another app made.
actor SpotSandboxFile {
    let url: URL
    private var known: Date?
    private var hasLooked = false

    init(url: URL) {
        self.url = url
    }

    func write(_ text: String) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
        known = modified
    }

    /// The text of the file when it changed since the last look, or nil when it did not. The first look always reads it.
    func change() -> String? {
        let date = modified
        guard !hasLooked || date != known else { return nil }
        hasLooked = true
        known = date
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private var modified: Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
