import OpenspotCore
import SwiftUI

struct SpotThemeRows: View {
    let model: SpotThemeModel

    private static let titles = [
        ThemeRow.look: "Dark and light", "shared": "Both appearances", "glass": "Glass", "space": "Space",
        "radius": "Corners", "type": "Type", "motion": "Motion"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SpotTokens.menuPadding) {
                Text(model.inUse).font(SpotType.title).lineLimit(1)
                Spacer(minLength: 0)
                if model.isBuiltIn {
                    Button("Duplicate to edit") { model.duplicate() }
                }
            }
            .padding(.horizontal, SpotTokens.themeRowPadding)
            .frame(height: SpotTokens.themeLine)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpotTokens.menuRowGap) {
                        ForEach(model.groups, id: \.self) { group in
                            header(group)
                            ForEach(model.grouped[group] ?? []) { row in
                                SpotThemeRowView(row: row, isLocked: model.isBuiltIn, model: model)
                                    .id(row.id)
                            }
                        }
                    }
                    .padding(.bottom, SpotTokens.padding)
                }
                .scrollIndicators(.never)
                .background { PickScroll(model: model, proxy: proxy) }
            }
        }
    }

    private func header(_ group: String) -> some View {
        HStack(spacing: SpotTokens.menuPadding) {
            Text(Self.titles[group] ?? group.capitalized)
            Spacer(minLength: 0)
            if group == ThemeRow.look {
                Text("Dark").frame(width: SpotTokens.themeCellWidth, alignment: .leading)
                Text("Light").frame(width: SpotTokens.themeCellWidth, alignment: .leading)
            }
        }
        .font(SpotType.strong)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        .padding(.horizontal, SpotTokens.themeRowPadding)
        .frame(height: SpotTokens.themeLine)
    }
}

private struct PickScroll: View {
    let model: SpotThemeModel
    let proxy: ScrollViewProxy

    var body: some View {
        Color.clear.onChange(of: model.picked) { _, id in
            if let id { proxy.scrollTo(id) }
        }
    }
}
