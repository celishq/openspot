import OpenspotCore
import SwiftUI

struct SpotFieldView: View {
    static let rect = CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
    private static let gap: CGFloat = 8

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
        let glyphLeft = SpotTokens.halo + SpotTokens.padding + (isInSheet ? SpotTokens.padding + (SpotTokens.listIconSize - SpotTokens.glyphSize) / 2 : 0)
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
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .animation(SpotMotion.fade(isShown: model.isShown)) {
            $0.scaleEffect(model.isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: 0.5, y: Self.rect.midY / SpotTokens.panelHeight))
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

    private var fieldRowRect: CGRect {
        CGRect(
            x: SpotTokens.halo + SpotTokens.padding,
            y: SpotTokens.halo + SpotTokens.sheetFieldDrop,
            width: SpotTokens.gridWidth - 2 * SpotTokens.padding,
            height: SpotTokens.listRowHeight
        )
    }

    private static let fieldTextWidth = SpotTokens.gridWidth - 4 * SpotTokens.padding - SpotTokens.listIconSize - gap

    private var fieldTextLeft: CGFloat {
        isInSheet
            ? SpotTokens.halo + 2 * SpotTokens.padding + SpotTokens.listIconSize + Self.gap
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

    private var promptLayer: some View {
        let top = SpotTokens.halo + (isInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let left = fieldTextLeft
        return promptWords
            .frame(height: SpotTokens.rowHeight)
            .offset(x: left, y: top)
            .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .morph(showsField ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
            .modifier(SpotShownFade(
                isShown: model.isShown,
                hiddenScale: MotionTokens.hiddenScale,
                anchor: UnitPoint(x: 0.5, y: (SpotTokens.halo + SpotTokens.rowHeight / 2) / SpotTokens.panelHeight)
            ))
            .allowsHitTesting(false)
    }

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

    private var sheetWord: String {
        let id = model.transition.id
        return SearchPrompt.word(for: model.entries.first { $0.id == id }?.state.title ?? "")
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
    private var outsideSheet: some View {
        if let sheetShape {
            SpotOutsideShape(inner: sheetShape).fill(style: FillStyle(eoFill: true))
        } else {
            Color.black
        }
    }

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
