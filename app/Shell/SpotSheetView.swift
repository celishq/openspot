import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    let list: ItemList
    let onRun: (SpotItem) -> Void
    let onClose: () -> Void
    @State private var edges = SpotScrollEdges()

    private static let bottomFade = 2 * SpotTokens.padding

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding - 5) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(Color.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.state.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    if let subtitle = entry.state.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .modifier(SpotSecondaryText())
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Color.clear.frame(height: SpotTokens.listRowHeight)
            if list.shown.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13, weight: .medium))
                    .modifier(SpotSecondaryText())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rows
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: SpotTokens.sheetRect.width, height: SpotTokens.sheetRect.height, alignment: .topLeading)
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        return list.search == .live && list.query.isEmpty ? "Type to search" : "No results"
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: SpotTokens.listRowGap) {
                    ForEach(Array(list.shown.enumerated()), id: \.element.run) { index, item in
                        Button {
                            onRun(item)
                        } label: {
                            rowLabel(item, isSelected: index == list.selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .safeAreaPadding(.top, SpotTokens.padding)
            .safeAreaPadding(.bottom, Self.bottomFade)
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edgeFade)
            .padding(.vertical, -SpotTokens.padding)
            .onChange(of: list.selectedItem?.run) { _, run in
                if let run { proxy.scrollTo(run) }
            }
            .onChange(of: list.query) {
                guard let run = list.shown.first?.run else { return }
                DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
            }
        }
    }

    private var edgeFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(1 - edges.top), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: SpotTokens.padding)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.bottomFade)
        }
    }

    private func rowLabel(_ item: SpotItem, isSelected: Bool) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(Color.white.opacity(isSelected ? 0.3 : 0.12), in: row)
        .contentShape(row)
    }
}
