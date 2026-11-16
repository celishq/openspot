import OpenspotCore
import SwiftUI

struct SpotFieldView: View {
    static let rect = CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)

    let model: SpotsModel
    let isOpen: Bool
    let isInSheet: Bool
    let isInstall: Bool
    let showsField: Bool
    let surfaceIsOut: Bool
    var sheet: (morph: SheetMorph, cardRadius: CGFloat)?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            searchField
                .morph(showsField ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
                .allowsHitTesting(showsField && !model.isEditing)
            promptLayer
                .modifier(SpotFaded())
                .opacity(model.isEditing ? MotionTokens.hiddenOpacity : 1)
            editHeader
                .modifier(SpotFaded())
                .opacity(model.isEditing ? 1 : MotionTokens.hiddenOpacity)
                .allowsHitTesting(model.isEditing)
        }
        .modifier(FieldDim(isDim: model.dimsField))
        .modifier(SpotMenuDim(model: model, index: nil))
        .background(SpotFieldFocus(model: model, isFocused: $isFocused))
    }

    private var searchField: some View {
        let place = isInSheet ? Self.sheetRow : Self.rect
        let top = isInSheet ? Self.sheetTop : SpotTokens.halo
        let glyphLeft = isInSheet ? Self.sheetGlyphLeft : SpotTokens.halo + SpotTokens.padding
        return ZStack(alignment: .topLeading) {
            SpotSurface(rect: place, radius: fieldRadius, glass: isInstall ? 0 : 1, cut: sheetShape)
            SpotSurfaceShape(rect: place, radius: fieldRadius)
                .fill(SpotTheme.ink.opacity(isInSheet ? SpotTheme.fill : 0))
                .mask { insideSheet }
            ZStack(alignment: .topLeading) {
                SpotFieldPrompt.glyph
                    .offset(x: glyphLeft, y: top)
                searchText
                    .frame(width: Self.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                    .offset(x: fieldTextLeft, y: top)
                SpotSlashMark(model: model)
                    .frame(width: Self.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                    .offset(x: fieldTextLeft, y: top)
                    .allowsHitTesting(false)
            }
            .morph(progress, opacity: crossing)
            .modifier(SpotFaded())
            .opacity(model.showsFieldDrop || model.isEditing ? MotionTokens.hiddenOpacity : 1)
            .allowsHitTesting(!model.showsFieldDrop)
            .modifier(SpotShownFade(isShown: model.isShown))
            if let drop = model.fieldDrop {
                SpotDropView(drop: drop)
                    .padding(.horizontal, SpotTokens.padding)
                    .frame(width: Self.rect.width, height: Self.rect.height)
                    .offset(x: Self.rect.minX, y: Self.rect.minY)
                    .opacity(model.showsFieldDrop ? 1 : MotionTokens.hiddenOpacity)
                    .allowsHitTesting(model.showsFieldDrop)
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.glassInk)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .animation(SpotMotion.fade(isShown: model.isShown)) {
            $0.scaleEffect(model.isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: UnitPoint.center.x, y: Self.rect.midY / SpotTokens.panelHeight))
        }
    }

    private var editHeader: some View {
        HStack {
            Text("Edit Spots")
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.ink)
            Spacer()
            SpotRoundButton(symbol: "sidebar.left", label: "Left Panel", look: model.panels[.left] ? .strong : .plain) {
                model.show(.left, !model.panels[.left])
            }
            SpotRoundButton(symbol: "sidebar.right", label: "Right Panel", look: model.panels[.right] ? .strong : .plain) {
                model.show(.right, !model.panels[.right])
            }
            SpotRoundButton(symbol: "checkmark", label: "Done", look: .strong) { model.endEditing() }
        }
        .padding(.leading, SpotTokens.padding + SpotTokens.glyphInset)
        .padding(.trailing, SpotTokens.padding)
        .frame(width: Self.rect.width, height: Self.rect.height)
        .offset(x: Self.rect.minX, y: Self.rect.minY)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }

    static let sheetRow = CGRect(
        x: SpotTokens.halo + SpotTokens.padding,
        y: SpotTokens.halo + SpotTokens.sheetFieldDrop,
        width: SpotTokens.gridWidth - 2 * SpotTokens.padding,
        height: SpotTokens.listRowHeight
    )
    static let sheetTop = SpotTokens.halo + SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2
    static let sheetGlyphLeft = SpotTokens.halo + 2 * SpotTokens.padding + (SpotTokens.listIconSize - SpotTokens.glyphSize) / 2
    static let sheetTextLeft = SpotTokens.halo + 2 * SpotTokens.padding + SpotTokens.listIconSize + SpotTokens.fieldTextGap
    static let sheetRadius = SurfaceEdge.sheet.inner().radius
    static let fieldTextWidth = SpotTokens.gridWidth - 4 * SpotTokens.padding - SpotTokens.listIconSize - SpotTokens.fieldTextGap

    private var fieldTextLeft: CGFloat {
        isInSheet ? Self.sheetTextLeft : SpotTokens.halo + SpotTokens.padding + SpotTokens.glyphSize + SpotTokens.fieldTextGap
    }

    private var searchText: some View {
            SpotSearchText(model: model, title: "\(SearchPrompt.verb) \(isOpen ? sheetWord : SearchPrompt.grid)")
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { _ = model.handleSearchKey(ActionKey(name: "return")) }
                .onKeyPress(keys: [.downArrow, .upArrow, .leftArrow, .rightArrow]) { press in
                    if (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true { return .ignored }
                    let name = press.key == .downArrow ? "down" : press.key == .upArrow ? "up" : press.key == .leftArrow ? "left" : "right"
                    return model.handleSearchKey(ActionKey(name: name, isCommand: press.modifiers.contains(.command))) ? .handled : .ignored
                }
    }

    private var promptLayer: some View {
        let top = isInSheet ? Self.sheetTop : SpotTokens.halo
        let left = fieldTextLeft
        return promptWords
            .frame(height: SpotTokens.rowHeight)
            .offset(x: left, y: top)
            .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .morph(showsField ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
            .modifier(SpotShownFade(
                isShown: model.isShown,
                hiddenScale: MotionTokens.hiddenScale,
                anchor: UnitPoint(x: UnitPoint.center.x, y: (SpotTokens.halo + SpotTokens.rowHeight / 2) / SpotTokens.panelHeight)
            ))
            .allowsHitTesting(false)
    }

    private var promptWords: some View {
        SpotFieldPrompt(word: sheetWord, progress: progress)
            .morph(progress, opacity: crossing)
        .modifier(SpotEmptyField(model: model, isHidden: model.showsFieldDrop))
    }

    private var sheetWord: String {
        let id = model.transition.id
        return SearchPrompt.word(for: model.sheetEntry(id)?.state.title ?? "")
    }

    private var progress: Double {
        isOpen ? 1 : 0
    }

    private var crossing: (Double) -> Double {
        guard let morph = sheet?.morph else { return { _ in 1 } }
        let header = CGRect(x: SpotTokens.padding, y: SpotTokens.padding, width: SpotTokens.gridWidth - 2 * SpotTokens.padding, height: SpotTokens.glyphSize)
        let line = SpotType.inputLine
        let rest = SpotTokens.halo + (SpotTokens.rowHeight - line) / 2
        let drop = SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2
        return { progress in
            let words = CGRect(x: SpotTokens.halo, y: rest + drop * CGFloat(progress), width: SpotTokens.gridWidth, height: line)
            return morph.crossing(of: words, header: header, at: progress)
        }
    }

    private var sheetShape: SpotSurfaceShape? {
        sheet.map { isOpen ? SpotSurfaceShape(rect: $0.morph.sheet, radius: SpotTokens.radius) : SpotSurfaceShape(rect: $0.morph.card, radius: $0.cardRadius) }
    }

    @ViewBuilder
    private var insideSheet: some View {
        if let sheetShape {
            sheetShape.fill(SpotTheme.mask)
        } else {
            SpotTheme.mask
        }
    }

    private var fieldRadius: CGFloat {
        isInSheet ? Self.sheetRadius : SurfaceEdge(card: .strip).radius
    }

}

private struct FieldDim: ViewModifier {
    let isDim: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.spotFade, isDim ? SpotTheme.unfocusedCardStrength : 1)
            .animation(SpotMotion.grow(isOpen: isDim), value: isDim)
    }
}
