import OpenspotCore
import SwiftUI

struct NodeChoice: View {
    let node: ViewNode
    let look: SpotPart.Look?
    @Environment(\.spotNode) private var context

    var body: some View {
        if let part = context.host.part(of: node) {
            let host = context.host
            NodePartFrame(node: node, part: part, look: look) { size in
                ChoiceDrawing(part: part, look: look, size: size, isCard: context.isCard, call: context.call(of: part), keepsIconColumn: context.keepsIconColumn(part), menuOpening: { host.menuOpening }) { context.set(part, to: $0) }
            }
        }
    }
}

private struct ChoiceDrawing: View {
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    let isCard: Bool
    let call: ScriptCall?
    let keepsIconColumn: Bool
    let menuOpening: () -> SheetParts.MenuOpening?
    let onSet: (String) -> Void
    @Environment(\.spotSurfaceEdge) private var surface

    var body: some View {
        if isCard {
            card
        } else {
            sheet
        }
    }

    @ViewBuilder
    private var card: some View {
        switch part.control {
        case .menu(let options, let value), .list(let options, let value):
            Menu(options.first { $0.id == value }?.title ?? part.title ?? "") {
                ForEach(options, id: \.id) { option in
                    Button(option.title) { onSet(option.id) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        default:
            NodeWords(part: part)
        }
    }

    @ViewBuilder
    private var sheet: some View {
        switch part.control {
        case .swatches(let colors, let value) where colors.count > 1:
            HStack(spacing: SpotTokens.partLineGap) {
                mark
                swatches(colors, value: value)
            }
        case .list(let items, let value):
            list(items, value: value)
                .overlay(alignment: .topTrailing) { mark.padding(SpotTokens.controlPadding) }
        case .menu(let options, _) where options.isEmpty:
            NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {
                SpotWorkMark(call: nil, side: SpotTokens.workMark)
            }
            .modifier(NodeTile(isOn: look == .tile))
        case .menu(let options, let value):
            NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {
                menu(options, value: value)
            }
            .modifier(NodeTile(isOn: look == .tile))
        case .swatches(let colors, let value):
            NodeLine(part: part, size: size, call: call, keepsIconColumn: keepsIconColumn) {
                if let color = colors.first {
                    swatch(color, isChosen: color == value, size: SpotTokens.smallSwatch)
                }
            }
            .modifier(NodeTile(isOn: look == .tile))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var mark: some View {
        if let call {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
        }
    }

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    private func menu(_ options: [SpotPart.Option], value: String?) -> some View {
        let chosen = options.first { $0.id == value } ?? options.first
        return HStack(spacing: SpotTokens.partLineGap) {
            if let icon = chosen?.icon {
                SpotAttachmentCard(look: AttachmentChip.Look(icon))
                    .scaleEffect(SpotTokens.choiceCardScale)
                    .frame(width: SpotTokens.choiceCard, height: SpotTokens.choiceCard)
            }
            HStack(spacing: SpotTokens.choiceChevronGap) {
                Text(chosen?.title ?? "")
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(SpotType.mark)
                    .modifier(SpotSecondaryText())
            }
        }
        .fixedSize()
        .task(id: options) { await SpotChoiceMenu.prepare(options) }
        .accessibilityHidden(true)
        .overlay {
            GeometryReader { room in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { popUp(options, value: value, over: room.frame(in: .global)) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(part.title ?? part.id)
                    .accessibilityValue(options.first { $0.id == value }?.title ?? "")
                    .accessibilityAction { popUp(options, value: value, over: room.frame(in: .global)) }
                    .onChange(of: menuOpening()) { _, opening in
                        guard opening?.part == part.id else { return }
                        let rect = room.frame(in: .global)
                        DispatchQueue.main.async { popUp(options, value: value, over: rect) }
                    }
            }
        }
    }

    private func popUp(_ options: [SpotPart.Option], value: String?, over rect: CGRect) {
        SpotChoiceMenu.popUp(options: options, value: value, over: rect) { onSet($0) }
    }

    private func swatches(_ colors: [String], value: String?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                if index > 0 { Spacer(minLength: 0) }
                swatch(color, isChosen: color == value, size: SpotTokens.swatchSize)
            }
        }
    }

    private func swatch(_ color: String, isChosen: Bool, size: CGFloat) -> some View {
        Button { onSet(color) } label: {
            Circle()
                .fill(SpotColorBar.color(color))
                .frame(width: size, height: size)
                .overlay {
                    if isChosen { Circle().strokeBorder(SpotTheme.ink, lineWidth: SpotTokens.ring) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color)
    }

    private func list(_ items: [SpotPart.Option], value: String?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpotTokens.listRowGap) {
                ForEach(items, id: \.id) { item in
                    Button { onSet(item.id) } label: {
                        Text(item.title)
                            .font(SpotType.body)
                            .foregroundStyle(SpotTheme.ink)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, SpotTokens.controlPadding)
                            .frame(height: SpotTokens.listRow)
                            .background(SpotTheme.ink.opacity(item.id == value ? SpotTheme.selectedFill : 0), in: shape)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
