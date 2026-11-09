import Foundation

/// The cards of the files that give no spot.
extension PluginFolder {
    /// A card for each file of this folder that gives no spot, which opens its faults. Its title says what a press does, and
    /// its detail names the spot, so that both fit a wide card. A file that loads with a fault, such as a key that another
    /// spot has, keeps its own card. Each card takes the ID and the place of the spot it stands for.
    public func faultSpots(of scan: ScanResult, agent: AgentPrompt) -> [Spot] {
        let loaded = Set(scan.plugins.filter { !$0.commands.isEmpty }.map(\.id))
        let faults = Dictionary(grouping: scan.refused.filter { !loaded.contains($0.file) }, by: \.file)
        return faults.keys.sorted().compactMap { id in
            guard let file = file(of: id) else { return nil }
            let name = Plugin.name(of: file)
            let reasons = faults[id]?.map(\.reason) ?? []
            let spot = Spot(
                id: id,
                name: "Fix",
                url: file,
                kind: .list,
                symbol: "exclamationmark.triangle",
                subtitle: name,
                read: .sheet,
                shipped: .fault(FaultSpot(file: file, name: name, faults: reasons, agent: agent))
            )
            let added = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate
            return added.map(spot.added(at:)) ?? spot
        }
    }

    /// The file of a spot ID in this folder, such as `home/coffee.sh` for `home/coffee`.
    func file(of id: String) -> URL? {
        let parts = id.split(separator: "/").map(String.init)
        let place = parts.dropLast().reduce(url) { $0.appendingPathComponent($1, isDirectory: true) }
        guard let stem = parts.last, let names = try? FileManager.default.contentsOfDirectory(atPath: place.path) else { return nil }
        return names.sorted().lazy.map { place.appendingPathComponent($0) }.first { file in
            var isFolder: ObjCBool = false
            return file.deletingPathExtension().lastPathComponent == stem && !file.lastPathComponent.hasPrefix(".")
                && FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue
        }
    }
}
