import OpenspotCore
import SwiftUI

struct StoreTry: View {
    let model: SpotsModel
    let spot: Spot
    let output: Frame
    let hasSheet: Bool
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            Text("Try \(spot.name)")
                .font(SpotType.settingsGroup)
            HStack(alignment: .top, spacing: SpotTokens.storeInset) {
                StoreSizes(spot: spot, face: output.face, sizes: SpotSize.all, width: SpotTokens.storeTryWidth)
                if hasSheet {
                    StoreSheetPreview(model: model, spot: spot, output: output)
                }
            }
            HStack {
                Text("Sample data. Clicks here run nothing and change nothing on your Mac.")
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
                Spacer(minLength: SpotTokens.settingsTrailingGap)
                Button("Done", action: done)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(SpotTokens.storeInset)
    }
}
