import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    let items: [SpotItem]
    let itemSelected: Int
    let onRun: (SpotItem) -> Void
    let onClose: () -> Void

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding - 5) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(Color.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.state.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    if let subtitle = entry.state.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .modifier(SpotSecondaryText())
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.element.run) { index, item in
                    Button {
                        onRun(item)
                    } label: {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, SpotTokens.padding)
                            .frame(height: 40)
                            .background(Color.white.opacity(index == itemSelected ? 0.3 : 0.12), in: row)
                            .contentShape(row)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(SpotTokens.padding)
        .frame(width: SpotTokens.sheetRect.width, height: SpotTokens.sheetRect.height, alignment: .topLeading)
    }
}
