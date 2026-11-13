import Foundation

/// The releases of a package: the files a release names, its release log, and a new release signed by a key.
extension SpotFolder {
    /// The files of a spot folder that a release names: each one but its release log.
    public func released(in root: String) -> [File] {
        files(in: root).filter { $0.path != "\(root)/\(ReleaseLog.fileName)" }
    }

    /// The release log of its own spot folder, with no check of its files, or nil when it has none or one that does not check.
    public var releases: ReleaseLog? {
        roots.first.flatMap { text(of: ReleaseLog.fileName, in: $0) }.flatMap { try? ReleaseLog(text: $0) }
    }

    /// The release log of one of its spot folders, or nil when it has none. Throws a fault for a log that does not check, or
    /// whose last release does not name the files beside it.
    public func releaseLog(in root: String) throws -> ReleaseLog? {
        guard let text = text(of: ReleaseLog.fileName, in: root) else { return nil }
        let log = try ReleaseLog(text: text)
        guard log.names(SpotManifest(released(in: root))) else {
            throw SpotError.fault("\(root) does not match its last release, so a file changed after it was signed.")
        }
        return log
    }

    /// This spot with a release of its own spot folder signed by the key, after the releases of its log. It is the same
    /// spot when its last release names its files already, as for a forward, which keeps the first author's signature.
    public func signed(by key: AccountKey, at date: Date = Date()) throws -> SpotFolder {
        guard let root = roots.first else { return self }
        let path = "\(root)/\(ReleaseLog.fileName)"
        let current = try files.first { $0.path == path }.map { try ReleaseLog(text: $0.text ?? "") } ?? ReleaseLog(releases: [])
        let released = released(in: root)
        guard !current.names(SpotManifest(released)) else { return self }
        let readme = text(of: SpotListing.readmeName, in: root) ?? ""
        let log = try current.signing(released, readme: readme, by: key, at: date)
        return try SpotFolder(files: files.filter { $0.path != path } + [File(path: path, isExecutable: false, contents: Data(log.text.utf8))])
    }

    /// Writes the release log of its own spot folder into that folder in the spots folder, so that the next release
    /// follows it.
    public func keepReleaseLog(in folder: URL) throws {
        guard let root = roots.first, let file = files.first(where: { $0.path == "\(root)/\(ReleaseLog.fileName)" }) else { return }
        try file.contents.write(to: folder.appendingPathComponent(file.path), options: .atomic)
    }

    /// This spot as it goes out: compiled when it needs to be, signed by the key, with its release log kept in its own
    /// folder in the spots folder, so that the next release follows it.
    public func release(by key: AccountKey, keepingLogIn spots: URL) async throws -> SpotFolder {
        let built = needsCompile ? try await compiled() : self
        let signed = try built.signed(by: key)
        try signed.keepReleaseLog(in: spots)
        return signed
    }
}
