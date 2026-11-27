import Foundation

extension SpotsModel {
    nonisolated static let newAge: TimeInterval = 7 * 86_400

    func isNew(_ spot: Spot) -> Bool {
        guard let added = spot.addedDate, runs.now().timeIntervalSince(added) < Self.newAge else { return false }
        return !usedIDs.contains(spot.id)
    }

    func markUsed(_ id: String) {
        guard usedIDs.insert(id).inserted, entries.contains(where: { $0.id == id && $0.isNew }) else { return }
        teachesEdit = id
        patchEntries([id])
    }

    @concurrent
    nonisolated static func readUsed(_ usage: StatsLog, at date: Date) async -> Set<String> {
        let days = usage.days(Int(newAge / 86_400) + 1, at: date)
        return Set(days.flatMap { day in day.spots.filter { $0.value.acts > 0 }.keys })
    }
}
