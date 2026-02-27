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

    private var maxCount: Int { counts.values.max() ?? 0 }

    // MARK: - GitHub-style 4-level intensity
    // 0 → empty (just border)
    // 1 → lightest fill
    // …
    // max → vivid full colour

    private func shade(for value: Int, isFuture: Bool) -> Color {
        // Future dates: invisible
        if isFuture { return .clear }

        // Zero activity: empty placeholder (barely-there border comes via overlay)
        guard maxCount > 0, value > 0 else { return .clear }

        let ratio = min(Double(value) / Double(maxCount), 1.0)
        switch ratio {
        case ..<0.25: return color.opacity(0.28)  // level 1 – lightest
        case 0.25..<0.50: return color.opacity(0.52) // level 2
        case 0.50..<0.75: return color.opacity(0.76) // level 3
        default:         return color              // level 4 – vivid
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
