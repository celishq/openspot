import SwiftUI

/// Each day of the year as a square, in one field that fills the card from edge to edge: the days that passed are dark,
/// today is in the accent colour, and the days to come are faint. A small or wide card shows only the days left.
struct SpotView: View {
    let spot: SpotInput

    private var day: Int { Int(spot["day"] ?? "") ?? 0 }
    private var days: Int { max(1, Int(spot["days"] ?? "") ?? 365) }
    private var left: String { spot["left"] ?? "–" }

    var body: some View {
        Group {
            if spot.size.height < 100 && spot.size.width < 200 {
                count
            } else if spot.size.height < 100 {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(spot["title"] ?? "").font(.headline)
                        Text("\(left) days left").font(spot.font.detail).opacity(spot.secondary)
                    }
                    .fixedSize()
                    field
                }
                .padding(spot.inset)
            } else {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(spot["title"] ?? "").font(.headline)
                        Spacer(minLength: 4)
                        Text("\(left) days left").font(spot.font.detail).opacity(spot.secondary)
                    }
                    field
                }
                .padding(spot.inset)
            }
        }
        .foregroundStyle(spot.ink)
        .frame(width: spot.size.width, height: spot.size.height)
    }

    private var count: some View {
        Group {
            if spot.size.width < 100 {
                VStack(spacing: -1) {
                    Text(left).font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("days left").font(.system(size: 8)).opacity(spot.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Text(left).font(spot.font.metric)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("days left")
                        Text("in \(spot["title"] ?? "")")
                    }
                    .font(spot.font.detail)
                    .opacity(spot.secondary)
                }
            }
        }
    }

    private var field: some View {
        Canvas { context, size in
            let field = DayField(count: days, size: size)
            let ink = spot.ink
            for index in 0..<days {
                let path = Path(roundedRect: field.square(at: index), cornerRadius: field.side * 0.28)
                if index == day - 1 {
                    context.fill(path, with: .color(spot.accent))
                } else {
                    context.fill(path, with: .color(ink.opacity(index < day - 1 ? 0.42 : 0.09)))
                }
            }
        }
    }
}

/// The squares of a count of days laid out in the rows that make them biggest, with the first and last column on the
/// left and right edges and the first and last row on the top and bottom edges.
struct DayField {
    let columns: Int
    let rows: Int
    let side: CGFloat
    let size: CGSize

    init(count: Int, size: CGSize) {
        var best = (columns: count, rows: 1, step: 0.0)
        for rows in 1...count {
            let columns = (count + rows - 1) / rows
            let step = min(size.width / Double(columns), size.height / Double(rows))
            if step > best.step { best = (columns, rows, step) }
        }
        columns = best.columns
        rows = best.rows
        side = best.step * 0.78
        self.size = size
    }

    func square(at index: Int) -> CGRect {
        let across = (size.width - side) / Double(max(columns - 1, 1))
        let down = (size.height - side) / Double(max(rows - 1, 1))
        return CGRect(x: Double(index % columns) * across, y: Double(index / columns) * down, width: side, height: side)
    }
}
