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
        layout = AttachmentLayout(chips: chips, after: AttachmentLayout(), selection: nil, lead: nil, spreads: false, fit: fit)
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
        if selected == source { selected = chips.first?.source }
        if lead == source { lead = nil }
    }

    mutating func turn(by step: Int) {
        let order = chips.map(\.source)
        guard !order.isEmpty else { return }
        guard let selected, let index = order.firstIndex(of: selected) else {
            let first = lead.flatMap { order.firstIndex(of: $0) } ?? 0
            self.selected = order[step < 0 ? (first + order.count - 1) % order.count : first]
            return
        }
        self.selected = order[(index + step % order.count + order.count) % order.count]
    }

    mutating func select(_ source: String) {
        guard chips.contains(where: { $0.source == source }) else { return }
        selected = source
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
        spreads = false
    }

    mutating func place() {
        layout = AttachmentLayout(chips: chips, after: layout, selection: selected, lead: lead, spreads: spreads, fit: fit)
    }

    private func look(of app: String?, value: AttachmentValue?, own: AttachmentChip.Look?) -> AttachmentChip.Look {
        if let icon = value?.icon { return AttachmentChip.Look(icon) }
        if let own, !own.isSymbol { return own }
        if app != nil, app == front?.bundleID, let path = front?.path { return .file(FileIcon(path: path)) }
        return own ?? .symbol(value?.kind.symbol ?? AttachmentChip.loadingSymbol)
    }

    private mutating func settle() {
        if chips.count > Self.limit { chips = Array(chips.prefix(Self.limit)) }
        if let selected, !chips.contains(where: { $0.source == selected }) { self.selected = chips.first?.source }
        if let lead, !chips.contains(where: { $0.source == lead }) { self.lead = nil }
    }
}
