import SwiftUI

struct SpotView: View {
    let spot: SpotInput

    var body: some View {
        VStack(spacing: -2) {
            Text(spot["day"] ?? "")
                .font(.system(size: spot.size.height * 0.16, weight: .semibold))
                .foregroundStyle(.red)
            Text(spot["date"] ?? "")
                .font(.system(size: spot.size.height * 0.42, weight: .medium))
                .foregroundStyle(spot.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
