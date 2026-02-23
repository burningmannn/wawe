import SwiftUI

// MARK: - Утилиты
extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCompareKey: String {
        self.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func trimmedLowercasedIfNeeded() -> String {
        // лёгкая нормализация: убираем лишние пробелы; регистр не ломаем принудительно,
        // но можно привести к нижнему для консистентности:
        self.trimmed
    }

    var normalizedURL: URL? {
        var s = self.trimmed
        guard !s.isEmpty else { return nil }

        // Fix protocol-relative URLs
        if s.hasPrefix("//") {
            s = "https:" + s
        } else if s.lowercased().hasPrefix("http://") {
            // Upgrade http → https to satisfy ATS
            s = "https://" + s.dropFirst("http://".count)
        } else if !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }

        // Try to create URL directly
        if let url = URL(string: s), let host = url.host, !host.isEmpty {
            return url
        }
        // Try with percent-encoding (handles spaces and special chars in path/query)
        if let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), let host = url.host, !host.isEmpty {
            return url
        }
        return nil
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case date = "По дате"
    case progressLowToHigh = "Прогресс (сначала новые)"
    case progressHighToLow = "Прогресс (сначала изученные)"
    
    var id: String { rawValue }
}

struct AppColors {
    static let sessionBlue = Color.primary
    static let badgeVIP = Color.hex("#FFD60A")
    static let badgeDay1Start = Color.hex("#0A84FF")
    static let badgeDay1End = Color.hex("#5E5CE6")
    static let badge10YR = Color.hex("#64D2FF")
    static let badge8YR = Color.hex("#FF375F")
    static let badgePro = Color.hex("#30D158")
    static let streak1 = Color.primary
    static let streak2 = Color.primary
    static let streak3 = Color.primary
    static let streak4 = Color.primary
    static let streak5 = Color.primary
    static let streak6 = Color.primary
}

extension Color {
    static func hex(_ hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
