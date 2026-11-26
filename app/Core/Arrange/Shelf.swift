import Foundation
import Observation

@MainActor
@Observable
public final class Shelf {
    public private(set) var offGrid: [SpotsModel.Entry] = []
    public private(set) var spots: [SpotsModel.Entry] = []
    public private(set) var query = ""
    public private(set) var layout: ShelfLayout?
    @ObservationIgnored public private(set) var scroll: CGFloat = 0
    @ObservationIgnored private var found = SearchList<SpotsModel.Entry>()
    @ObservationIgnored private var room: (screen: CGSize, panelOrigin: CGPoint)?
    @ObservationIgnored private var slots: [String: ShelfSlot] = [:]

    public init() {}

    func take(offGrid next: [SpotsModel.Entry]) {
        guard next != offGrid else { return }
        offGrid = next
        found = SearchList(next) { ($0.spot.name, nil, $0.spot.keywords) }
        filter()
    }

    func search(_ text: String) -> Bool {
        guard text != query else { return false }
        query = text
        filter()
        return true
    }

    public func scrolled(to offset: CGFloat) {
        guard scroll != offset else { return }
        scroll = offset
    }

    public func place(screen: CGSize, panelOrigin: CGPoint) {
        if room?.screen != screen || room?.panelOrigin != panelOrigin { slots = [:] }
        room = (screen, panelOrigin)
        lay()
    }

    func reset() {
        if !query.isEmpty { query = "" }
        scroll = 0
        slots = [:]
        filter()
    }

    func lay(placing drop: (id: String, slot: ShelfSlot)? = nil) {
        guard let room else { return }
        let panel = CGRect(x: room.panelOrigin.x + SpotTokens.halo, y: room.panelOrigin.y + SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.panelHeight)
        let isFull = query.trimmingCharacters(in: .whitespaces).isEmpty
        let ids = spots.map(\.id)
        let next = ShelfLayout(
            screen: room.screen,
            panel: panel,
            sizes: spots.map(\.size),
            slots: isFull ? ids.map { $0 == drop?.id ? drop?.slot : slots[$0] } : [],
            first: isFull ? ids.firstIndex { $0 == drop?.id } : nil
        )
        if isFull { slots = Dictionary(uniqueKeysWithValues: zip(ids, next.slots)) }
        if next != layout { layout = next }
    }

    func slot(at corner: CGPoint, size: SpotSize) -> ShelfSlot? {
        guard let layout, let offset = inPanel else { return nil }
        return layout.slot(near: CGPoint(x: corner.x - offset.width, y: corner.y - offset.height), size: size)
    }

    public func origin(of id: String) -> CGPoint? {
        guard let layout, let offset = inPanel, let index = spots.firstIndex(where: { $0.id == id }), layout.rects.indices.contains(index) else { return nil }
        let rect = layout.rects[index]
        return CGPoint(x: rect.minX + offset.width, y: rect.minY + offset.height)
    }

    private var inPanel: CGSize? {
        guard let layout, let room else { return nil }
        return CGSize(width: -room.panelOrigin.x, height: layout.band.lowerBound + SpotTokens.scrollFadeLength - scroll - room.panelOrigin.y)
    }

    func size(of id: String) -> SpotSize? {
        guard let layout, let index = spots.firstIndex(where: { $0.id == id }), layout.sizes.indices.contains(index) else { return nil }
        return layout.sizes[index]
    }

    private func filter() {
        let next = found.matching(SearchQuery(text: query))
        if next != spots { spots = next }
        lay()
    }
}
