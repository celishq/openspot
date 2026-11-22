import OpenspotCore
import SwiftUI

struct NodeSwitch: View {
    let node: ViewNode
    let look: SpotPart.Look?
    @Environment(\.spotNode) private var context

    var body: some View {
        if let part = context.actions.part(of: node) {
            NodePartFrame(node: node, part: part, look: look) { size in
                SwitchDrawing(part: part, look: look, size: size, isCard: context.isCard, call: context.call(of: part), keepsIconColumn: context.keepsIconColumn(part)) { context.set(part, to: $0) }
            }
        }
    }
}

private struct SwitchDrawing: View {
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    let isCard: Bool
    let call: ScriptCall?
    let keepsIconColumn: Bool
    let onSet: (String) -> Void
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        if isCard {
            card
        } else {
            NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {
                if part.isTick {
                    SpotTick(isOn: isOn, words: EmptyView(), onPress: set)
                        .fixedSize()
                } else {
                    Toggle(part.title ?? part.id, isOn: Binding(get: { isOn }, set: set))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .tint(SpotTheme.accent)
                }
            }
            .modifier(NodeTile(isOn: look == .tile))
        }
    }

    @ViewBuilder
    private var card: some View {
        if part.isTick {
            SpotTick(isOn: isOn, words: NodeWords(part: part), onPress: set)
        } else {
            ViewThatFits(in: .horizontal) {
                if part.title != nil || part.detail != nil {
                    HStack(spacing: SpotTokens.slotSwitchGap) {
                        HStack(spacing: SpotTokens.wordsGap) {
                            if let icon = part.icon { glyph(icon) }
                            NodeWords(part: part).fixedSize()
                        }
                        Spacer(minLength: 0)
                        toggle
                    }
                }
                toggle
            }
        }
    }

    @ViewBuilder
    private var toggle: some View {
        let toggle = Toggle("", isOn: Binding(get: { isOn }, set: set)).labelsHidden()
        if isOnSolid {
            toggle.toggleStyle(SpotSolidSwitch())
        } else {
            toggle
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(SpotTheme.ink)
        }
    }

    private func glyph(_ icon: Icon) -> some View {
        NodeIcon(icon: icon, side: SpotTokens.glyph)
            .font(SpotType.glyph)
            .foregroundStyle(isOnSolid ? AnyShapeStyle(SpotTheme.glyphOnSolid) : AnyShapeStyle(SpotTheme.glassInk))
            .frame(width: SpotTokens.glyph, height: SpotTokens.glyph)
            .background(SpotTheme.ink.opacity(isOnSolid ? 0 : SpotTheme.disc), in: Circle())
    }

    private var isOn: Bool {
        if case .toggle(let on) = part.control { return on }
        return false
    }

    private func set(_ on: Bool) {
        onSet(on ? "true" : "false")
    }
}
