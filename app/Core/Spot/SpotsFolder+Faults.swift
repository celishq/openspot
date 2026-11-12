import Foundation

/// The cards of the files that give no spot.
extension SpotsFolder {
    /// A card for each file of this folder that gives no spot, which opens its faults. Its title says what a press does, and
    /// its detail names the spot, so that both fit a wide card. A file that loads with a fault, such as a key that another
    /// spot has, keeps its own card. Each card takes the ID and the place of the spot it stands for.
    public func faultSpots(of scan: ScanResult, prompt: AgentPrompt) -> [Spot] {
        let loaded = Set(scan.files.filter { !$0.spots.isEmpty }.map(\.id))
        let faults = Dictionary(grouping: scan.refused.filter { !loaded.contains($0.file) }, by: \.file)
        return faults.keys.sorted().compactMap { id in
            guard let file = file(of: id) else { return nil }
            let name = SpotFile.name(of: file)
            let reasons = faults[id]?.map(\.reason) ?? []
            let spot = Spot(
                id: id,
                name: "Fix",
                url: file,
                kind: .list,
                symbol: "exclamationmark.triangle",
                subtitle: name,
                read: .sheet,
                host: .fault(FaultSpot(file: file, name: name, faults: reasons, prompt: prompt))
            )
            let added = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate
            return added.map(spot.added(at:)) ?? spot
        }
    }

    /// The file of a spot ID in this folder, such as `home.spot/coffee.sh` for `home/coffee` and `home.spot/home.sh` for `home`.
    func file(of id: String) -> URL? {
        let parts = id.split(separator: "/").map(String.init)
        guard let name = parts.first else { return nil }
        let place = url.appendingPathComponent(name + "." + SpotFolder.fileExtension, isDirectory: true)
        guard let stem = parts.last, let names = try? FileManager.default.contentsOfDirectory(atPath: place.path) else { return nil }
        return names.sorted().lazy.map { place.appendingPathComponent($0) }.first { file in
            var isFolder: ObjCBool = false
            return file.deletingPathExtension().lastPathComponent == stem && !file.lastPathComponent.hasPrefix(".")
                && FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue
        }
    }
}
