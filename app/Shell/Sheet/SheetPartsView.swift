import OpenspotCore
import SwiftUI

struct SheetPartsView: View {
    let panel: SheetParts
    let host: any NodeHost
    @FocusState private var focus: String?
    @Environment(\.spotIsHeld) private var isHeld

    var body: some View {
        tree
        .onAppear(perform: focusSelectedField)
        .modifier(FocusOnShow(focus: focusSelectedField))
        .modifier(FocusOnSelect(selectedID: selectedID, focus: focusSelectedField))
        .onChange(of: host.isSettled) { _, isSettled in
            if isSettled { focusSelectedField() }
        }
        .onChange(of: focus) { _, id in
            if !isHeld, let part = panel.parts.first(where: { $0.id == id }) { host.focus(part) }
        }
    }

    private var tree: some View {
        ScrollView(showsIndicators: false) {
            NodeRoom(height: panel.height, fits: panel.tree.holdsScroll) {
                NodeTree(tree: panel.tree, pictureTimes: panel.pictureTimes)
                    .environment(\.spotNode.host, host)
                    .environment(\.spotNode.panel, panel)
                    .environment(\.spotNode.focus, $focus)
            }
            .padding(SpotTokens.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(SpotArrowScroll(nudge: { [host] in host.nudge }, searches: host.list?.landedSearches ?? 0))
        .frame(width: SpotTokens.partsWidth + 2 * SpotTokens.padding, height: panel.height + 2 * SpotTokens.padding, alignment: .topLeading)
        .padding(-SpotTokens.padding)
    }

    private var selectedID: () -> String? {
        { [host] in host.selectedPart }
    }

    private func focusSelectedField() {
        guard !isHeld, !panel.showsRows, host.isSettled else { return }
        let id = selectedID()
        DispatchQueue.main.async { focus = panel.parts.first { $0.id == id && $0.isEditable }?.id }
    }
}

private struct FocusOnShow: ViewModifier {
    let focus: @MainActor @Sendable () -> Void
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        content.onChange(of: isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeIn, execute: focus) }
        }
    }
}

private struct FocusOnSelect: ViewModifier {
    let selectedID: () -> String?
    let focus: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: selectedID()) { focus() }
    }
}
