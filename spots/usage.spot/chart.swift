import SwiftUI

/// Each spot as a dot, by its acts a day across and its CPU a day up, both on a log scale.
/// A dot takes the colour of its state, the selected row rings its dot, each name that fits beside its dot shows, and a click on a dot sends its id.
struct SpotView: View {
    let spot: SpotInput

    private static let left: CGFloat = 34
    private static let bottom: CGFloat = 20
    private static let top: CGFloat = 10
    private static let right: CGFloat = 12
    private static let mostActs = 20.0
    private static let leastCPU = 0.01
    private static let mostCPU = 2.0

    private struct Dot: Identifiable {
        let id: String
        let title: String
        let acts: Double
        let cpu: Double
        let state: String
    }

    private var dots: [Dot] {
        spot.items.filter { $0["state"] != nil }.map { row in
            Dot(id: row.id, title: row["title"] ?? row.id, acts: Double(row["acts"] ?? "") ?? 0, cpu: Double(row["cpu"] ?? "") ?? 0, state: row["state"] ?? "")
        }
    }

    var body: some View {
        let size = CGSize(width: spot.size.width - 2 * spot.inset, height: spot.size.height - 2 * spot.inset)
        let sides = sides(size)
        ZStack(alignment: .topLeading) {
            axes(size)
            ForEach(dots) { dot in
                mark(dot, at: place(dot, in: size), side: sides[dot.id])
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .padding(spot.inset)
        .foregroundStyle(spot.ink)
    }

    private func x(_ acts: Double, _ width: CGFloat) -> CGFloat {
        Self.left + CGFloat(log10(acts + 1) / log10(Self.mostActs + 1)) * (width - Self.left - Self.right)
    }

    private func y(_ cpu: Double, _ height: CGFloat) -> CGFloat {
        let share = log10(min(max(cpu, Self.leastCPU), Self.mostCPU) / Self.leastCPU) / log10(Self.mostCPU / Self.leastCPU)
        return height - Self.bottom - CGFloat(share) * (height - Self.bottom - Self.top)
    }

    private func place(_ dot: Dot, in size: CGSize) -> CGPoint {
        CGPoint(x: x(min(dot.acts, Self.mostActs), size.width), y: y(dot.cpu, size.height))
    }

    private func axes(_ size: CGSize) -> some View {
        let faint = spot.ink.opacity(0.18)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: Self.left, y: Self.top))
                path.addLine(to: CGPoint(x: Self.left, y: size.height - Self.bottom))
                path.addLine(to: CGPoint(x: size.width - Self.right, y: size.height - Self.bottom))
            }
            .stroke(faint, lineWidth: 1)
            ForEach([0.0, 1, 5, 20], id: \.self) { acts in
                label(acts == 0 ? "0" : String(Int(acts)), at: CGPoint(x: x(acts, size.width), y: size.height - Self.bottom / 2 + 2))
            }
            ForEach([0.01, 0.1, 1.0], id: \.self) { cpu in
                label("\(cpu < 1 ? String(cpu) : "1") s", at: CGPoint(x: Self.left / 2 - 2, y: y(cpu, size.height)))
            }
            label("acts a day →", at: CGPoint(x: size.width - Self.right - 34, y: size.height - Self.bottom - 9))
        }
    }

    private func label(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 9))
            .opacity(spot.secondary * 0.8)
            .fixedSize()
            .position(point)
    }

    private func colour(_ state: String) -> Color {
        switch state {
        case "bad": .red
        case "warn": .orange
        case "unused": spot.ink.opacity(0.35)
        default: spot.ink.opacity(0.85)
        }
    }

    private func sides(_ size: CGSize) -> [String: Bool] {
        let first = dots.sorted { rank($0) < rank($1) }
        var taken: [CGRect] = []
        var sides: [String: Bool] = [:]
        for dot in first {
            let point = place(dot, in: size)
            let width = CGFloat(dot.title.count) * 6 + 4
            let bounds = CGRect(x: Self.left, y: 0, width: size.width - Self.left, height: size.height - Self.bottom)
            for isLeft in [point.x > size.width * 0.6, point.x <= size.width * 0.6] {
                let box = CGRect(x: isLeft ? point.x - 11 - width : point.x + 11, y: point.y - 7, width: width, height: 14)
                if bounds.contains(box) && !taken.contains(where: { $0.intersects(box) }) {
                    taken.append(box)
                    sides[dot.id] = isLeft
                    break
                }
            }
        }
        return sides
    }

    private func rank(_ dot: Dot) -> Int {
        dot.id == spot.selection ? 0 : dot.state == "bad" ? 1 : dot.state == "warn" ? 2 : 3
    }

    private func mark(_ dot: Dot, at point: CGPoint, side: Bool?) -> some View {
        let isSelected = spot.selection == dot.id
        let isStrong = isSelected || dot.state == "bad" || dot.state == "warn"
        return ZStack {
            if isSelected {
                Circle().stroke(spot.ink, lineWidth: 1.5).frame(width: 14, height: 14)
            }
            Circle().fill(colour(dot.state)).frame(width: 7, height: 7)
            if let isLeft = side {
                Text(dot.title)
                    .font(.system(size: 10, weight: isStrong ? .medium : .regular))
                    .opacity(isStrong ? 1 : spot.secondary * 0.8)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: 0, alignment: isLeft ? .trailing : .leading)
                    .offset(x: isLeft ? -11 : 11)
            }
        }
        .frame(width: 16, height: 16)
        .contentShape(Circle())
        .onTapGesture { spot.send(dot.id) }
        .position(point)
        .zIndex(isSelected ? 1 : 0)
    }
}
