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
    private var front: FrontApp?
    private var arrival: [String] = []

    public init(fit: Int = SpotTokens.attachmentFit) {
        self.fit = fit
    }

    public var selectedChip: AttachmentChip? {
        chips.first { $0.source == selected }
    }

    public var isOn: Bool {
        selected != nil
    }

    mutating func open(over front: FrontApp?, loading: [(source: String, look: AttachmentChip.Look?)], unread: [(source: String, look: AttachmentChip.Look?)] = []) {
        self.front = front
        selected = nil
        arrival = (unread + loading).map(\.source)
        chips = unread.map { AttachmentChip(source: $0.source, app: front?.bundleID, appName: front?.name, look: look(of: front?.bundleID, kind: nil, else: $0.look), state: .unread) }
            + loading.map { AttachmentChip(source: $0.source, app: front?.bundleID, appName: front?.name, look: look(of: front?.bundleID, kind: nil, else: $0.look)) }
        settle()
        layout = AttachmentLayout(chips: chips, after: AttachmentLayout(), selection: nil, spreads: false, fit: fit)
    }

    mutating func fill(_ source: String, with value: AttachmentValue, look own: AttachmentChip.Look?) {
        let held = chips.first { $0.source == source }
        let app = value.app ?? held?.app
        let name = app == held?.app ? held?.appName : app == front?.bundleID ? front?.name : nil
        chips.removeAll { $0.source == source }
        chips.append(AttachmentChip(source: source, app: app, appName: name, look: look(of: app, kind: value.kind, else: own), state: .ready(value)))
        if !arrival.contains(source) { arrival.append(source) }
        settle()
    }

    mutating func end(_ source: String) {
        guard chips.contains(where: { $0.source == source && $0.isLoading }) else { return }
        remove(source)
    }

    mutating func mark(_ source: String, _ state: AttachmentChip.State) {
        guard let index = chips.firstIndex(where: { $0.source == source }), chips[index].state != state else { return }
        chips[index].state = state
    }

    mutating func remove(_ source: String) {
        chips.removeAll { $0.source == source }
        if selected == source { selected = chips.first?.source }
    }

    mutating func turn(by step: Int) {
        let order = layout.order(of: chips)
        guard !order.isEmpty else { return }
        guard let selected, let index = order.firstIndex(of: selected) else {
            self.selected = order[step < 0 ? order.count - 1 : 0]
            return
        }
        self.selected = order[(index + step % order.count + order.count) % order.count]
    }

    mutating func leave() {
        selected = nil
    }

    mutating func place(spreads: Bool) {
        layout = AttachmentLayout(chips: chips, after: layout, selection: selected, spreads: spreads, fit: fit)
    }

    private func look(of app: String?, kind: AttachmentValue.Kind?, else own: AttachmentChip.Look?) -> AttachmentChip.Look {
        if app != nil, app == front?.bundleID, let path = front?.path { return .file(FileIcon(path: path)) }
        return own ?? .symbol(kind?.symbol ?? AttachmentChip.loadingSymbol)
    }

    private mutating func settle() {
        let place = Dictionary(arrival.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        chips = Array(chips.sorted { ($0.rank(over: front?.bundleID), place[$0.source] ?? 0) < ($1.rank(over: front?.bundleID), place[$1.source] ?? 0) }.prefix(Self.limit))
        if let selected, !chips.contains(where: { $0.source == selected }) { self.selected = chips.first?.source }
    }
}
