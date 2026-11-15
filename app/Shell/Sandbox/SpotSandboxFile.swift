import Foundation

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
