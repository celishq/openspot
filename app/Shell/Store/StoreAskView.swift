import OpenspotCore
import SwiftUI

struct StoreAskView: View {
    let store: Store
    let ask: StoreAsk

    var body: some View {
        ZStack {
            SpotTheme.storeDim
                .ignoresSafeArea()
                .onTapGesture { store.dismissAsk() }
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                content
            }
            .padding(SpotTokens.storeInset)
            .frame(width: SpotTokens.storeAskWidth, alignment: .leading)
            .background(SpotTheme.window, in: SpotRoundShape(radius: SpotTokens.storeAskRadius))
            .shadow(color: SpotTheme.cardShadow, radius: SpotTheme.liftShadow)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ask {
        case .clash(let review):
            title("“\(review.name)” is already in My spots.", "Replace it with the one you’re installing? Replace moves yours to the Trash, and Keep Both installs this one under a new name. Its data stays either way.")
            buttons {
                Button("Keep Both") { Task { await store.confirm(.keepBoth) } }
                Spacer(minLength: 0)
                Button("Stop") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Replace") { Task { await store.confirm(.replace) } }
                    .keyboardShortcut(.defaultAction)
            }
        case .install(let review):
            title("Install \(review.name)?", ([review.from] + [review.updated].compactMap { $0 }).joined(separator: " · "))
            StoreTrustView(lines: review.lines)
            buttons {
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Install") { Task { await store.confirm(review.clash) } }
                    .keyboardShortcut(.defaultAction)
            }
        case .update(let change):
            title("Update \(change.name)?", change.powers.isEmpty ? "This version asks for nothing new." : "This version asks for more than the one you have:")
            powers(change)
            buttons {
                Spacer(minLength: 0)
                Button("Cancel") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Update") { Task { await store.confirm() } }
                    .keyboardShortcut(.defaultAction)
            }
        case .revert(let change):
            title("Replace your edited \(change.name)?", "Your copy goes to the Trash, and the version of its source takes its place. Its data stays.")
            powers(change)
            buttons {
                Spacer(minLength: 0)
                Button("Stop") { store.dismissAsk() }
                    .keyboardShortcut(.cancelAction)
                Button("Replace") { Task { await store.confirm(.replace) } }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func title(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(title)
                .font(SpotType.strong)
            Text(detail)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func powers(_ change: StoreChange) -> some View {
        if !change.powers.isEmpty {
            VStack(alignment: .leading, spacing: SpotTokens.storeTileLineGap) {
                ForEach(change.powers, id: \.self) { Text($0) }
            }
            .font(SpotType.body)
        }
    }

    private func buttons(@ViewBuilder _ row: () -> some View) -> some View {
        HStack(spacing: SpotTokens.wordsGap) { row() }
            .controlSize(.large)
            .padding(.top, SpotTokens.storeTileLineGap)
    }
}
