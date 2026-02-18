
import SwiftUI

// MARK: - Общая строка статистики
struct StatisticRow: View {
    let title: String
    let systemImage: String
    let value: Int

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}
