import SwiftUI

struct YearProgressGrid: View {
    let counts: [String: Int]
    let startDate: Date
    let weeks: Int
    let daySize: CGFloat
    let spacing: CGFloat
    let color: Color
    let sequentialCount: Int?

    // MARK: - Internals

    private let today = Calendar.current.startOfDay(for: Date())

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var daysMatrix: [[Date]] {
        var matrix: [[Date]] = []
        let cal = Calendar.current
        var current = startDate
        for _ in 0..<weeks {
            var column: [Date] = []
            for _ in 0..<7 {
                column.append(current)
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
            matrix.append(column)
        }
        return matrix
    }

    // MARK: - Category-based 3-level shading
    // 0 → empty (just border)
    // 1–2 categories done → dim fill
    // 3 categories done  → vivid full colour

    private func shade(for value: Int, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        switch value {
        case 0:     return .clear
        case 1, 2:  return color.opacity(0.35)  // partial day
        default:    return color                 // all 3 done
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { r in
                        let index = w * 7 + r

                        if let seq = sequentialCount {
                            // Sequential mode (streak-style)
                            let filled = index < seq
                            dayCell(fill: filled ? color : .clear, isEmpty: !filled, isFuture: false)
                        } else {
                            // Date-based mode
                            let date  = daysMatrix[w][r]
                            let day   = Calendar.current.startOfDay(for: date)
                            let isFuture = day > today
                            let isToday  = day == today
                            let key   = formatter.string(from: date)
                            let value = counts[key] ?? 0
                            let fill  = shade(for: value, isFuture: isFuture)
                            dayCell(fill: fill, isEmpty: value == 0 && !isFuture, isFuture: isFuture, isToday: isToday)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Single day cell

    @ViewBuilder
    private func dayCell(
        fill: Color,
        isEmpty: Bool,
        isFuture: Bool,
        isToday: Bool = false
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)

            if isEmpty {
                // Subtle border for empty past days (like GitHub's empty cells)
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 0.5)
            }

            if isToday {
                // Thin accent ring on today
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(color.opacity(0.85), lineWidth: 1)
            }
        }
        .frame(width: daySize, height: daySize)
    }
}
