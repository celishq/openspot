import OpenspotCore
import SwiftUI

struct StoreAddSheet: View {
    let store: Store
    @Binding var isShown: Bool

    var body: some View {
        StoreSheet(title: "Add a store", line: "A store is a folder of spots, such as one a friend shares with you. Openspot lists its spots beside your own.") {
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                fact("Each spot in it is a .spot folder", "folder")
                fact("Install copies a spot into your spots", "square.and.arrow.down")
                fact("Your copy never changes under you", "lock")
                fact("Updates install only when you approve them", "arrow.triangle.2.circlepath")
                fact("Remove the store, and your spots stay", "trash")
            }
        } buttons: {
            Spacer(minLength: 0)
            Button("Cancel") { isShown = false }
                .keyboardShortcut(.cancelAction)
            Button("Choose Folder…") {
                Task {
                    guard let folder = await SpotFolderPick.pick() else { return }
                    isShown = false
                    await store.addSource(folder)
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func fact(_ text: String, _ symbol: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: SpotTokens.storeMarkerWidth)
        }
    }
}
