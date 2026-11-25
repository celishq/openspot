import OpenspotCore
import SwiftUI

struct NodeButton: View {
    let node: ViewNode
    let look: SpotPart.Look?
    var label: AnyView?
    @Environment(\.spotNode) private var context
    @Environment(\.spotSurfaceEdge) private var surface

    var body: some View {
        if let part = context.host.part(of: node) {
            NodePartFrame(node: node, part: part, look: look, hasLabel: label != nil) { size in
                if let label {
                    Button { context.press(part) } label: {
                        if context.isCard {
                            label
                        } else {
                            label
                                .spotHover(in: SpotRoundShape(surface.inner()))
                                .contentShape(SpotRoundShape(surface.inner()))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    ButtonDrawing(part: part, look: look, size: size, isCard: context.isCard, call: context.call(of: part), keepsIconColumn: context.keepsIconColumn(part)) { context.press(part) }
                }
            }
        }
    }
}

private struct ButtonDrawing: View {
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    let isCard: Bool
    let call: ScriptCall?
    let keepsIconColumn: Bool
    let onPress: () -> Void
    @Environment(\.spotSurfaceEdge) private var surface
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        switch part.press {
        case .round(let icon) where isCard:
            Button(action: onPress) {
                NodeIcon(icon: icon, side: SpotTokens.slotButton / 2)
                    .font(SpotType.body.weight(.semibold))
                    .foregroundStyle(ink)
                    .frame(width: SpotTokens.slotButton, height: SpotTokens.slotButton)
                    .background(ink.opacity(look == .bare ? 0 : SpotTheme.chip), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(part.title ?? part.spoken ?? part.id.capitalized)
        case .round(let icon):
            NodeLine(part: part, size: size, call: call, keepsIconColumn: look != .bare && keepsIconColumn) {
                SpotRoundButton(
                    icon: icon,
                    label: part.title ?? part.spoken ?? part.id.capitalized,
                    act: call,
                    size: min(size.width, size.height, SpotTokens.partMaxRound),
                    look: look == .strong ? .strong : look == .bare ? .bare : .plain,
                    action: onPress
                )
            }
            .modifier(NodeTile(isOn: look == .tile))
        case .line where isCard:
            Button(action: onPress) {
                Text(part.title ?? part.id.capitalized)
                    .font(SpotType.action)
                    .foregroundStyle(ink)
                    .padding(.horizontal, SpotTokens.slotChipPaddingX)
                    .padding(.vertical, SpotTokens.chipPaddingY)
                    .background(ink.opacity(SpotTheme.chip), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .line:
            Button(action: onPress) { sheetLabel }
                .buttonStyle(.plain)
        case .none:
            NodeWords(part: part)
        }
    }

    private var ink: Color {
        SpotTheme.ink(onSolid: isOnSolid)
    }

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    @ViewBuilder
    private var sheetLabel: some View {
        switch look {
        case .chip:
            words(part.title ?? part.id, font: SpotType.action)
                .padding(.horizontal, SpotTokens.padding)
                .padding(.vertical, SpotTokens.chipPaddingY)
                .fixedSize()
                .spotFill(isActive: call != nil, otherwise: SpotTheme.ink.opacity(SpotTheme.selectedFill), in: Capsule())
                .spotHover(isOnSolid: call != nil, in: Capsule())
                .contentShape(Capsule())
        case .bare:
            HStack {
                NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {}
                if part.detail == nil, let key = part.key {
                    Text(key.label).font(SpotType.detail).modifier(SpotSecondaryText())
                }
            }
            .contentShape(Rectangle())
        case .strong:
            centered(isActive: true)
        case .tile:
            NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {}
                .modifier(NodeTile(isOn: true))
                .spotHover(in: shape)
                .contentShape(shape)
        default:
            centered(isActive: call != nil)
        }
    }

    @ViewBuilder
    private func words(_ words: String, font: Font) -> some View {
        if let call, let title = call.title {
            SpotShine(words: title, font: font)
        } else if let call {
            HStack(spacing: SpotTokens.placeGap / 2) {
                SpotWorkMark(call: call, side: SpotTokens.workMark)
                Text("Stop").font(font).lineLimit(1)
            }
        } else if let icon = part.icon {
            HStack(spacing: SpotTokens.placeGap / 2) {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                if let title = part.title { Text(title).lineLimit(1) }
            }
            .font(font)
        } else {
            Text(words).font(font).lineLimit(1)
        }
    }

    @ViewBuilder
    private func keyed(_ title: some View) -> some View {
        if let key = part.key {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SpotTokens.placeGap / 2) {
                    SpotButtonKey(label: key.label).hidden()
                    title.frame(maxWidth: .infinity)
                    SpotButtonKey(label: key.label)
                }
                HStack(spacing: SpotTokens.placeGap / 2) {
                    title.frame(maxWidth: .infinity)
                    SpotButtonKey(label: key.label)
                }
                title.frame(maxWidth: .infinity)
            }
        } else {
            title.frame(maxWidth: .infinity)
        }
    }

    private func centered(isActive: Bool) -> some View {
        keyed(words(part.title ?? part.id.capitalized, font: SpotType.body.weight(.medium)))
            .padding(.horizontal, SpotTokens.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .spotFill(isActive: isActive, otherwise: SpotTheme.ink.opacity(SpotTheme.selectedFill), in: shape)
            .spotHover(isOnSolid: isActive, in: shape)
            .contentShape(shape)
    }
}
