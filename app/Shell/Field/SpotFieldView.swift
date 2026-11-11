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
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            searchField
                .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: showsField)) { $0.opacity(showsField ? 1 : 0) }
                .allowsHitTesting(showsField && !model.isEditing)
            promptLayer
                .opacity(model.isEditing ? 0 : 1)
            editHeader
                .opacity(model.isEditing ? 1 : 0)
                .allowsHitTesting(model.isEditing)
        }
        .onChange(of: model.isShown) { _, isShown in
            guard isShown else {
                isFocused = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration) {
                if model.isShown, model.showsSearch, !model.isOpenForDrag { isFocused = true }
            }
        }
        .onChange(of: model.showsSearch) { _, shows in
            isFocused = shows
        }
        .onChange(of: model.menu == nil) { _, isClosed in
            if isClosed, model.isShown, model.showsSearch { isFocused = true }
        }
    }

    private var searchField: some View {
        let place = isInSheet ? fieldRowRect : Self.rect
        let top = SpotTokens.halo + (isInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let glyphLeft = SpotTokens.halo + SpotTokens.padding + (isInSheet ? SpotTokens.padding + (SpotTokens.listIconSize - SpotTokens.glyphSize) / 2 : 0)
        return ZStack(alignment: .topLeading) {
            SpotSurface(rect: place, radius: fieldRadius, glass: isInSheet || isInstall ? 0 : 1, fill: isInSheet ? 1 : 0)
            ZStack(alignment: .topLeading) {
                Image(systemName: "magnifyingglass")
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.rowHeight)
                    .offset(x: glyphLeft, y: top)
                searchText
                    .frame(width: Self.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                    .offset(x: fieldTextLeft, y: top)
            }
            .modifier(SpotFieldCrossing(isOpen: isOpen, crosses: !isInstall))
            .opacity(model.showsFieldDrop || model.isEditing ? 0 : 1)
            .opacity(model.isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
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
        .scaleEffect(model.isShown ? 1 : SpotMotion.hiddenScale, anchor: UnitPoint(x: 0.5, y: Self.rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
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
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: Self.rect.width, height: Self.rect.height)
        .offset(x: Self.rect.minX, y: Self.rect.minY)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }

    /// The field's row in an open sheet.
    private var fieldRowRect: CGRect {
        CGRect(
            x: SpotTokens.halo + SpotTokens.padding,
            y: SpotTokens.halo + SpotTokens.sheetFieldDrop,
            width: SpotTokens.gridWidth - 2 * SpotTokens.padding,
            height: SpotTokens.listRowHeight
        )
    }

    /// The width of the field's words, as narrow as its row in a sheet, so that it stays one size.
    private static let fieldTextWidth = SpotTokens.gridWidth - 4 * SpotTokens.padding - SpotTokens.listIconSize - gap

    /// Where the field's words start, at rest and in a sheet.
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
                .onKeyPress(.downArrow) {
                    if model.openList != nil {
                        model.moveItemLine(by: 1)
                    } else {
                        model.moveSelection(dx: 0, dy: 1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if model.openList != nil {
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
            .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: showsField)) { $0.opacity(showsField ? 1 : 0) }
            .opacity(model.isShown ? 1 : 0)
            .scaleEffect(model.isShown ? 1 : SpotMotion.hiddenScale, anchor: UnitPoint(x: 0.5, y: (SpotTokens.halo + SpotTokens.rowHeight / 2) / SpotTokens.panelHeight))
            .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            .allowsHitTesting(false)
    }

    /// One line on one path: the first word stays, and the last fades into the other in its place.
    private var promptWords: some View {
        HStack(spacing: 0) {
            Text("\(SearchPrompt.verb) ")
            ZStack(alignment: .leading) {
                Text(SearchPrompt.grid)
                    .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: !isOpen)) { $0.opacity(isOpen ? 0 : 1) }
                Text(sheetWord)
                    .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: isOpen)) { $0.opacity(isOpen ? 1 : 0) }
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        .lineLimit(1)
        .modifier(SpotFieldCrossing(isOpen: isOpen, crosses: !isInstall))
        .modifier(SpotEmptyField(model: model, isHidden: model.showsFieldDrop))
    }

    /// The last word of the prompt in the open sheet, from its spot's title. It is read here, so that a new title reruns
    /// the field and not the panel.
    private var sheetWord: String {
        let id = model.transition.id
        return SearchPrompt.word(for: model.entries.first { $0.id == id }?.state.title ?? "")
    }

    private var fieldRadius: CGFloat {
        isInSheet ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

}
