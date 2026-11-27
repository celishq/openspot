import Foundation

public struct AttachmentLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let chip: AttachmentChip
        public let depth: Int
        public let x: CGFloat
        public let scale: CGFloat
        public let opacity: Double
        public let layer: Double

        init(chip: AttachmentChip, quietDepth depth: Int) {
            self.chip = chip
            self.depth = depth
            x = 0
            scale = SpotTokens.attachmentQuietScale
            opacity = depth == 0 ? 1 : MotionTokens.hiddenOpacity
            layer = -Double(depth)
        }

        init(chip: AttachmentChip, depth: Int, count: Int) {
            let shown = min(count, AttachmentStack.pile)
            self.chip = chip
            self.depth = depth
            scale = 1 - CGFloat(min(depth, AttachmentStack.pile - 1)) * SpotTokens.attachmentShrink
            x = Self.centre(trailing: -CGFloat(shown - 1 - min(depth, shown - 1)) * SpotTokens.attachmentStep, scale: scale)
            opacity = depth < AttachmentStack.pile ? 1 : MotionTokens.hiddenOpacity
            layer = -Double(depth)
        }

        init(chip: AttachmentChip, slot: Int, depth: Int, spreadCount: Int, fit: Int) {
            self.chip = chip
            self.depth = depth
            scale = 1 - CGFloat(min(depth, 1)) * SpotTokens.attachmentShrink
            let front = -CGFloat(spreadCount - 1 - (depth == 0 ? slot : 0)) * SpotTokens.attachmentPitch
            x = Self.centre(trailing: front + (depth == 0 ? 0 : SpotTokens.attachmentStep), scale: scale)
            opacity = depth == 0 ? 1 : depth == 1 ? 1 - SpotTokens.attachmentCardFade : MotionTokens.hiddenOpacity
            layer = -Double(slot) - Double(depth * fit)
        }

        private static func centre(trailing: CGFloat, scale: CGFloat) -> CGFloat {
            trailing.rounded() + SpotTokens.attachmentCard * (1 - scale) / 2
        }
    }

    public let places: [Place]
    public let isSpread: Bool
    public let selection: String?
    public let spreadCount: Int
    public let isQuiet: Bool
    private let start: Int

    init() {
        places = []
        isSpread = false
        selection = nil
        spreadCount = 0
        isQuiet = false
        start = 0
    }

    init(chips: [AttachmentChip], after previous: AttachmentLayout, selection: String?, lead: String?, spreads: Bool, fit: Int) {
        let isSpread = spreads && selection != nil
        var order = chips.map(\.source)
        if !isSpread, let first = selection ?? lead, let index = order.firstIndex(of: first) {
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
        self.start = start
        self.spreadCount = spreadCount
        isQuiet = selection == nil && !places.isEmpty
    }

    private func start(of index: Int, count: Int, fit: Int) -> Int {
        let start = isSpread ? self.start : 0
        guard index >= start else { return index }
        return index < start + fit ? min(start, max(count - fit, 0)) : index - fit + 1
    }
}
