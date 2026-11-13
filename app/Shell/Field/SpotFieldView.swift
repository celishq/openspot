import OpenspotCore
import SwiftUI

/// The search field and the words it shows while empty. It grows from its place at rest into its row in an open sheet: its
/// glass grows by a shape, and its glyph and its words keep one size and move by offsets alone. It takes the focus when the
/// panel shows with a search, and gives it up when the panel hides.
struct SpotFieldView: View {
    /// Where the field lies at rest. The install screen grows out of it and collapses into it.
    static let rect = CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
    private static let gap: CGFloat = 8

    let model: SpotsModel
    /// Whether a sheet is open or on its way there.
    let isOpen: Bool
    /// Whether the field lies in the open sheet.
    let isInSheet: Bool
    /// Whether the sheet is the install screen, which grows out of the field and has no header for the words to cross.
    let isInstall: Bool
    /// Whether the field is drawn. A form, a sheet of parts and the install screen replace it.
    let showsField: Bool
    /// Whether a sheet is out or a drop is taken, which sets the time of each fade.
    let surfaceIsOut: Bool
    /// The sheet that is built, from its card to its open place, which holds the field's row while the field lies in it,
    /// and the radius of its card. Nil with no sheet with a card, or for the install screen, which grows out of the field.
    var sheet: (morph: SheetMorph, cardRadius: CGFloat)?
    @FocusState private var isFocused: Bool
    @Environment(\.spotPanelWidth) private var panelWidth

    var body: some View {
        ZStack(alignment: .topLeading) {
            searchField
                .morph(showsField ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
                .allowsHitTesting(showsField && !model.isEditing)
            promptLayer
                .opacity(model.isEditing ? 0 : 1)
            editHeader
                .opacity(model.isEditing ? 1 : 0)
                .allowsHitTesting(model.isEditing)
        }
        .modifier(SpotFocusLook(focus: model.isMenuOpen ? .faded : .none))
        .background(SpotFieldFocus(model: model, isFocused: $isFocused))
    }

    private var searchField: some View {
        let place = isInSheet ? fieldRowRect : Self.rect
        let top = SpotTokens.halo + (isInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let glyphLeft = SpotTokens.halo + SpotTokens.padding + (isInSheet ? sheetShift + SpotTokens.padding + (SpotTokens.listIconSize - SpotTokens.glyphSize) / 2 : 0)
        return ZStack(alignment: .topLeading) {
            SpotSurface(rect: place, radius: fieldRadius, glass: isInSheet || isInstall ? 0 : 1)
                .mask { outsideSheet }
            SpotSurfaceShape(rect: place, radius: fieldRadius)
                .fill(SpotTheme.ink.opacity(SpotTheme.fill * (isInSheet ? 1 : 0)))
                .mask { insideSheet }
            ZStack(alignment: .topLeading) {
                Image(systemName: "magnifyingglass")
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.rowHeight)
                    .offset(x: glyphLeft, y: top)
                searchText
                    .frame(width: Self.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                    .offset(x: fieldTextLeft, y: top)
            }
            .morph(progress, opacity: crossing)
            .opacity(model.showsFieldDrop || model.isEditing ? 0 : 1)
            .modifier(SpotShownFade(isShown: model.isShown))
            if let drop = model.fieldDrop {
                SpotDropView(drop: drop)
                    .padding(.horizontal, SpotTokens.padding)
                    .frame(width: Self.rect.width, height: Self.rect.height)
                    .offset(x: Self.rect.minX, y: Self.rect.minY)
                    .opacity(model.showsFieldDrop ? 1 : 0)
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink)
        .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .animation(SpotMotion.fade(isShown: model.isShown)) {
            $0.scaleEffect(model.isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: Self.rect.midX / panelWidth, y: Self.rect.midY / SpotTokens.panelHeight))
        }
    }

    /// The words of Edit Spots and its Done button, on the field's glass in the place of the search.
    private var editHeader: some View {
        HStack {
            Text("Edit Spots")
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.ink)
            Spacer()
            SpotRoundButton(symbol: "checkmark", label: "Done", look: .strong) { model.endEditing() }
        }
        .padding(.leading, SpotTokens.padding + SpotTokens.glyphInset)
        .padding(.trailing, SpotTokens.padding)
        .frame(width: Self.rect.width, height: Self.rect.height)
        .offset(x: Self.rect.minX, y: Self.rect.minY)
        .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }

    /// The field's row in an open sheet.
    private var fieldRowRect: CGRect {
        CGRect(
            x: SpotTokens.halo + sheetShift + SpotTokens.padding,
            y: SpotTokens.halo + SpotTokens.sheetFieldDrop,
            width: SpotTokens.gridWidth - 2 * SpotTokens.padding,
            height: SpotTokens.listRowHeight
        )
    }

    /// How far right of the field's place at rest the open sheet lies, on a wide grid.
    private var sheetShift: CGFloat {
        (sheet?.morph.sheet.minX ?? SpotTokens.halo) - SpotTokens.halo
    }

    /// The width of the field's words, as narrow as its row in a sheet, so that it stays one size.
    private static let fieldTextWidth = SpotTokens.gridWidth - 4 * SpotTokens.padding - SpotTokens.listIconSize - gap

    /// Where the field's words start, at rest and in a sheet.
    private var fieldTextLeft: CGFloat {
        isInSheet
            ? SpotTokens.halo + sheetShift + 2 * SpotTokens.padding + SpotTokens.listIconSize + Self.gap
            : SpotTokens.halo + SpotTokens.padding + SpotTokens.glyphSize + Self.gap
    }

    private var searchText: some View {
            SpotSearchText(model: model, title: "\(SearchPrompt.verb) \(isOpen ? sheetWord : SearchPrompt.grid)")
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { model.runSelected() }
                .onKeyPress(keys: [.downArrow]) { press in
                    if model.openList != nil, press.modifiers.contains(.command) {
                        model.moveItemToEdge(last: true)
                    } else if model.openList != nil {
                        model.moveItemLine(by: 1)
                    } else {
                        model.moveSelection(dx: 0, dy: 1)
                    }
                    return .handled
                }
                .onKeyPress(keys: [.upArrow]) { press in
                    if model.openList != nil, press.modifiers.contains(.command) {
                        model.moveItemToEdge(last: false)
                    } else if model.openList != nil {
                        model.moveItemLine(by: -1)
                    } else {
                        model.moveSelection(dx: 0, dy: -1)
                    }
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    if model.openList != nil {
                        guard (model.openItems?.perLine ?? 1) > 1 else { return .ignored }
                        model.moveItem(by: -1)
                        return .handled
                    }
                    if !model.query.isEmpty { return .ignored }
                    if model.selectedIsSlider {
                        model.adjustSelected(by: -5)
                    } else {
                        model.moveSelection(dx: -1, dy: 0)
                    }
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if model.openList != nil {
                        guard (model.openItems?.perLine ?? 1) > 1 else { return .ignored }
                        model.moveItem(by: 1)
                        return .handled
                    }
                    if !model.query.isEmpty { return .ignored }
                    if model.selectedIsSlider {
                        model.adjustSelected(by: 5)
                    } else {
                        model.moveSelection(dx: 1, dy: 0)
                    }
                    return .handled
                }
                .onKeyPress(keys: [.return]) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.openBigView()
                    return .handled
                }
    }

    /// The empty field's words, as a layer of their own that moves with the field by offsets alone, which stay smooth where
    /// layout rounds to whole pixels.
    private var promptLayer: some View {
        let top = SpotTokens.halo + (isInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let left = fieldTextLeft
        return promptWords
            .frame(height: SpotTokens.rowHeight)
            .offset(x: left, y: top)
            .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .morph(showsField ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
            .modifier(SpotShownFade(
                isShown: model.isShown,
                hiddenScale: MotionTokens.hiddenScale,
                anchor: UnitPoint(x: Self.rect.midX / panelWidth, y: (SpotTokens.halo + SpotTokens.rowHeight / 2) / SpotTokens.panelHeight)
            ))
            .allowsHitTesting(false)
    }

    /// One line on one path: the first word stays, and the last fades into the other in its place.
    private var promptWords: some View {
        HStack(spacing: 0) {
            Text("\(SearchPrompt.verb) ")
            ZStack(alignment: .leading) {
                Text(SearchPrompt.grid)
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
                Text(sheetWord)
                    .morph(progress, opacity: SheetMorph.sheetLook(at:))
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        .lineLimit(1)
        .morph(progress, opacity: crossing)
        .modifier(SpotEmptyField(model: model, isHidden: model.showsFieldDrop))
    }

    /// The last word of the prompt in the open sheet, from its spot's title. It is read here, so that a new title reruns
    /// the field and not the panel.
    private var sheetWord: String {
        let id = model.transition.id
        return SearchPrompt.word(for: model.entries.first { $0.id == id }?.state.title ?? "")
    }

    /// How far the sheet is open, which the sheet's motion carries from 0 to 1.
    private var progress: Double {
        isOpen ? 1 : 0
    }

    /// How strongly the field's words show as they pass the sheet's header: none while they lie across it. With no sheet,
    /// as for the install screen, they pass no header.
    private var crossing: (Double) -> Double {
        guard let morph = sheet?.morph else { return { _ in 1 } }
        let header = CGRect(x: SpotTokens.padding, y: SpotTokens.padding, width: SpotTokens.gridWidth - 2 * SpotTokens.padding, height: SpotTokens.glyphSize)
        let line = SpotType.inputLine
        let rest = SpotTokens.halo + (SpotTokens.rowHeight - line) / 2
        let drop = SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2
        let shift = sheetShift
        return { progress in
            let words = CGRect(x: SpotTokens.halo + shift * CGFloat(progress), y: rest + drop * CGFloat(progress), width: SpotTokens.gridWidth, height: line)
            return morph.crossing(of: words, header: header, at: progress)
        }
    }

    /// The sheet's shape now: on its card until it opens.
    private var sheetShape: SpotSurfaceShape? {
        sheet.map { isOpen ? SpotSurfaceShape(rect: $0.morph.sheet, radius: SpotTokens.radius) : SpotSurfaceShape(rect: $0.morph.card, radius: $0.cardRadius) }
    }

    /// The panel but the sheet, where the field's glass shows, so that one glass lies under the field where it meets the sheet.
    @ViewBuilder
    private var outsideSheet: some View {
        if let sheetShape {
            SpotOutsideShape(inner: sheetShape).fill(style: FillStyle(eoFill: true))
        } else {
            Color.black
        }
    }

    /// The sheet, where the field's row shows, so that the row never lies outside the sheet's edge.
    @ViewBuilder
    private var insideSheet: some View {
        if let sheetShape {
            sheetShape.fill(Color.black)
        } else {
            Color.black
        }
    }

    private var fieldRadius: CGFloat {
        isInSheet ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

}
