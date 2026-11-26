import OpenspotCore
import SwiftUI

struct StoreAskView: View {
    let store: Store
    let ask: StoreAsk

    var body: some View {
        switch ask {
        case .clash(let review):
            StoreSheet(title: "“\(review.name)” is already in My spots.", line: "Replace moves yours to the Trash. Keep Both installs this one under a new name. Its data stays either way.") {
                EmptyView()
            } buttons: {
                Button("Keep Both") { Task { await store.confirm(.keepBoth) } }
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Replace") { Task { await store.confirm(.replace) } }
                    .keyboardShortcut(.defaultAction)
            }
        case .install(let review):
            StoreSheet(title: "Install \(review.name)?", line: ([review.from] + [review.updated].compactMap { $0 }).joined(separator: " · ")) {
                StoreTrustView(lines: review.lines)
            } buttons: {
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Install") { Task { await store.confirm(review.clash) } }
                    .keyboardShortcut(.defaultAction)
            }
        case .update(let change):
            StoreSheet(title: "Update \(change.name)?", line: change.powers.isEmpty ? "This version asks for nothing new." : "This version asks for more than the one you have:") {
                powers(change)
            } buttons: {
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Update") { Task { await store.confirm() } }
                    .keyboardShortcut(.defaultAction)
            }
        case .revert(let change):
            StoreSheet(title: "Replace your edited \(change.name)?", line: "Your copy goes to the Trash, and the version of its store takes its place. Its data stays.") {
                powers(change)
            } buttons: {
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Replace") { Task { await store.confirm(.replace) } }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder
    private func powers(_ change: StoreChange) -> some View {
        if !change.powers.isEmpty {
            VStack(alignment: .leading, spacing: SpotTokens.storeTileLineGap) {
                ForEach(change.powers, id: \.self) { Text($0) }
            }
        }
    }
}
