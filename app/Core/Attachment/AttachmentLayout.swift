import Foundation

public struct AttachmentLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let chip: AttachmentChip
        public let slot: Int
        public let depth: Int
        public let x: CGFloat
        public let scale: CGFloat
        public let opacity: Double
        public let layer: Double
        public let isQuiet: Bool

        init(chip: AttachmentChip, quietDepth depth: Int) {
            self.chip = chip
            slot = 0
            self.depth = depth
            x = SpotTokens.attachmentQuietX
            scale = SpotTokens.attachmentQuietScale
            opacity = depth == 0 ? 1 : MotionTokens.hiddenOpacity
            layer = -Double(depth)
            isQuiet = true
        }

        init(chip: AttachmentChip, depth: Int, count: Int) {
            let shown = min(count, AttachmentStack.pile)
            self.chip = chip
            slot = 0
            self.depth = depth
            x = -CGFloat(shown - 1 - min(depth, shown - 1)) * SpotTokens.attachmentStep
            scale = 1 - CGFloat(min(depth, AttachmentStack.pile - 1)) * SpotTokens.attachmentShrink
            opacity = depth < AttachmentStack.pile ? 1 : MotionTokens.hiddenOpacity
            layer = -Double(depth)
            isQuiet = false
        }

        init(chip: AttachmentChip, slot: Int, depth: Int, spreadCount: Int, fit: Int) {
            let pitch = SpotTokens.attachmentCard + SpotTokens.attachmentSpreadGap
            self.chip = chip
            self.slot = slot
            self.depth = depth
            x = -CGFloat(spreadCount - 1 - (depth == 0 ? slot : 0)) * pitch + (depth == 0 ? 0 : SpotTokens.attachmentStep)
            scale = 1 - CGFloat(min(depth, 1)) * SpotTokens.attachmentShrink
            opacity = depth == 0 ? 1 : depth == 1 ? 1 - SpotTokens.attachmentCardFade : MotionTokens.hiddenOpacity
            layer = -Double(slot) - Double(depth * fit)
            isQuiet = false
        }
    }

    public let places: [Place]
    public let isSpread: Bool
    public let selection: String?
    public let spreadCount: Int
    private let order: [String]
    private let start: Int

    init() {
        places = []
        isSpread = false
        selection = nil
        spreadCount = 0
        order = []
        start = 0
    }

    init(chips: [AttachmentChip], after previous: AttachmentLayout, selection: String?, spreads: Bool, fit: Int) {
        let isSpread = spreads && selection != nil
        var order = previous.order(of: chips)
        if !isSpread, let selection, let index = order.firstIndex(of: selection) {
            order = Array(order[index...] + order[..<index])
        }
        let start = isSpread ? previous.start(of: order.firstIndex { $0 == selection } ?? 0, count: order.count, fit: fit) : 0
        let byID = Dictionary(chips.map { ($0.source, $0) }, uniquingKeysWith: { first, _ in first })
        let spreadCount = isSpread ? min(order.count, fit) : 0
        places = order.enumerated().compactMap { index, source in
            guard let chip = byID[source] else { return nil }
            guard isSpread else {
                return selection == nil ? Place(chip: chip, quietDepth: index) : Place(chip: chip, depth: index, count: order.count)
            }
            let slot = index - start
            return (0..<fit).contains(slot)
                ? Place(chip: chip, slot: slot, depth: 0, spreadCount: spreadCount, fit: fit)
                : Place(chip: chip, slot: 0, depth: (slot + order.count) % order.count - fit + 1, spreadCount: spreadCount, fit: fit)
        }
        self.selection = selection
        self.isSpread = isSpread
        self.order = order
        self.start = start
        self.spreadCount = spreadCount
    }

    public var isQuiet: Bool {
        places.first?.isQuiet ?? false
    }

    public var showsHint: Bool {
        isQuiet && places.first?.chip.isLoading == false
    }

    func order(of chips: [AttachmentChip]) -> [String] {
        let sources = chips.map(\.source)
        return order.filter(sources.contains) + sources.filter { !order.contains($0) }
    }

    private func start(of index: Int, count: Int, fit: Int) -> Int {
        let start = isSpread ? self.start : 0
        guard index >= start else { return index }
        return index < start + fit ? min(start, max(count - fit, 0)) : index - fit + 1
    }
}
