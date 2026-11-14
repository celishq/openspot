import Foundation

extension SpotPackage {
    public func released(in root: String) -> [File] {
        files(in: root).filter { $0.path != "\(root)/\(ReleaseLog.fileName)" }
    }

    public var releases: ReleaseLog? {
        roots.first.flatMap { text(of: ReleaseLog.fileName, in: $0) }.flatMap { try? ReleaseLog(text: $0) }
    }

    public func releaseLog(in root: String) throws -> ReleaseLog? {
        guard let text = text(of: ReleaseLog.fileName, in: root) else { return nil }
        let log = try ReleaseLog(text: text)
        guard log.names(SpotManifest(released(in: root))) else {
            throw SpotError.fault("\(root) does not match its last release, so a file changed after it was signed.")
        }
        return log
    }

    public func signed(by key: AccountKey, at date: Date = Date()) throws -> SpotPackage {
        guard let root = roots.first else { return self }
        let path = "\(root)/\(ReleaseLog.fileName)"
        let current = try files.first { $0.path == path }.map { try ReleaseLog(text: $0.text ?? "") } ?? ReleaseLog(releases: [])
        let released = released(in: root)
        guard !current.names(SpotManifest(released)) else { return self }
        let readme = text(of: SpotListing.readmeName, in: root) ?? ""
        let log = try current.signing(released, readme: readme, by: key, at: date)
        return try SpotPackage(files: files.filter { $0.path != path } + [File(path: path, isExecutable: false, contents: Data(log.text.utf8))])
    }

    public func keepReleaseLog(in folder: URL) throws {
        guard let root = roots.first, let file = files.first(where: { $0.path == "\(root)/\(ReleaseLog.fileName)" }) else { return }
        try file.contents.write(to: folder.appendingPathComponent(file.path), options: .atomic)
    }

    public func release(by key: AccountKey, keepingLogIn spots: URL) async throws -> SpotPackage {
        let built = needsCompile ? try await compiled() : self
        let signed = try built.signed(by: key)
        try signed.keepReleaseLog(in: spots)
        return signed
    }
}
