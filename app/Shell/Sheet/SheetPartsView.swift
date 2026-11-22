import AppKit
import OpenspotCore
import SwiftUI

struct SheetPartsView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let panel: SheetParts
    var act: (SpotPart) -> ScriptCall? = { _ in nil }
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    var recordingPart: String?
    var onRecord: (SpotPart) -> Void = { _ in }
    var keys: KeyRecording?
    var list = ItemList()
    var onRun: (SpotItem) -> Void = { _ in }
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var selection: (() -> Int)?
    var selectedPart: (() -> String?)?
    var nudge: () -> SheetParts.Nudge = { SheetParts.Nudge.rest }
    var menuOpening: () -> SheetParts.MenuOpening? = { nil }
    var onFocus: (SpotPart) -> Void = { _ in }
    @FocusState private var focus: String?
    @Environment(\.spotIsHeld) private var isHeld

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        tree
        .onAppear(perform: focusSelectedField)
        .modifier(FocusOnShow(focus: focusSelectedField))
        .modifier(FocusOnSelect(selectedID: selectedID, focus: focusSelectedField))
        .onChange(of: focus) { _, id in
            if !isHeld, let part = panel.parts.first(where: { $0.id == id }) { onFocus(part) }
        }
    }

    private var send: (String, String) -> Void {
        let tree = panel.tree
        let onSet = onSet
        return { id, value in
            if let part = tree.node(id)?.part { onSet(part, value) }
        }
    }

    private var tree: some View {
        ScrollView(showsIndicators: false) {
            NodeRoom(height: panel.height) {
                NodeTree(tree: panel.tree, pictureTimes: panel.pictureTimes)
                    .environment(\.spotNodeParts, nodeParts)
                    .environment(\.spotNodeSend, send)
                    .environment(\.spotNodeSelection, selectedID)
                    .environment(\.spotNodeViewInput, NodeViewInput(items: panel.rows, answers: panel.answered, selection: selectedRun))
            }
            .padding(SpotTokens.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(SpotArrowScroll(nudge: nudge, searches: list.landedSearches))
        .frame(width: SpotTokens.partsWidth + 2 * SpotTokens.padding, height: panel.height + 2 * SpotTokens.padding, alignment: .topLeading)
        .padding(-SpotTokens.padding)
    }

    private var nodeParts: NodeParts {
        NodeParts(
            part: { node, label, look in
                guard let part = node.part else { return AnyView(EmptyView()) }
                return AnyView(nodePart(node.kind, part, look, label: label, size: node.naturalSize))
            },
            items: { room in
                AnyView(SpotItemsView(list: list, onRun: onRun, selection: selection, onDragOut: onDragOut, room: room))
            }
        )
    }

    @ViewBuilder
    private func nodePart(_ kind: String, _ part: SpotPart, _ look: SpotPart.Look?, label: AnyView?, size natural: CGSize) -> some View {
        let height = natural.height
        let size = CGSize(width: SpotTokens.partsWidth, height: height)
        Group {
            if let label {
                Button { onPress(part) } label: {
                    label
                        .spotHover(in: shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
            } else if part.fillsHeight {
                GeometryReader { room in
                    content(kind, part, look, room.size)
                }
                .frame(minHeight: height, idealHeight: height)
                .frame(idealWidth: natural.width)
            } else {
                content(kind, part, look, size)
                    .frame(maxWidth: part.fillsWidth(as: look) ? .infinity : nil, minHeight: height, maxHeight: .infinity, alignment: part.fillsWidth(as: look) ? .leading : .center)
            }
        }
        .background {
            if part.isFocusable {
                Color.clear.modifier(PartRing(id: part.id, selectedID: selectedID, hasBox: label != nil || hasBox(part, look), shape: shape))
            }
        }
    }

    private var selectedRun: () -> String? {
        { [list, selection] in list.run(at: (selection ?? { list.selected })()) }
    }

    private var selectedID: () -> String? {
        selectedPart ?? { [panel] in panel.selectedPart?.id }
    }

    private func hasBox(_ part: SpotPart, _ look: SpotPart.Look?) -> Bool {
        if part.isEditable || look == .tile { return true }
        guard part.press == .line else { return false }
        return switch look {
        case .chip, .bare: false
        default: true
        }
    }

    private func focusSelectedField() {
        guard !isHeld, !panel.showsRows else { return }
        let id = selectedID()
        DispatchQueue.main.async { focus = panel.parts.first { $0.id == id && $0.isEditable }?.id }
    }

    private func content(_ kind: String, _ part: SpotPart, _ look: SpotPart.Look?, _ size: CGSize) -> some View {
        NodeControl(kind: kind, part: part, look: look, size: size, call: act(part), keepsIconColumn: panel.keepsIconColumn(part), recordingPart: recordingPart, keys: keys, focus: $focus, menuOpening: menuOpening, onSet: onSet, onPress: onPress, onRecord: onRecord)
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

private struct PartRing: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let id: String
    let selectedID: () -> String?
    let hasBox: Bool
    let shape: SpotRoundShape

    func body(content: Content) -> some View {
        let isSelected = selectedID() == id
        if hasBox {
            let gap = SpotTokens.focusGap
            let ring = SpotRoundShape(surface.inner(by: SpotTokens.padding - gap))
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: ring)).padding(-gap)
        } else {
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: shape)).padding(.horizontal, -SpotTokens.controlPadding)
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
