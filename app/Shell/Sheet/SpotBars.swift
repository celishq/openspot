import SwiftUI

struct SpotBars: View {
    let points: [Double]
    let gap: CGFloat
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            guard !points.isEmpty else { return }
            let top = max(points.max() ?? 1, 1)
            let width = (size.width - gap * CGFloat(points.count - 1)) / CGFloat(points.count)
            guard width > 0 else { return }
            let fill = GraphicsContext.Shading.color(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
            for (index, point) in points.enumerated() {
                let height = size.height * max(point, 0) / top
                let bar = CGRect(x: CGFloat(index) * (width + gap), y: size.height - height, width: width, height: height)
                context.fill(RoundedRectangle(cornerRadius: radius).path(in: bar), with: fill)
            }
        }
    }
}
