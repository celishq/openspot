import Foundation

extension SpotRuns {
    public func knownSheet(of id: String) -> Bool? {
        guard let fact = sheetFacts[id], fact.stamp == stamps[id] else { return nil }
        return fact.hasSheet
    }

    func takeSheetFacts(of scripts: [Spot]) {
        let ids = Set(scripts.map(\.id))
        sheetFacts = sheetFacts.filter { ids.contains($0.key) }
        guard learnsSheets else { return }
        for spot in scripts {
            guard let stamp = stamps[spot.id], sheetFacts[spot.id]?.stamp != stamp else { continue }
            sheetFacts[spot.id] = SheetFact(stamp: stamp)
            unlearned.append(spot.id)
        }
    }

    func learnNextSheet() {
        guard learning == nil, !hasQuit else { return }
        while !unlearned.isEmpty {
            let id = unlearned.removeFirst()
            guard let stamp = stamps[id], sheetFacts[id] == SheetFact(stamp: stamp), let spot = sheets[id]?.spot else { continue }
            learning = Task { [weak self, limit = showLimit] in
                var hasSheet: Bool?
                if let text = try? await self?.answer(of: spot, .show, limit: limit, event: .want) { hasSheet = await Self.holdsSheet(text) }
                self?.learned(id, stamp: stamp, hasSheet: hasSheet)
            }
            return
        }
    }

    private func learned(_ id: String, stamp: [Int], hasSheet: Bool?) {
        learning = nil
        guard !hasQuit else { return }
        if sheetFacts[id]?.stamp == stamp {
            sheetFacts[id]?.hasSheet = hasSheet
            if let hasSheet { sheets[id]?.know(sheet: hasSheet) }
        }
        learnNextSheet()
    }

    @concurrent
    private nonisolated static func holdsSheet(_ text: String) async -> Bool {
        FrameRoot(text: text).isPicture
    }
}
