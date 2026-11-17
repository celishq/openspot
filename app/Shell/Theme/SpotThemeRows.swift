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
                    ForEach(groups, id: \.self) { group in
                        Section {
                            ForEach(model.rows.filter { $0.group == group }) { row in
                                SpotThemeRowView(row: row, isLocked: model.isBuiltIn, isPicked: model.picked == row.id, model: model)
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
                .onChange(of: model.picked) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var groups: [String] {
        model.rows.map(\.group).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
}
