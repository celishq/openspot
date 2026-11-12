import Foundation

/// The boards in one folder, as the Draw spot and the board window list them: newest first, each with its title and its
/// picture.
struct Shelf {
    struct Entry: Identifiable, Equatable {
        let file: URL
        let title: String
        let edited: Date

        var id: URL { file }

        /// The picture that the board saves beside itself.
        var picture: URL { file.deletingPathExtension().appendingPathExtension("png") }
    }

    let folder: URL

    var entries: [Entry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "json" }.map { file in
            let edited = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return Entry(file: file, title: (try? Board.load(from: file).title) ?? "Untitled board", edited: edited)
        }.sorted { $0.edited > $1.edited }
    }

    /// Gives a board a new title. A title of only spaces changes nothing.
    func rename(_ file: URL, to title: String) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var board = try Board.load(from: file)
        board.title = title
        try board.save(to: file)
    }

    /// Hands a board, its picture and its folder of images to `trash`, such as the Trash of the Mac.
    func discard(_ file: URL, trash: (URL) throws -> Void) throws {
        let base = file.deletingPathExtension()
        for part in [file, base.appendingPathExtension("png"), base.appendingPathExtension("assets")] where FileManager.default.fileExists(atPath: part.path) {
            try trash(part)
        }
    }

    /// Writes a new empty board and returns its file.
    func make() throws -> URL {
        let file = folder.appendingPathComponent(UUID().uuidString.lowercased()).appendingPathExtension("json")
        try Board().save(to: file)
        return file
    }
}
