import AppKit
import OpenspotCore
import SwiftUI

extension StoreView {
    @ViewBuilder
    var placePage: some View {
        let source = store.place.source
        title(.heading, EmptyView(), store.title, placeLine(source)) {}
        if let source, store.missing.contains(source.url.path) {
            group(nil) {
                plain("Openspot cannot find \(source.url.path). Locate the folder, or remove the store. The spots you got from it stay.")
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
        } else if source != nil {
            Section {} header: {
                VStack(alignment: .leading, spacing: SpotTokens.storeTileGap) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpotTokens.storeTileGap), count: 2), spacing: SpotTokens.storeTileGap) {
                        ForEach(store.cards) { card in StoreTile(store: store, card: card) }
                    }
                    Text("Drag a spot to My spots to install it.")
                        .font(SpotType.settingsLine)
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
                .foregroundStyle(.primary)
            }
        } else {
            ForEach(store.groups) { shelf in
                group(shelf.title) {
                    lines(shelf.cards) { card in cardLine(card) }
                }
            }
        }
    }

    private func placeLine(_ source: StoreSource?) -> String {
        guard let source else { return "Each spot you have." }
        return source.isBuiltIn ? "Spots made to show what Openspot can do." : source.url.path
    }

    private func cardLine(_ card: StoreCard) -> some View {
        row(action: { Task { await store.open(card.id) } }) {
            SettingsSpotIcon(spot: card.spot, side: SpotTokens.settingsRowTile)
            titled(card.spot.name, card.spot.subtitle ?? "")
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            chevron
        }
    }

    @ViewBuilder
    func spotPage(_ page: StorePage) -> some View {
        title(.header, SettingsSpotIcon(spot: page.spot, side: SpotTokens.settingsHeaderTile), page.spot.name, pageLine(page)) {
            HStack(spacing: SpotTokens.settingsValueGap) {
                button(page)
            }
            .padding(.top, SpotTokens.settingsTitleGap)
        }
        Section {
            VStack(spacing: SpotTokens.storeTilePadding) {
                let preview = sample.flatMap { $0.id == page.id ? StorePreview(face: $0.output.face, spot: page.spot) : nil } ?? page.preview
                StoreCardPreview(spot: page.spot, face: preview.face, size: preview.size)
                if sample?.id == page.id, model != nil {
                    Button("Try") { isTrying = true }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpotTokens.storeTilePadding)
        }
        group("About") {
            StoreReadmeView(lines: page.shown, name: page.spot.name)
        }
        if page.trust.contains(where: { !$0.isFiles }) {
            group("What It Can Do") {
                ForEach(page.trust.filter { !$0.isFiles }, id: \.title) { line in
                    HStack(alignment: .firstTextBaseline, spacing: SpotTokens.settingsValueGap) {
                        Text(line.title)
                            .foregroundStyle(.secondary)
                            .frame(width: SpotTokens.storeTrustTitleWidth, alignment: .leading)
                        Text(line.words.joined(separator: "\n"))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        if !page.files.isEmpty {
            folding("Files", isFolded: $areFilesFolded) {
                ForEach(page.files) { file in
                    row(action: { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }) {
                        Image(systemName: file.symbol)
                            .foregroundStyle(.secondary)
                            .frame(width: SpotTokens.storeMarkerWidth)
                        Text(file.name)
                        Spacer(minLength: SpotTokens.settingsTrailingGap)
                        Text(file.size)
                            .foregroundStyle(.secondary)
                    }
                    .help("Show in Finder")
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
            Button("Install") { Task { await store.installPage() } }
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
        if let model, let page = store.page, let sample, sample.id == page.id {
            StoreTry(model: model, spot: page.spot, output: sample.output, hasSheet: sample.hasSheet) { isTrying = false }
        }
    }

    func loadSample() async {
        guard let model, let page = store.page, page.hasSample else { return }
        guard let output = await SpotSample.output(of: page.spot, runsScript: page.runsSample, runs: model.runs), store.page?.id == page.id else { return }
        sample = StoreSample(id: page.id, output: output)
    }
}
