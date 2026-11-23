import OpenspotCore
import SwiftUI

struct SpotFieldValue: View {
    let model: SpotsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SpotFieldValuePointer(model: model)
            ZStack(alignment: .leading) {
                if let preview = model.contextPreview {
                    ZStack(alignment: .leading) {
                        words(of: preview)
                            .id(preview)
                            .transition(.opacity)
                    }
                    .transition(.opacity.combined(with: .offset(y: -SpotTokens.contextValueRise)))
                }
            }
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: SpotFieldView.rect.width, height: SpotTokens.contextValueRoom)
    }

    private func words(of preview: ContextPreview) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            HStack(spacing: SpotTokens.previewCaptionGap) {
                Image(systemName: preview.symbol)
                Text(preview.caption)
                    .lineLimit(1)
            }
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            if !preview.text.isEmpty {
                Text(preview.text)
                    .font(SpotType.body)
                    .modifier(SpotInk())
                    .lineLimit(SpotTokens.previewLines)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SpotFieldValuePointer: View {
    let model: SpotsModel

    var body: some View {
        let spread = model.contextSpread
        let x = SpotContextStack.selectedX(in: spread).map { Self.front + $0 }
        let width = SpotTokens.contextPointerWidth
        Rectangle()
            .fill(SpotTheme.contextDivider)
            .frame(height: SpotTokens.dividerHeight)
            .mask {
                Rectangle()
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .frame(width: width)
                            .offset(x: (x ?? Self.front) - width / 2)
                            .opacity(x == nil ? MotionTokens.hiddenOpacity : 1)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .overlay(alignment: .bottomLeading) {
                SpotPointerShape()
                    .stroke(SpotTheme.contextDivider, lineWidth: SpotTokens.dividerHeight)
                    .frame(width: width, height: SpotTokens.contextPointerHeight)
                    .offset(x: (x ?? Self.front) - width / 2)
                    .opacity(x == nil ? MotionTokens.hiddenOpacity : 1)
            }
            .allowsHitTesting(false)
    }

    private static var front: CGFloat {
        SpotFieldView.contextLeft - SpotFieldView.rect.minX + SpotTokens.contextStack(count: ContextChips.limit) - SpotTokens.contextCard / 2
    }
}

private struct SpotPointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
