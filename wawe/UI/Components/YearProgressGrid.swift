import SwiftUI

struct YearProgressGrid: View {
    let counts: [String: Int]
    let startDate: Date
    let weeks: Int
    let daySize: CGFloat
    let spacing: CGFloat
    let color: Color
    let sequentialCount: Int?
    
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
            for i in 0..<7 {
                column.append(current)
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
            matrix.append(column)
        }
        return matrix
    }
    private var maxCount: Int {
        counts.values.max() ?? 0
    }
    private func shade(for value: Int) -> Color {
        guard maxCount > 0 else { return Color.secondary.opacity(0.12) }
        let ratio = min(Double(value) / Double(maxCount), 1.0)
        if ratio == 0 { return Color.secondary.opacity(0.12) }
        if ratio < 0.25 { return color.opacity(0.35) }
        if ratio < 0.5 { return color.opacity(0.55) }
        if ratio < 0.75 { return color.opacity(0.75) }
        return color.opacity(0.95)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { r in
                        let index = w * 7 + r
                        if let seq = sequentialCount {
                            let filled = index < seq
                            RoundedRectangle(cornerRadius: 2)
                                .fill(filled ? color.opacity(0.95) : Color.secondary.opacity(0.12))
                                .frame(width: daySize, height: daySize)
                        } else {
                            let date = daysMatrix[w][r]
                            let key = formatter.string(from: date)
                            let value = counts[key] ?? 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(shade(for: value))
                                .frame(width: daySize, height: daySize)
                        }
                    }
                }
            }
        }
    }
}
