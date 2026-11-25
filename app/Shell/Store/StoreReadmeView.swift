import OpenspotCore
import SwiftUI

struct StoreReadmeView: View {
    let lines: [StoreReadmeLine]
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeTileLineGap) {
            if lines.isEmpty {
                Text("\(name) has no readme yet.")
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .heading(let text):
                    Text(text)
                        .font(SpotType.strong)
                        .padding(.top, SpotTokens.storeHeadingGap)
                case .text(let text):
                    Text(text)
                case .media(let path, let caption):
                    VStack(alignment: .leading, spacing: SpotTokens.storeTileLineGap) {
                        AsyncImage(url: URL(string: path).flatMap { $0.scheme == nil ? nil : $0 } ?? URL(fileURLWithPath: path)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(maxHeight: SpotTokens.storeMediaHeight, alignment: .leading)
                        .clipShape(SpotRoundShape(radius: SpotTokens.mediaRadius))
                        if !caption.isEmpty {
                            Text(caption)
                                .font(SpotType.detail)
                                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                        }
                    }
                }
            }
        }
        .font(SpotType.body)
        .textSelection(.enabled)
    }
}
