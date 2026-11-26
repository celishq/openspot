import OpenspotCore
import SwiftUI

extension StoreView {
    @ViewBuilder
    var placePage: some View {
        let source = store.place.source
        title(.heading, EmptyView(), store.title, placeLine(source)) {}
        if let source, store.missing.contains(source.url.path) {
            group(nil) {
                plain("Openspot cannot find \(source.url.path). Locate the folder, or remove the source. The spots you got from it stay.")
                HStack {
                    Spacer(minLength: 0)
                    Button("Remove") { Task { await store.removeSource(source.url) } }
                    Button("Locate…") {
                        Task {
                            guard let folder = await SpotFolderPick.pick() else { return }
                            await store.addSource(folder)
                            await store.removeSource(source.url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else if store.cards.isEmpty {
            group(nil) {
                plain(store.query.isEmpty ? "No spots here yet." : "No spot here matches “\(store.query)”.")
                if !store.query.isEmpty {
                    Button("Clear Search") { store.search("") }
                }
            }
        } else {
            group(nil) {
                lines(store.cards) { card in cardLine(card, isFromSource: source != nil) }
            }
        }
    }

    private func placeLine(_ source: StoreSource?) -> String {
        guard let source else { return "Each spot you have. Drop a spot from a source here to install it." }
        let from = source.isBuiltIn ? "The spots that come with Openspot." : source.url.path
        return "\(from) Drag a spot to My spots, or press +, to install it."
    }

    @ViewBuilder
    private func cardLine(_ card: StoreCard, isFromSource: Bool) -> some View {
        let line = row(action: { Task { await store.open(card.id) } }) {
            SettingsSpotIcon(spot: card.spot, side: SpotTokens.settingsRowTile)
            titled(card.spot.name, card.spot.subtitle ?? "")
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if let mark = card.mark { StoreMarkView(mark: mark) }
            if isFromSource, card.mark == nil {
                Button { Task { await store.install(card.id) } } label: { Image(systemName: "plus.circle") }
                    .buttonStyle(.borderless)
                    .help("Install \(card.spot.name)")
            }
            chevron
        }
        if isFromSource {
            line.draggable(card.id) { StoreTileLift(card: card) }
        } else {
            line
        }
    }

    @ViewBuilder
    func spotPage(_ page: StorePage) -> some View {
        title(.header, SettingsSpotIcon(spot: page.spot, side: SpotTokens.settingsCompactTile), page.spot.name, pageLine(page)) {
            HStack(spacing: SpotTokens.settingsValueGap) {
                button(page)
                if page.hasSample, model != nil {
                    Button("Try") { isTrying = true }
                }
            }
            .padding(.top, SpotTokens.settingsTitleGap)
        }
        group("About") {
            StoreReadmeView(lines: page.shown, name: page.spot.name)
        }
        if !page.trust.isEmpty {
            group("What It Can Do") {
                ForEach(page.trust, id: \.title) { line in
                    HStack(alignment: .firstTextBaseline, spacing: SpotTokens.settingsValueGap) {
                        Text(line.title)
                            .foregroundStyle(.secondary)
                            .frame(width: SpotTokens.storeTrustTitleWidth, alignment: .leading)
                        Text(line.words.joined(separator: line.title == "Files" ? ", " : "\n"))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func pageLine(_ page: StorePage) -> String {
        let state = page.button == .edited ? "Edited, updates paused" : page.updated
        return ([page.from] + [state].compactMap { $0 }).joined(separator: " · ")
    }

    @ViewBuilder
    private func button(_ page: StorePage) -> some View {
        switch page.button {
        case .install:
            Button("Install") { Task { await store.install(page.id) } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        case .update:
            Button("Update") { Task { await store.update(page.id) } }
                .buttonStyle(.borderedProminent)
        case .edited:
            Button("Revert…") { Task { await store.revert(page.id) } }
        case .installed:
            Label("Installed", systemImage: "checkmark")
                .foregroundStyle(.secondary)
        case .locked:
            Label("Comes with Openspot", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var trySheet: some View {
        if let model, let page = store.page {
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                SpotSampleSheet(model: model, entry: SpotsModel.Entry(spot: page.spot, run: nil)) {
                    await SpotSample.output(of: page.spot, runsScript: page.runsSample, runs: model.runs)
                }
                HStack {
                    Text("Sample data. Clicks here run nothing and change nothing on your Mac.")
                        .font(SpotType.settingsLine)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: SpotTokens.settingsTrailingGap)
                    Button("Done") { isTrying = false }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(SpotTokens.storeInset)
        }
    }
}
