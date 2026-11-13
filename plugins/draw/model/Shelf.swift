import Foundation

/// The boards in a folder and in the folders inside it, as the Draw spot and the board window list them: as a tree of
/// folders and boards, or as every board, newest first, each with its title and its picture.
struct Shelf {
    struct Entry: Identifiable, Equatable {
        let file: URL
        let title: String
        let edited: Date

        var id: URL { file }

        /// The picture that the board saves beside itself.
        var picture: URL { file.deletingPathExtension().appendingPathExtension("png") }
    }

    /// One place in the tree: a folder with what it holds, or a board.
    struct Node: Identifiable, Equatable {
        let url: URL
        let title: String
        let edited: Date
        let isFolder: Bool
        var children: [Node] = []

        var id: URL { url }

        /// The picture of a board.
        var picture: URL { url.deletingPathExtension().appendingPathExtension("png") }
    }

    let folder: URL

    /// The folders and boards at the top, in the order a person set by dragging, with what is new first. With no order
    /// set, folders come first by name, then boards newest first.
    var tree: [Node] {
        nodes(in: folder)
    }

    /// Every board in every folder, newest first.
    var entries: [Entry] {
        boards(in: folder).sorted { $0.edited > $1.edited }
    }

    /// The boards whose title holds the words, ignoring case and accents. Empty words match each board.
    func entries(matching words: String) -> [Entry] {
        let words = words.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return entries }
        return entries.filter { $0.title.range(of: words, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The folder where a new board or folder goes: the picked folder, the folder of the picked board, or the top.
    func place(for pick: URL?) -> URL {
        guard let pick else { return folder }
        return Self.isFolder(pick) ? pick : pick.deletingLastPathComponent()
    }

    /// Gives a board a new title, or a folder a new name, and returns where it now is. A name of only spaces changes
    /// nothing, and a slash or a colon in a folder's name becomes a dash.
    @discardableResult
    func rename(_ url: URL, to title: String) throws -> URL {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return url }
        if Self.isFolder(url) {
            let name = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let moved = url.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
            guard moved.standardizedFileURL != url.standardizedFileURL else { return url }
            try FileManager.default.moveItem(at: url, to: moved)
            let parent = url.deletingLastPathComponent()
            writeOrder(order(of: parent).map { $0 == url.lastPathComponent ? name : $0 }, in: parent)
            return moved
        }
        var board = try Board.load(from: url)
        board.title = title
        try board.save(to: url)
        return url
    }

    /// Hands a board with its picture and its images, or a whole folder, to `trash`, such as the Trash of the Mac.
    func discard(_ url: URL, trash: (URL) throws -> Void) throws {
        if Self.isFolder(url) {
            try trash(url)
            return
        }
        let base = url.deletingPathExtension()
        for part in [url, base.appendingPathExtension("png"), base.appendingPathExtension("assets")] where FileManager.default.fileExists(atPath: part.path) {
            try trash(part)
        }
    }

    /// Writes a new empty board in a folder, or at the top, and returns its file.
    @discardableResult
    func make(in place: URL?) throws -> URL {
        let file = (place ?? folder).appendingPathComponent(UUID().uuidString.lowercased()).appendingPathExtension("json")
        try Board().save(to: file)
        return file
    }

    /// Makes a new folder with a free name, such as New Folder 2, in a folder or at the top.
    func makeFolder(in place: URL?) throws -> URL {
        let parent = place ?? folder
        let made = parent.appendingPathComponent(free("New Folder", in: parent), isDirectory: true)
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: false)
        return made
    }

    /// Moves a board with its picture and its images, or a folder, into a folder, and returns where it now is. A folder
    /// never moves into itself, and a folder whose name is taken there takes a free one.
    @discardableResult
    func move(_ url: URL, into target: URL) throws -> URL {
        let target = URL(fileURLWithPath: target.standardizedFileURL.path, isDirectory: true)
        if url.deletingLastPathComponent().standardizedFileURL.path == target.path { return url }
        if Self.isFolder(url) {
            guard !(target.path + "/").hasPrefix(url.standardizedFileURL.path + "/") else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            let name = free(url.lastPathComponent, in: target)
            let moved = target.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        }
        let base = url.deletingPathExtension()
        let moved = target.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: moved)
        for ending in ["png", "assets"] where FileManager.default.fileExists(atPath: base.appendingPathExtension(ending).path) {
            try FileManager.default.moveItem(at: base.appendingPathExtension(ending), to: moved.deletingPathExtension().appendingPathExtension(ending))
        }
        return moved
    }

    /// Moves boards and folders into a folder and puts them, in their order, before `before`, or at the end. Returns
    /// where each now is.
    @discardableResult
    func arrange(_ urls: [URL], into target: URL, before: URL?) throws -> [URL] {
        let moved = try urls.map { try move($0, into: target) }
        let names = moved.map(\.lastPathComponent)
        var order = nodes(in: target).map(\.url.lastPathComponent).filter { !names.contains($0) }
        let place = before.flatMap { order.firstIndex(of: $0.lastPathComponent) } ?? order.count
        order.insert(contentsOf: names, at: place)
        writeOrder(order, in: target)
        return moved
    }

    /// The names in a folder in the order a person set, kept in a hidden file there.
    private func order(of place: URL) -> [String] {
        guard let data = try? Data(contentsOf: place.appendingPathComponent(".order")) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func writeOrder(_ names: [String], in place: URL) {
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? data.write(to: place.appendingPathComponent(".order"), options: .atomic)
    }

    /// A name for a folder that nothing in `parent` takes yet: the name itself, or with 2, 3 and on after it.
    private func free(_ name: String, in parent: URL) -> String {
        let stem = name.replacingOccurrences(of: #" \d+$"#, with: "", options: .regularExpression)
        var name = name
        var count = 2
        while FileManager.default.fileExists(atPath: parent.appendingPathComponent(name).path) {
            name = "\(stem) \(count)"
            count += 1
        }
        return name
    }

    // MARK: Reading

    /// Whether a place is a folder of boards, not a board's own folder of images.
    static func isFolder(_ url: URL) -> Bool {
        var folder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &folder) && folder.boolValue && url.pathExtension != "assets"
    }

    private func contents(of place: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: place, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return items.filter { $0.pathExtension == "json" || Self.isFolder($0) }
    }

    private static func edited(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func nodes(in place: URL) -> [Node] {
        let items = contents(of: place)
        let folders = items.filter(Self.isFolder).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Node(url: $0, title: $0.lastPathComponent, edited: Self.edited($0), isFolder: true, children: nodes(in: $0)) }
        let boards = items.filter { !Self.isFolder($0) }
            .map { Node(url: $0, title: (try? Board.load(from: $0).title) ?? "Untitled board", edited: Self.edited($0), isFolder: false) }
            .sorted { $0.edited > $1.edited }
        let natural = folders + boards
        let order = order(of: place)
        guard !order.isEmpty else { return natural }
        let set = natural.filter { order.contains($0.url.lastPathComponent) }
            .sorted { order.firstIndex(of: $0.url.lastPathComponent)! < order.firstIndex(of: $1.url.lastPathComponent)! }
        return natural.filter { !order.contains($0.url.lastPathComponent) } + set
    }

    private func boards(in place: URL) -> [Entry] {
        contents(of: place).flatMap { item -> [Entry] in
            if Self.isFolder(item) { return boards(in: item) }
            return [Entry(file: item, title: (try? Board.load(from: item).title) ?? "Untitled board", edited: Self.edited(item))]
        }
    }
}
