@testable import OpenspotCore

extension SpotLock.Entry {
    static func added(_ name: String, from source: String? = nil, key: String? = nil, isShipped: Bool? = nil) -> SpotLock.Entry {
        SpotLock.Entry(source: source ?? "https://example.com/\(name).git", commit: nil, paths: ["\(name).spot"], hash: nil, uses: [], key: key, isShipped: isShipped)
    }
}

extension Trust {
    static func restricting(_ name: String) -> Trust {
        Trust(entries: [.added(name)])
    }
}
