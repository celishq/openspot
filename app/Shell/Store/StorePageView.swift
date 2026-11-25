import OpenspotCore
import SwiftUI

struct StorePageView: View {
    let store: Store
    let page: StorePage
    let model: SpotsModel?
    @State private var isTrying = false

    private var placeName: String {
        guard case .source(let url) = store.place else { return "My spots" }
        return store.sources.first { $0.url == url }?.name ?? "Sources"
    }

    private var line: String {
        let state = page.button == .edited ? "Edited, updates paused" : page.updated
        return ([page.from] + [state].compactMap { $0 }).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            Button { store.closePage() } label: {
                Label(placeName, systemImage: "chevron.left")
                    .font(SpotType.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            .keyboardShortcut("[", modifiers: .command)
            HStack(alignment: .center, spacing: SpotTokens.wordsGap) {
                SpotGlyph(entry: SpotsModel.Entry(spot: page.spot, run: nil))
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(page.spot.name)
                        .font(SpotType.title)
                    Text(line)
                        .font(SpotType.detail)
                        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                }
                Spacer(minLength: 0)
                if page.hasSample {
                    Picker("Show", selection: $isTrying) {
                        Text("About").tag(false)
                        Text("Try").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                button
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                    if isTrying, let model {
                        SpotSampleSheet(model: model, entry: SpotsModel.Entry(spot: page.spot, run: nil)) {
                            await SpotSample.output(of: page.spot, runsScript: page.runsSample, runs: model.runs)
                        }
                        Text("Sample data. Clicks here run nothing and change nothing on your Mac.")
                            .font(SpotType.detail)
                            .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                    } else {
                        StoreTrustView(lines: page.trust)
                        StoreReadmeView(lines: page.shown, name: page.spot.name)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, SpotTokens.storeInset)
            }
        }
        .padding([.horizontal, .top], SpotTokens.storeInset)
        .onChange(of: page.id) { isTrying = false }
    }

    @ViewBuilder
    private var button: some View {
        switch page.button {
        case .install:
            Button("Install") { Task { await store.install(page.id) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        case .update:
            Button("Update") { Task { await store.update(page.id) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .edited:
            Button("Revert…") { Task { await store.revert(page.id) } }
                .controlSize(.large)
        case .installed:
            Label("Installed", systemImage: "checkmark")
                .font(SpotType.strong)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
        case .locked:
            Label("Comes with Openspot", systemImage: "lock.fill")
                .font(SpotType.strong)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
        }
    }
}
