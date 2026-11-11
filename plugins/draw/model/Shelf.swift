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

    /// Writes a new empty board and returns its file.
    func make() throws -> URL {
        let file = folder.appendingPathComponent(UUID().uuidString.lowercased()).appendingPathExtension("json")
        try Board().save(to: file)
        return file
    }
}
