import Foundation

public struct AttachmentStack: Equatable, Sendable {
    public static let limit = 6
    public static let pile = 3

    public let fit: Int
    public private(set) var chips: [AttachmentChip] = [] {
        didSet {
            let apps = Dictionary(chips.compactMap { chip in chip.app.map { ($0, 1) } }, uniquingKeysWith: +)
            for index in chips.indices { chips[index].showsKind = chips[index].app.map { (apps[$0] ?? 0) > 1 } ?? false }
        }
    }
    public private(set) var selected: String?
    public private(set) var layout = AttachmentLayout()
    var pause: Duration = .seconds(1)
    private(set) var spreads = false
    var isMoving = false
    private var front: FrontApp?
    private var lead: String?

    public init(fit: Int = SpotTokens.attachmentFit) {
        self.fit = fit
    }

    public var selectedChip: AttachmentChip? {
        chips.first { $0.source == selected }
    }

    public var isOn: Bool {
        selected != nil
    }

    mutating func open(over front: FrontApp?, unread: [(source: String, look: AttachmentChip.Look?)]) {
        self.front = front
        selected = nil
        lead = nil
        spreads = false
        isMoving = false
        chips = unread.map { AttachmentChip(source: $0.source, app: front?.bundleID, appName: front?.name, look: look(of: front?.bundleID, value: nil, own: $0.look), state: .unread) }
        settle()
        place()
    }

    mutating func fill(_ source: String, with value: AttachmentValue, look own: AttachmentChip.Look?) {
        let held = chips.first { $0.source == source }
        let app = value.app ?? held?.app
        let name = app == held?.app ? held?.appName : app == front?.bundleID ? front?.name : nil
        let chip = AttachmentChip(source: source, app: app, appName: name, look: look(of: app, value: value, own: own), state: .ready(value))
        if let index = chips.firstIndex(where: { $0.source == source }) { chips[index] = chip } else { chips.append(chip) }
        settle()
    }

    mutating func fail(_ source: String, _ text: String, look own: AttachmentChip.Look?) {
        guard !chips.contains(where: { $0.source == source }) else { return mark(source, .failed(text)) }
        chips.append(AttachmentChip(source: source, app: front?.bundleID, appName: front?.name, look: look(of: front?.bundleID, value: nil, own: own), state: .failed(text)))
        settle()
    }

    mutating func mark(_ source: String, _ state: AttachmentChip.State) {
        guard let index = chips.firstIndex(where: { $0.source == source }), chips[index].state != state else { return }
        chips[index].state = state
    }

    mutating func remove(_ source: String) {
        chips.removeAll { $0.source == source }
        settle()
    }

    @discardableResult
    mutating func turn(by step: Int) -> Bool {
        let order = chips.map(\.source)
        guard !order.isEmpty else { return false }
        if let selected, let index = order.firstIndex(of: selected) {
            self.selected = order[(index + step % order.count + order.count) % order.count]
        } else {
            let front = (step < 0 ? layout.places.last : layout.places.first)?.chip.source
            self.selected = front.flatMap { order.contains($0) ? $0 : nil } ?? order[0]
        }
        let start = lead
        reveal(forward: step > 0)
        return lead != start
    }

    mutating func select(_ source: String) {
        guard chips.contains(where: { $0.source == source }) else { return }
        selected = source
        reveal(forward: false)
    }

    mutating func leave() {
        lead = selected ?? lead
        selected = nil
        spreads = false
    }

    mutating func spread() {
        spreads = true
    }

    mutating func fold() {
        lead = selected ?? lead
        spreads = false
    }

    mutating func place() {
        layout = AttachmentLayout(chips: chips, selection: selected, lead: lead, spreads: spreads, fit: fit)
    }

    private func look(of app: String?, value: AttachmentValue?, own: AttachmentChip.Look?) -> AttachmentChip.Look {
        if let icon = value?.icon { return AttachmentChip.Look(icon) }
        if let own, !own.isSymbol { return own }
        if app != nil, app == front?.bundleID, let path = front?.path { return .file(FileIcon(path: path)) }
        return own ?? .symbol(value?.kind.symbol ?? AttachmentChip.loadingSymbol)
    }

    private mutating func reveal(forward: Bool) {
        guard let selected, let index = chips.firstIndex(where: { $0.source == selected }) else { return }
        let start = lead.flatMap { lead in chips.firstIndex { $0.source == lead } } ?? 0
        guard (index - start + chips.count) % chips.count >= fit else { return }
        lead = forward ? chips[(index - fit + 1 + chips.count) % chips.count].source : selected
    }

    private mutating func settle() {
        if chips.count > Self.limit { chips = Array(chips.prefix(Self.limit)) }
        if let selected, !chips.contains(where: { $0.source == selected }) { self.selected = chips.first?.source }
        if let lead, !chips.contains(where: { $0.source == lead }) { self.lead = nil }
    }
}
