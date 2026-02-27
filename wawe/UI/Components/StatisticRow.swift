
import SwiftUI

// Kept for potential reuse; yellow background removed — plain style only
struct StatisticRow: View {
    let title: String
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(value)")
                .font(.title3.bold())
                .monospacedDigit()
        }
    }
}
