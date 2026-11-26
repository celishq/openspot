import OpenspotCore
import SwiftUI

struct StoreAddSheet: View {
    let store: Store
    @Binding var isShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text("Add a store")
                    .font(SpotType.settingsTitle)
                Text("A store is a folder of spots, such as one a friend shares with you. Openspot lists its spots beside your own.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                fact("Each spot in it is a .spot folder", "folder")
                fact("Install copies a spot into your spots", "square.and.arrow.down")
                fact("Your copy never changes under you", "lock")
                fact("A newer version waits for your yes", "arrow.triangle.2.circlepath")
                fact("Remove the store, and your spots stay", "trash")
            }
            HStack(spacing: SpotTokens.settingsRowGap) {
                Spacer()
                Button("Cancel") { isShown = false }
                    .keyboardShortcut(.cancelAction)
                Button("Choose Folder…") {
                    Task {
                        guard let folder = await SpotFolderPick.pick() else { return }
                        isShown = false
                        await store.addSource(folder)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
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
