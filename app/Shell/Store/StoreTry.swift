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
            HStack(alignment: .top, spacing: SpotTokens.storeInset) {
                VStack(alignment: .leading, spacing: SpotTokens.storeTileGap) {
                    HStack(alignment: .top, spacing: SpotTokens.storeTileGap) {
                        sized(.small)
                        sized(.wide)
                        sized(.square)
                    }
                    sized(.strip)
                    sized(.large)
                }
                if hasSheet {
                    SpotSampleSheet(model: model, entry: SpotsModel.Entry(spot: spot, run: nil)) { output }
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

    private func sized(_ size: SpotSize) -> some View {
        VStack(spacing: SpotTokens.storeTileLineGap) {
            StoreCardPreview(spot: spot, face: output.face, size: size, fits: false)
            Text("\(size.columns)×\(size.rows)")
                .font(SpotType.detail)
                .foregroundStyle(.secondary)
        }
    }
}
