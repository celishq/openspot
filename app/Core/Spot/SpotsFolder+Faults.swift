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
            guard let file = SpotID(id).file(in: url) else { return nil }
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
}
