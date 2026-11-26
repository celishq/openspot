import OpenspotCore
import SwiftUI

struct LookPanel: View {
    let swatch: Theme.Appearance
    let layout: Theme.Layout
    let spots: [LookSpot]

    private var faces: SpotType.Faces { SpotType.Faces(layout.type) }
    private var padding: CGFloat { CGFloat(layout.space.padding) }
    private var rowGap: CGFloat { CGFloat(layout.space.rowGap) }
    private var halo: CGFloat { CGFloat(layout.space.padding) * SpotTokens.settingsLookHalo }

    var size: CGSize {
        let width = layout.width(columns: SpotTokens.columns)
        let height = layout.fieldHeight + rowGap + layout.height(rows: 1) + rowGap + layout.height(rows: 1)
        return CGSize(width: width + 2 * halo, height: height + 2 * halo)
    }

    var body: some View {
        let faces = faces
        ZStack {
            backdrop
            VStack(alignment: .leading, spacing: rowGap) {
                field(faces)
                HStack(spacing: CGFloat(layout.space.columnGap)) {
                    ForEach(0..<2, id: \.self) { card(at: $0, size: .wide, faces: faces) }
                }
                HStack(spacing: CGFloat(layout.space.columnGap)) {
                    ForEach(2..<6, id: \.self) { card(at: $0, size: .small, faces: faces) }
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var backdrop: some View {
        ZStack {
            if layout.backdrop.style != .blur { swatch.backdropTint.color }
        }
        .mask(SpotRoundShape(radius: CGFloat(layout.radius.card) + halo / 2).padding(halo / 2).blur(radius: halo * SpotTokens.settingsLookFade))
    }

    private func glass(_ shape: SpotRoundShape) -> some View {
        shape.fill(swatch.glass.color).overlay(shape.stroke(SpotTheme.pictureRim, lineWidth: SpotTokens.pictureRimLine))
    }

    private func field(_ faces: SpotType.Faces) -> some View {
        let shape = SpotRoundShape(radius: layout.corner(for: .strip))
        return HStack(spacing: SpotTokens.fieldTextGap) {
            Image(systemName: "magnifyingglass")
            Text("Search")
        }
        .font(faces.input)
        .foregroundStyle(swatch.ink.color.opacity(swatch.secondary))
        .padding(.horizontal, padding)
        .frame(width: layout.width(columns: SpotTokens.columns), height: layout.fieldHeight, alignment: .leading)
        .background(glass(shape))
    }

    private func card(at index: Int, size: SpotSize, faces: SpotType.Faces) -> some View {
        let spot = spots.isEmpty ? nil : spots[index % spots.count]
        let shape = SpotRoundShape(radius: layout.corner(for: size))
        return HStack(spacing: layout.wordsGap) {
            Image(systemName: spot?.symbol ?? "square")
                .font(SpotType.glyph)
                .foregroundStyle(index == 0 ? swatch.accent.color : swatch.ink.color)
                .frame(width: CGFloat(layout.space.glyph), height: CGFloat(layout.space.glyph))
            if size.columns > 1, let name = spot?.name, !name.isEmpty {
                Text(name)
                    .font(faces.title)
                    .foregroundStyle(swatch.ink.color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, size.columns > 1 ? padding : 0)
        .frame(width: layout.width(columns: size.columns), height: layout.height(rows: size.rows), alignment: size.columns > 1 ? .leading : .center)
        .background(swatch.ink.color.opacity(swatch.fill), in: shape)
        .background(glass(shape))
    }
}
