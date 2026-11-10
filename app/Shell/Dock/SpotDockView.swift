import OpenspotCore
import SwiftUI

/// The dock of Edit Spots: the search, a tab for each place with its count, Done, and the spots of the tab in one row that
/// scrolls to the side. With All, the spots of each place follow the name of the place.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool

    var body: some View {
        let dock = model.dock
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: 6) {
                search
                ForEach(SpotDock.Tab.allCases, id: \.self) { tab in
                    tabButton(tab, count: dock.count(of: tab), isOn: dock.tab == tab)
                }
                Spacer(minLength: 0)
                Button { model.endEditing() } label: {
                    Text("Done")
                        .font(SpotType.title)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 28)
                        .background(SpotTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 2 * SpotTokens.columnGap) {
                    ForEach(SpotDock.Place.allCases.filter { place in dock.shown.contains { $0.place == place } }, id: \.self) { place in
                        VStack(alignment: .leading, spacing: 6) {
                            if dock.tab == .all {
                                Text(place.title)
                                    .font(SpotType.action)
                                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                            }
                            HStack(alignment: .top, spacing: SpotTokens.columnGap) {
                                ForEach(dock.shown.filter { $0.place == place }) { item in
                                    SpotDockTile(entry: entry(of: item))
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .leading) {
                if dock.shown.isEmpty {
                    Text(dock.query.isEmpty ? "Each spot shows on the grid." : "No spot has this name.")
                        .font(SpotType.body)
                        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                }
            }
        }
        .padding(16)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background {
            let shape = RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous)
            SpotBlur(radius: SpotTheme.blur)
                .overlay(SpotTheme.glass)
                .clipShape(shape)
                .overlay(shape.strokeBorder(SpotTheme.ink.opacity(SpotTheme.fill), lineWidth: 0.5))
        }
        .onChange(of: isSearching) { _, isOn in model.searchesDock(isOn) }
        .onChange(of: model.isSearchingDock) { _, isOn in if !isOn { isSearching = false } }
    }

    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
            TextField("Search", text: Binding(get: { model.dock.query }, set: { model.searchDock($0) }))
                .textFieldStyle(.plain)
                .font(SpotType.body)
                .focused($isSearching)
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 28)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: Capsule())
    }

    private func tabButton(_ tab: SpotDock.Tab, count: Int, isOn: Bool) -> some View {
        Button { model.showDockTab(tab) } label: {
            HStack(spacing: 4) {
                Text(tab.title)
                Text("\(count)").foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
            }
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(SpotTheme.ink.opacity(isOn ? SpotTheme.chip : 0), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// The card of a spot in the dock: its entry when it has one, or one made from its command when it is off.
    private func entry(of item: SpotDock.Item) -> SpotsModel.Entry {
        model.cards.first { $0.id == item.id } ?? SpotsModel.Entry(command: item.command, run: nil)
    }
}
