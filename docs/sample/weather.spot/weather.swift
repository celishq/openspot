import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        VStack(spacing: spot.size.height * 0.02) {
            Image(systemName: spot["icon"] ?? "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: spot.size.height * 0.2))
            Text(spot["temp"] ?? "")
                .font(.system(size: spot.size.height * 0.34, weight: .medium))
                .foregroundStyle(spot.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
