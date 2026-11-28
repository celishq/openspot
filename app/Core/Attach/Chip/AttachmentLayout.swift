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

        init(chip: AttachmentChip, slot: Int, depth: Int, spreadCount: Int) {
            self.chip = chip
            self.depth = depth
            scale = 1 - CGFloat(min(depth, 1)) * SpotTokens.attachmentShrink
            let front = -CGFloat(spreadCount - 1 - slot) * SpotTokens.attachmentPitch
            x = Self.centre(trailing: front + (depth == 0 ? 0 : SpotTokens.attachmentStep), scale: scale)
            opacity = depth == 0 ? 1 : depth == 1 ? 1 - SpotTokens.attachmentCardFade : MotionTokens.hiddenOpacity
            layer = -Double(slot + depth)
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

    init() {
        places = []
        isSpread = false
        selection = nil
        spreadCount = 0
        isQuiet = false
    }

    init(chips: [AttachmentChip], selection: String?, lead: String?, spreads: Bool, fit: Int) {
        let isSpread = spreads && selection != nil
        var order = chips.map(\.source)
        if let first = selection ?? lead, let index = order.firstIndex(of: first) {
            order = Array(order[index...] + order[..<index])
        }
        let byID = Dictionary(chips.map { ($0.source, $0) }, uniquingKeysWith: { first, _ in first })
        let spreadCount = isSpread ? min(order.count, fit) : 0
        places = order.enumerated().compactMap { rank, source in
            guard let chip = byID[source] else { return nil }
            guard isSpread else {
                return selection == nil ? Place(chip: chip, quietDepth: rank) : Place(chip: chip, depth: rank, count: order.count)
            }
            return rank < spreadCount
                ? Place(chip: chip, slot: rank, depth: 0, spreadCount: spreadCount)
                : Place(chip: chip, slot: spreadCount - 1, depth: rank - spreadCount + 1, spreadCount: spreadCount)
        }
        self.selection = selection
        self.isSpread = isSpread
        self.spreadCount = spreadCount
        isQuiet = selection == nil && !places.isEmpty
    }
}
