import Foundation

@MainActor
public final class PlaygroundPanel {
    public let model: SpotsModel
    public private(set) var file: URL?
    private let spots: URL
    private let config: URL

    public init(host: SpotsHost, scratch: URL, defaults: UserDefaults) {
        spots = scratch.appendingPathComponent("spots", isDirectory: true)
        config = scratch.appendingPathComponent("config", isDirectory: true)
        let core = scratch.appendingPathComponent("core", isDirectory: true)
        for folder in [spots, config, core] {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": config.path, "OPENSPOT_CORE": core.path],
            home: scratch,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns())
    }

    @discardableResult
    public func place(file: URL?, text: String, spots real: URL? = nil) throws -> String {
        let (source, id) = SheetSandbox.place(of: file, text: text, spots: real ?? spots, scratch: spots)
        let target = SpotID(id).file(in: spots, extension: source.pathExtension)
        let manager = FileManager.default
        for old in (try? manager.contentsOfDirectory(at: spots, includingPropertiesForKeys: nil)) ?? [] {
            try? manager.removeItem(at: old)
        }
        if let file, file.deletingLastPathComponent().pathExtension == SpotPackage.fileExtension {
            try manager.copyItem(at: file.deletingLastPathComponent(), to: target.deletingLastPathComponent())
        }
        try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.removeItem(at: target)
        try text.write(to: target, atomically: true, encoding: .utf8)
        if target.pathExtension != SpotFile.inlineExtension {
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        }
        self.file = target
        try "[[spots]]\nid = \"\(id)\"\ngrid = true\n".write(to: config.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        model.reload()
        model.panelWillShow(holding: [])
        return id
    }

    public func show(_ place: PlaygroundPlace, id: String) {
        switch place {
        case .sheet:
            if model.openList != id { _ = model.push(FlowSheet(spot: id)) }
        case .card:
            if model.openList != nil { model.closeList(moving: false) }
        }
    }
}
