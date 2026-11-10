import OpenspotCore
import SwiftUI

/// The dock of Edit Spots: the search, the number of spots that are off, Done, and those spots in one row that scrolls to
/// the side.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool

    var body: some View {
        let dock = model.dock
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: 6) {
                search
                Text("Off \(dock.shown.count)")
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                    .padding(.horizontal, 10)
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
                HStack(alignment: .top, spacing: SpotTokens.columnGap) {
                    ForEach(dock.shown) { item in
                        SpotDockTile(entry: SpotsModel.Entry(command: item.command, run: nil))
                    }
                }
            }
            .overlay(alignment: .leading) {
                if dock.shown.isEmpty {
                    Text(dock.query.isEmpty ? "Each spot is on." : "No spot has this name.")
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
}
