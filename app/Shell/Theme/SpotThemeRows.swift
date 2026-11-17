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
            HStack {
                Text(model.inUse).font(SpotType.title).lineLimit(1)
                Spacer(minLength: 0)
                if model.isBuiltIn {
                    Button("Duplicate to edit") { model.duplicate() }
                }
            }
            .padding(SpotTokens.padding)
            ScrollViewReader { proxy in
                Form {
                    ForEach(model.groups, id: \.self) { group in
                        Section {
                            ForEach(model.grouped[group] ?? []) { row in
                                SpotThemeRowView(row: row, isLocked: model.isBuiltIn, model: model)
                                    .id(row.id)
                            }
                        } header: {
                            HStack {
                                Text(Self.titles[group] ?? group.capitalized)
                                Spacer(minLength: 0)
                                if group == ThemeRow.look {
                                    Text("Dark").frame(width: SpotTokens.themeCellWidth, alignment: .leading)
                                    Text("Light").frame(width: SpotTokens.themeCellWidth, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background { PickScroll(model: model, proxy: proxy) }
            }
        }
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
