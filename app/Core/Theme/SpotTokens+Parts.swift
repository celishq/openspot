import Foundation

extension SpotTokens {
    public static let arrowWidth: CGFloat = 7
    public static let fieldTextGap: CGFloat = 8
    public static let tipGap: CGFloat = 4
    public static let tipWidth: CGFloat = 280
    public static let tipLines = 4
    public static let submenuGap: CGFloat = 4
    public static let groupTitleGap: CGFloat = 6
    public static let cardLineReach: CGFloat = 6
    public static var mediaRadius: CGFloat { layout.radius.media }
    public static let wordsTileCircleShare: CGFloat = 0.36
    public static let wordsTileIconShare: CGFloat = 0.5
    public static let wordsTileGap: CGFloat = 4
    public static let pictureScale: CGFloat = 2
    public static let pictureRimLine: CGFloat = 0.5
    public static let offScreen = CGPoint(x: -9000, y: -9000)
    public static let scrollFadeLength = 56.0
    public static let scrollFadeDistance = 24.0
    public static let textLeading: CGFloat = 3
    public static let textLineGap: CGFloat = 1

    public static let toastMargin: CGFloat = 16
    public static let toastMaxSize = CGSize(width: 560, height: 120)
    public static let toastGlyphGap: CGFloat = 8
    public static let toastMarkSide: CGFloat = 16
    public static let toastPaddingY: CGFloat = 10
    public static let toastKeySpace: CGFloat = 2

    public static let contextCard: CGFloat = 28
    public static var contextCardRadius: CGFloat { contextCard * 0.25 }
    public static let contextInset: CGFloat = 1.5
    public static var contextIcon: CGFloat { contextCard - 2 * contextInset }
    public static var contextIconRadius: CGFloat { contextIcon * 0.224 }
    public static var contextSymbol: CGFloat { contextCard * 0.6 }
    public static let contextBorder: CGFloat = 0.5
    public static var contextStep: CGFloat { contextCard * 0.25 }
    public static let contextShrink: CGFloat = 0.1
    public static var contextSpreadGap: CGFloat { contextCard * 0.42 }
    public static var contextBadge: CGFloat { (contextCard * contextCard / 6).squareRoot() }
    public static var contextBadgeGlyph: CGFloat { contextBadge * 0.85 }
    public static let contextBadgeNudge: CGFloat = 0.5
    public static let contextNearShadowRadius: CGFloat = 2.5
    public static let contextNearShadowDrop: CGFloat = 2
    public static let contextFarShadowRadius: CGFloat = 7
    public static let contextFarShadowDrop: CGFloat = 6
    public static let contextDot: CGFloat = 4
    public static let contextDotGap: CGFloat = 3
    public static let contextValueRise: CGFloat = 8
    public static let contextGap: CGFloat = 8
    public static let previewLines = 2
    public static let previewCaptionGap: CGFloat = 4

    public static var contextValueRoom: CGFloat { cell + rowGap }

    public static func contextStack(count: Int) -> CGFloat {
        count == 0 ? 0 : contextCard + CGFloat(count - 1) * contextStep
    }

    public static let metricBigRingLine: CGFloat = 8
    public static let metricRingLine: CGFloat = 4
    public static let metricBarLine: CGFloat = 4
    public static let ringInsideGap: CGFloat = 2
    public static let trendBar: CGFloat = 3
    public static let trendGap: CGFloat = 2
    public static let toneDot: CGFloat = 7
    public static let edgeMarkWidth: CGFloat = 44
    public static let lineTrendHeight: CGFloat = 12
    public static let lineRingSide: CGFloat = 30
    public static let lineRingLine: CGFloat = 2

    public static let menuBarPill = CGSize(width: 40, height: 24)
    public static let menuBarGap: CGFloat = 5
    public static let menuBarCountGap: CGFloat = 3
    public static let menuBarPadding: CGFloat = 6
    public static let menuBarRing: CGFloat = 14
    public static let menuBarRingLine: CGFloat = 2.5
    public static let menuBarBar: CGFloat = 2
    public static let menuBarBarGap: CGFloat = 1
    public static let menuBarBarsHeight: CGFloat = 14

    public static var partsWidth: CGFloat { layout.partsWidth }
    public static var partsMaxHeight: CGFloat { sheetMaxHeight - sheetFieldDrop - padding }
    public static let partGap: CGFloat = 6
    public static let partMaxRound: CGFloat = 44
    public static var partFieldRoom: CGFloat { listRow + rowGap }
    public static let dividerHeight: CGFloat = 1
    public static let partGroupGap: CGFloat = 24
    public static let keycapSide: CGFloat = 52
    public static let keycapGap: CGFloat = 6
    public static let keycapPlus: CGFloat = 12
    public static let keycapHintGap: CGFloat = 4
    public static let keycapHintLine: CGFloat = 13
    public static let keycapStatusGap: CGFloat = 8
    public static let keycapStatusInset: CGFloat = 16
    public static let keycapCorner: CGFloat = 8
    public static let keycapEdge: CGFloat = 2.5
    public static let keycapLitEdge: CGFloat = 2
    public static let keycapGlow: CGFloat = 2.5
    public static let keycapDashLine: CGFloat = 1.5
    public static let menuMargin: CGFloat = 16
    public static let backdropLeastFade: CGFloat = 16
    public static var backdrop: Theme.Backdrop { layout.backdrop }
    public static let backdropMaskScale: CGFloat = 0.5
    public static let backdropFadeSteps = 64
    public static let backdropLeastBlur: CGFloat = 0.25
    public static let backdropBlurResponse: CGFloat = 1.2
    public static let cardShadowReach: CGFloat = 3

    public static let swatchSize: CGFloat = 22
    public static let smallSwatch: CGFloat = 16
    public static let partLineGap: CGFloat = 8
    public static let narrowCell: CGFloat = 80
    public static let narrowGap: CGFloat = 2
    public static let partSymbolWidth: CGFloat = 22
    public static let nodeBorder: CGFloat = 1
    public static let chipPaddingY: CGFloat = 5
    public static let choiceChevronGap: CGFloat = 4
    public static let colorBarWidth: CGFloat = 4
    public static let colorBarGap: CGFloat = 8

    public static let slotSwitchGap: CGFloat = 8
    public static let solidSwitchWidth: CGFloat = 36
    public static let solidSwitchHeight: CGFloat = 16
    public static let solidSwitchInset: CGFloat = 2
    public static let slotButton: CGFloat = 28
    public static let slotChipPaddingX: CGFloat = 12

    public static let workThickLine: CGFloat = 4
    public static let workThinLine: CGFloat = 2.5
    public static let workSquareShare: CGFloat = 0.28
    public static let workSquareCorner: CGFloat = 0.06
    public static let toneDotParts: CGFloat = 4
    public static let toneDotLeast: CGFloat = 5
    public static let toneDotShiftParts: CGFloat = 12
    public static let dragIconSide: CGFloat = 32
    public static let dragFan: CGFloat = 6

    public static let playgroundSize = CGSize(width: 1180, height: 940)
    public static let playgroundTextWidth: CGFloat = 320
    public static let playgroundTextIdeal: CGFloat = 440
    public static let playgroundTopHeight: CGFloat = 360
    public static let playgroundLogHeight: CGFloat = 120

    public static let builtIn = Theme.Layout()
    public static let windowFooterGap: CGFloat = builtIn.space.columnGap
    public static let windowFooterPadding: CGFloat = builtIn.space.padding
    public static let windowRowPadding: CGFloat = 10

    public static let emblemSide: CGFloat = 26
    public static var publisherPlace: CGSize { CGSize(width: partsWidth, height: 178) }
    public static let publisherTiltReach = CGSize(width: 10, height: 7)
    public static let publisherRatio = 263.0 / 166.0
    public static let publisherRadius: CGFloat = 14
    public static let publisherInset: CGFloat = 16
    public static let publisherLineGap: CGFloat = 8
    public static let publisherCatchShift: CGFloat = 0.8
    public static let publisherPillBlur: CGFloat = 6
    public static let publisherPillGap: CGFloat = 5
    public static let publisherPillHeight: CGFloat = 22
    public static let publisherPillCharWidth = 6.3
    public static let publisherPillRoom = 33.0
}
