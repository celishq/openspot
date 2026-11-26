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
                    .padding(.horizontal, -SpotTokens.storeColumnBleed)
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
        guard let source else { return store.summary }
        return source.isBuiltIn ? "Spots made to show what Openspot can do." : source.url.path
    }

    private func cardLine(_ card: StoreCard) -> some View {
        row(action: { Task { await store.open(card.id) } }) {
            SettingsSpotIcon(spot: card.spot, side: SpotTokens.settingsRowTile)
            titled(card.spot.name, card.spot.subtitle ?? " ")
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            switch card.mark {
            case .update:
                Button("Update") { Task { await store.update(card.id) } }
            case .edited:
                Text("Edited")
                    .foregroundStyle(.secondary)
            case .core, .installed, nil:
                EmptyView()
            }
            chevron
        }
        .contextMenu { StoreSpotMenu(store: store, model: model, id: card.id, spot: card.spot, isCore: card.mark == .core, opens: true) }
    }

    @ViewBuilder
    func spotPage(_ page: StorePage) -> some View {
        let preview = sample.flatMap { $0.id == page.id ? StorePreview(face: $0.output.face, spot: page.spot) : nil } ?? page.preview
        Section {} header: {
            VStack(alignment: .leading, spacing: SpotTokens.settingsHeadingGap) {
                HStack(alignment: .center, spacing: SpotTokens.settingsHeaderGap) {
                    SettingsSpotIcon(spot: page.spot, side: SpotTokens.settingsHeaderTile)
                    VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                        Text(page.spot.name)
                            .font(SpotType.settingsHeader)
                            .lineLimit(1)
                        Text(pageLine(page))
                            .font(SpotType.settingsPageLine)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: SpotTokens.settingsTrailingGap)
                    HStack(spacing: SpotTokens.settingsValueGap) {
                        if page.button != .install {
                            Text(badge(page.button))
                                .foregroundStyle(.secondary)
                        }
                        if sample?.id == page.id, model != nil {
                            Button("Try") { isTrying = true }
                                .buttonStyle(.bordered)
                        }
                        button(page)
                    }
                    .controlSize(.large)
                    .fixedSize()
                }
                VStack(alignment: .leading, spacing: SpotTokens.storeTileGap) {
                    StoreSizes(spot: page.spot, face: preview.face, sizes: preview.sizes, width: SpotTokens.storeRowWidth)
                    if !preview.drawsCard, let model, let sample, sample.id == page.id, sample.hasSheet {
                        StoreSheetPreview(model: model, spot: page.spot, output: sample.output, selects: false)
                            .allowsHitTesting(false)
                            .frame(maxHeight: SpotTokens.storeSheetPreviewHeight, alignment: .top)
                            .clipped()
                    }
                }
                .offset(x: -SpotTokens.storeColumnBleed)
            }
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.bottom, SpotTokens.settingsHeadingGap)
        }
        Section {} header: {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text("About")
                    .font(SpotType.settingsGroup)
                StoreReadmeView(lines: page.shown, name: page.spot.name)
                    .frame(maxWidth: SpotTokens.storeReadWidth, alignment: .leading)
            }
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.bottom, SpotTokens.settingsHeadingGap)
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
            Button { Task { await store.installPage() } } label: { action("Install") }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        case .update, .edited, .installed, .locked:
            if page.button == .update {
                Button { Task { await store.update(page.id) } } label: { action("Update") }
                    .buttonStyle(.borderedProminent)
            } else if let model {
                Button { model.openSpot(page.id) } label: { action("Open") }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            Menu {
                StoreSpotMenu(store: store, model: model, id: page.id, spot: page.spot, isCore: page.button == .locked, opens: page.button == .update)
                if page.button == .edited {
                    Button("Revert…") { Task { await store.revert(page.id) } }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: SpotTokens.storeActionHeight, height: SpotTokens.storeActionHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.hover), in: Capsule())
            .contentShape(Capsule())
            .help("More")
        }
    }

    private func action(_ title: String) -> some View {
        Text(title)
            .frame(minWidth: SpotTokens.storePrimaryWidth)
    }

    private func badge(_ button: StoreButton) -> String {
        switch button {
        case .locked: "Comes with Openspot"
        case .edited: "Edited"
        case .install, .installed, .update: "Installed"
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
