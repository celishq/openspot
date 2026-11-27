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
                case .heading(let level, let text):
                    Text(text)
                        .font(SpotType.strong)
                        .foregroundStyle(level > 2 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .padding(.top, SpotTokens.storeHeadingGap)
                case .text(let text):
                    Text(text)
                case .item(let marker, let text):
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(marker)
                            .foregroundStyle(.secondary)
                            .frame(width: SpotTokens.storeMarkerWidth, alignment: .leading)
                        Text(text)
                    }
                case .quote(let text):
                    Text(text)
                        .foregroundStyle(.secondary)
                        .padding(.leading, SpotTokens.storeCodePadding)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(SpotTheme.ink.opacity(SpotTheme.hover))
                                .frame(width: SpotTokens.storeQuoteBar)
                        }
                case .code(let text):
                    Text(text)
                        .font(SpotType.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SpotTokens.storeCodePadding)
                        .background(SpotTheme.ink.opacity(SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.mediaRadius))
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
