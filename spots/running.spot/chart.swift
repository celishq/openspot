import SwiftUI

/// Each spot as a dot, by its acts a day across and its CPU a day up, both on a log scale.
/// A dot takes the colour of its state, the selected row rings its dot, and a click on a dot sends its id.
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
        spot.rows.map { row in
            Dot(id: row.id, title: row["title"] ?? row.id, acts: Double(row["acts"] ?? "") ?? 0, cpu: Double(row["cpu"] ?? "") ?? 0, state: row["state"] ?? "")
        }
    }

    var body: some View {
        let size = CGSize(width: spot.size.width - 2 * spot.inset, height: spot.size.height - 2 * spot.inset)
        ZStack(alignment: .topLeading) {
            axes(size)
            ForEach(dots) { dot in
                mark(dot, at: place(dot, in: size))
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

    private func mark(_ dot: Dot, at point: CGPoint) -> some View {
        let isSelected = spot.selection == dot.id
        let isStrong = isSelected || dot.state == "bad" || dot.state == "warn"
        return ZStack {
            if isSelected {
                Circle().stroke(spot.ink, lineWidth: 1.5).frame(width: 16, height: 16)
            }
            Circle().fill(colour(dot.state)).frame(width: 8, height: 8)
            Text(dot.title)
                .font(.system(size: 10, weight: isStrong ? .medium : .regular))
                .opacity(isStrong ? 1 : spot.secondary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 0, alignment: isStrong ? .trailing : .leading)
                .offset(x: isStrong ? 4 : 9, y: isStrong ? -(isSelected ? 15 : 12) : 0)
        }
        .frame(width: 18, height: 18)
        .contentShape(Circle())
        .onTapGesture { spot.send(dot.id) }
        .position(point)
    }
}
