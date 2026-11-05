import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    let list: ItemList
    let rect: CGRect
    let hint: String
    let form: FormDraft?
    let screen: AnyView?
    let createTitle: String?
    let onCreate: () -> Void
    let onFormValue: (String, String) -> Void
    let onRun: (SpotItem) -> Void
    let onClose: () -> Void
    @State private var edges = SpotScrollEdges()

    private static let bottomFade = 2 * SpotTokens.padding

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: screen == nil ? SpotTokens.rowGap : SpotTokens.formFieldGap) {
            if screen == nil {
                header
            } else {
                screenHeader
            }
            if let screen {
                screen
            } else if let form {
                SpotFormView(draft: form, onValue: onFormValue)
                SpotHint(text: "⌘⏎ Save   Esc Cancel")
            } else {
                Color.clear.frame(height: SpotTokens.listRowHeight)
                if let createTitle {
                    Button(action: onCreate) {
                        createLabel(createTitle)
                    }
                    .buttonStyle(.plain)
                } else if list.shown.isEmpty {
                    Text(emptyText)
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    rows
                }
                SpotHint(text: hint)
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }

    private var header: some View {
            HStack(spacing: SpotTokens.padding - 5) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(Color.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(form?.form.title ?? entry.state.title)
                        .font(SpotType.title)
                        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    if form == nil, let subtitle = entry.state.subtitle {
                        Text(subtitle)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                            .lineLimit(1)
                    }
                }
                Spacer()
                SpotRoundButton(symbol: "xmark", label: "Close", action: onClose)
            }
    }

    /// The smaller header of a screen of its own, which leaves its room to the screen.
    private var screenHeader: some View {
        HStack {
            Text(entry.state.title)
                .font(SpotType.title)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            Spacer()
            SpotRoundButton(symbol: "xmark", label: "Close", action: onClose)
        }
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        if list.isLoading { return "Loading…" }
        if list.hasFailed { return "Could not load" }
        if list.search == .live && list.query.isEmpty { return "Type to search" }
        return list.query.isEmpty ? "Nothing here yet" : "No results"
    }

    private func createLabel(_ title: String) -> some View {
        Text(title)
            .font(SpotType.body)
            .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
            .background(Color.white.opacity(SpotTokens.selectedFill), in: row)
            .contentShape(row)
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
            .safeAreaPadding(.bottom, SpotTokens.sheetFits(rows: list.shown.count) ? SpotTokens.padding : Self.bottomFade)
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
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(item.title)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(Color.white.opacity(isSelected ? SpotTokens.selectedFill : SpotTokens.fill), in: row)
        .contentShape(row)
    }
}
