import Foundation

extension SpotTokens {
    public static let arrowWidth: CGFloat = 7
    public static let fieldTextGap: CGFloat = 8
    public static let tipGap: CGFloat = 4
    public static let tipWidth: CGFloat = 280
    public static let tipLines = 4
    public static let submenuGap: CGFloat = 4
    public static let cardLineReach: CGFloat = 6
    public static var mediaRadius: CGFloat { layout.radius.media }
    public static let wordsTileCircleShare: CGFloat = 0.36
    public static let wordsTileIconShare: CGFloat = 0.5
    public static let wordsTileGap: CGFloat = 4
    public static let pictureScale: CGFloat = 2
    public static let pictureRimLine: CGFloat = 0.5
    public static let offScreen = CGPoint(x: -9000, y: -9000)
    public static let scrollFadeLength = 56.0
    public static let arrangeMargin: CGFloat = 24
    public static let arrangeBar: CGFloat = 96
    public static let arrangeFoot: CGFloat = 72
    public static let arrangeButton: CGFloat = 34
    public static let arrangeButtonPadding: CGFloat = 16
    public static let scrollFadeDistance = 24.0
    public static let textLeading: CGFloat = 3
    public static let textLineGap: CGFloat = 1

    public static let toastMargin: CGFloat = 16
    public static let toastMaxWidth: CGFloat = 560
    public static let toastGlyphGap: CGFloat = 8
    public static let toastMarkSide: CGFloat = 16
    public static let toastPaddingY: CGFloat = 10
    public static let toastKeySpace: CGFloat = 2

    public static let attachmentCard: CGFloat = 28
    public static var attachmentCardRadius: CGFloat { min(attachmentCard * 0.25 * cardRadius / builtIn.radius.card, attachmentCard / 2) }
    public static let attachmentInset: CGFloat = 1.5
    public static var attachmentIcon: CGFloat { attachmentCard - 2 * attachmentInset }
    public static var attachmentIconRadius: CGFloat { min(attachmentIcon * 0.224 * cardRadius / builtIn.radius.card, attachmentIcon / 2) }
    public static var attachmentSymbol: CGFloat { attachmentIcon * 0.5 }
    public static let attachmentBorder: CGFloat = 1
    public static var attachmentStep: CGFloat { attachmentCard * 0.25 }
    public static let attachmentShrink: CGFloat = 0.1
    public static let attachmentQuietIcon: CGFloat = 20
    public static var attachmentQuietScale: CGFloat { attachmentQuietIcon / attachmentIcon }
    public static var attachmentQuietRadius: CGFloat { attachmentIconRadius * attachmentQuietScale }
    public static var attachmentEdge: CGFloat { (cell - attachmentCard) / 2 }
    public static let attachmentCardFade = 0.3
    public static var attachmentSpreadGap: CGFloat { attachmentCard * 0.42 }
    public static var attachmentPitch: CGFloat { attachmentCard + attachmentSpreadGap }
    public static var attachmentBadge: CGFloat { (attachmentCard * attachmentCard / 6).squareRoot() }
    public static var attachmentBadgeGlyph: CGFloat { attachmentBadge * 0.72 }
    public static let attachmentBadgeNudge: CGFloat = 0.5
    public static let attachmentNearShadowRadius: CGFloat = 2.5
    public static let attachmentNearShadowDrop: CGFloat = 2
    public static let attachmentFarShadowRadius: CGFloat = 7
    public static let attachmentFarShadowDrop: CGFloat = 6
    public static let attachmentDot: CGFloat = 4
    public static let attachmentDotGap: CGFloat = 3
    public static let attachmentGap: CGFloat = 8
    public static let detailsLineLimit = 2

    public static let detailsTop: CGFloat = 9
    public static var detailsFoot: CGFloat { padding + glyphInset }
    public static let detailsLineGap: CGFloat = 1
    static let lineShare: CGFloat = 1.25
    static let glyphWidthShare: CGFloat = 0.55

    public static var detailsWidth: CGFloat { gridWidth - 2 * (padding + glyphInset) }
    public static var detailsContentHeight: CGFloat { detailsHeight(lines: detailsLineLimit) - detailsTop - detailsFoot }
    public static var detailsPicture: CGFloat { detailsHeight(lines: 1) - detailsTop - detailsFoot }
    public static let detailsPictureGap: CGFloat = 8

    public static func detailsLines(of text: String, besidePicture: Bool = false) -> Int {
        guard !text.isEmpty else { return besidePicture ? 1 : 0 }
        let width = CGFloat(text.count) * CGFloat(layout.type.body) * glyphWidthShare
        let room = detailsWidth - (besidePicture ? detailsPicture + detailsPictureGap : 0)
        return min(detailsLineLimit, max(1, Int((width / room).rounded(.up))))
    }

    public static func detailsHeight(lines: Int) -> CGFloat {
        let caption = CGFloat(layout.type.detail) * lineShare
        let body = lines == 0 ? 0 : detailsLineGap + CGFloat(lines) * CGFloat(layout.type.body) * lineShare
        return (detailsTop + detailsFoot + caption + body).rounded(.up)
    }

    public static var attachmentFit: Int {
        let room = gridWidth - 2 * padding - glyph - fieldTextGap + attachmentSpreadGap
        return max(AttachmentStack.pile, min(AttachmentStack.limit, Int(room / (attachmentCard + attachmentSpreadGap))))
    }

    public static func fieldRect(room: CGFloat) -> CGRect {
        CGRect(x: halo, y: halo, width: gridWidth, height: cell + room)
    }

    public static func attachmentStack(count: Int) -> CGFloat {
        count == 0 ? 0 : attachmentCard + CGFloat(count - 1) * attachmentStep
    }

    public static var attachmentRow: CGFloat {
        attachmentCard + CGFloat(attachmentFit - 1) * attachmentPitch
    }

    public static var attachmentReach: CGFloat {
        2 * attachmentFarShadowRadius + attachmentFarShadowDrop
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
    public static let menuBarTint = 0.2
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
    public static let backdropMaskBytes = 16 * 1024 * 1024
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
    public static let settingsWindowSize = CGSize(width: 880, height: 620)
    public static let settingsWindowMinSize = CGSize(width: 680, height: 460)
    public static let settingsSidebarMin: CGFloat = 200
    public static let settingsSidebarIdeal: CGFloat = 240
    public static let settingsSidebarMax: CGFloat = 320
    public static let settingsPagePadding: CGFloat = 24
    public static var settingsTitleReveal: CGFloat { settingsPagePadding + settingsHeaderPadding + settingsHeaderTile }
    public static var settingsHeroReveal: CGFloat { settingsPagePadding + settingsHeroAvatar + settingsHeroGap }
    public static var settingsHeadingReveal: CGFloat { settingsPagePadding + settingsTitleLine }
    public static let settingsTitleLine: CGFloat = 32
    public static let settingsHeadingGap: CGFloat = 20
    public static let settingsAccountTile: CGFloat = 28
    public static let settingsAccountPadding: CGFloat = 8
    public static let settingsAccountCorner: CGFloat = 8
    public static let settingsAccountInset: CGFloat = 10
    public static let settingsFormWidth: CGFloat = 640
    public static let settingsBarFade: CGFloat = 14
    public static let settingsSectionTile: CGFloat = 20
    public static let settingsRowTile: CGFloat = 22
    public static let settingsHeaderTile: CGFloat = 52
    public static let settingsHeroAvatar: CGFloat = 72
    public static let settingsHeroGap: CGFloat = 8
    public static let settingsFoundTile: CGFloat = 24
    public static let settingsSpotIcon: CGFloat = 44
    public static let settingsTileCorner: CGFloat = 0.225
    public static let settingsBadge: CGFloat = 18
    public static let settingsRowGap: CGFloat = 10
    public static let settingsCorner: CGFloat = 10
    public static let settingsRim: CGFloat = 0.5
    public static let settingsGroupGap: CGFloat = 8
    public static let settingsHeaderGap: CGFloat = 14
    public static let settingsHeaderPadding: CGFloat = 16
    public static let settingsTitleGap: CGFloat = 4
    public static let settingsLineGap: CGFloat = 1
    public static let settingsTrailingGap: CGFloat = 8
    public static let settingsValueGap: CGFloat = 12
    public static let settingsRecordHeight: CGFloat = 22
    public static let settingsRecordWidth: CGFloat = 132
    public static let settingsRecordRing: CGFloat = 1
    public static let settingsRecordClear: CGFloat = 5
    public static let settingsRecordCorner: CGFloat = 5
    public static let settingsKeyName: CGFloat = 150
    public static let settingsFieldWidth: CGFloat = 220
    public static let settingsUseGap: CGFloat = 6
    public static let settingsLookColumn: CGFloat = 170
    public static let settingsLookGap: CGFloat = 18
    public static let settingsLookHeight: CGFloat = 104
    public static let settingsLookWords: CGFloat = 6
    public static let settingsLookTopInset: CGFloat = 14
    public static let settingsLookRing: CGFloat = 3
    public static let settingsLookCardRing: CGFloat = 4
    public static let settingsLookCheckInset: CGFloat = 6
    public static let settingsSheetWidth: CGFloat = 460
    public static let settingsSheetPadding: CGFloat = 24
    public static let settingsSheetGap: CGFloat = 14
    public static let settingsSheetTop: CGFloat = 6
    public static let settingsWordsGapX: CGFloat = 24
    public static let settingsWordsGapY: CGFloat = 8
    public static let settingsWordsNumber: CGFloat = 18
    public static let settingsPhraseHeight: CGFloat = 76
    public static let settingsPhrasePadding: CGFloat = 6
    public static let settingsPhraseCorner: CGFloat = 7
    public static let settingsGrantPadding: CGFloat = 22
    public static let settingsGrantCorner: CGFloat = 16
    public static let settingsGrantShadow: CGFloat = 24
    public static let settingsGrantDrop: CGFloat = 10
    public static let settingsGrantStep: CGFloat = 22
    public static let settingsGrantStepGap: CGFloat = 12
    public static let settingsSwitchHeight: CGFloat = 38
    public static let settingsSwitchPadding: CGFloat = 10
    public static let settingsSwitchInset: CGFloat = 3
    public static let settingsSwitchRing: CGFloat = 1.5
    public static let settingsSwitchCorner: CGFloat = 8
    public static let settingsSwitchFrame: CGFloat = 8
    public static let settingsAppIcon: CGFloat = 22
    public static let settingsDot: CGFloat = 7
    public static let settingsDetailGap: CGFloat = 2

    public static let builtIn = Theme.Layout()
    public static let windowFooterGap: CGFloat = builtIn.space.columnGap
    public static let windowFooterPadding: CGFloat = builtIn.space.padding
    public static let windowRowPadding: CGFloat = 10

    public static let storeInset: CGFloat = 16
    public static let storeHeadingGap: CGFloat = 10
    public static let storeMarkerWidth: CGFloat = 18
    public static let storeQuoteBar: CGFloat = 3
    public static let storeCodePadding: CGFloat = 8
    public static let storeTilePadding: CGFloat = 12
    public static let storeTileRadius: CGFloat = 14
    public static let storeTileLineGap: CGFloat = 4
    public static let storeTileGap: CGFloat = 12
    public static let storePreviewWidth: CGFloat = 240
    public static let storePreviewHeight: CGFloat = 84
    public static let storeRowWidth: CGFloat = 580
    public static let storeTryWidth: CGFloat = 460
    public static let storeSheetPreviewHeight: CGFloat = 320
    public static let storePreviewIcon: CGFloat = 56
    public static let storeActionWidth: CGFloat = 84
    public static let storeReadWidth: CGFloat = 520
    public static let storeMarkGap: CGFloat = 2
    public static let storeMarkPadding: CGFloat = 6
    public static let storeTrustTitleWidth: CGFloat = 110
    public static let storeMediaHeight: CGFloat = 240
}
