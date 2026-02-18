import SwiftUI

struct AnimatedBadgeBackground: View {
    let style: BadgeStyle
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if style.isAnimated {
                    // Base gradient with smoother cyclic animation
                    LinearGradient(colors: style.chromaticColors, startPoint: animate ? .topLeading : .bottomLeading, endPoint: animate ? .bottomTrailing : .topTrailing)
                        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
                    
                    // Iridescent overlay with smoother movement
                    LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: geo.size.width * 2.5)
                        .offset(x: animate ? geo.size.width : -geo.size.width * 1.5)
                        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: animate)
                } else {
                    style.gradient
                }
            }
        }
        .onAppear {
            if style.isAnimated {
                animate = true
            }
        }
    }
}

struct StreakBadgeBanner: View {
    let title: String
    let style: BadgeStyle
    
    var body: some View {
        HStack(spacing: 6) {
            if !style.iconName.isEmpty {
                Image(systemName: style.iconName)
                    .foregroundStyle(.black)
                    .font(.caption.bold())
            }
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            AnimatedBadgeBackground(style: style)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style.borderColor, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
    }
}

enum BadgeStyle {
    case base
    case pro
    case vip
    case streak(days: Int)
    case year
    case learned(count: Int)
    
    var isAnimated: Bool {
        return true
    }
    
    var chromaticColors: [Color] {
        switch self {
        case .base:
            return [Color(white: 0.95), Color(white: 0.85), Color(white: 0.9)]
        case .pro:
            return [Color.hex("#30D158"), Color.hex("#20A040"), Color.hex("#88E0A0")]
        case .vip:
            return [Color.hex("#FFD700"), Color.hex("#FDB931"), Color.hex("#FFFFE0")]
        case .streak(let d):
            if d >= 120 { return [Color.hex("#FF2D55"), Color.hex("#FF375F"), Color.hex("#FF9F0A")] }
            if d >= 60 { return [Color.hex("#FF9500"), Color.hex("#FF3B30"), Color.hex("#FFCC00")] }
            if d >= 30 { return [Color.hex("#FFCC00"), Color.hex("#FF9500"), Color.hex("#FFD60A")] }
            if d >= 7 { return [Color.hex("#5E5CE6"), Color.hex("#5856D6"), Color.hex("#AF52DE")] }
            return [Color.hex("#32ADE6"), Color.hex("#007AFF"), Color.hex("#5AC8FA")]
        case .year:
            return [Color.hex("#E0E0E0"), Color.hex("#C0C0C0"), Color.hex("#D0D0D0")]
        case .learned(let c):
            if c >= 500 { return [Color.hex("#64D2FF"), Color.hex("#007AFF"), Color.hex("#5AC8FA")] }
            return [Color.hex("#64D2FF"), Color.hex("#5AC8FA"), Color.hex("#007AFF")]
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .base:
            return LinearGradient(colors: [Color(white: 0.95), Color(white: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pro:
            return LinearGradient(colors: [Color.hex("#30D158"), Color.hex("#20A040")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vip:
            return LinearGradient(colors: [Color.hex("#FFD700"), Color.hex("#DAA520"), Color.hex("#B8860B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .streak(let d):
            if d >= 120 { return LinearGradient(colors: [Color.hex("#FF2D55"), Color.hex("#FF375F")], startPoint: .leading, endPoint: .trailing) }
            if d >= 60 { return LinearGradient(colors: [Color.hex("#FF9500"), Color.hex("#FF3B30")], startPoint: .leading, endPoint: .trailing) }
            if d >= 30 { return LinearGradient(colors: [Color.hex("#FFCC00"), Color.hex("#FF9500")], startPoint: .leading, endPoint: .trailing) }
            if d >= 7 { return LinearGradient(colors: [Color.hex("#5E5CE6"), Color.hex("#AF52DE")], startPoint: .leading, endPoint: .trailing) }
            return LinearGradient(colors: [Color.hex("#32ADE6"), Color.hex("#007AFF")], startPoint: .leading, endPoint: .trailing)
        case .year:
            return LinearGradient(colors: [Color.hex("#E0E0E0"), Color.hex("#A0A0A0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .learned(let c):
            if c >= 500 { return LinearGradient(colors: [Color.hex("#64D2FF"), Color.hex("#007AFF")], startPoint: .top, endPoint: .bottom) }
            return LinearGradient(colors: [Color.hex("#64D2FF"), Color.hex("#007AFF")], startPoint: .top, endPoint: .bottom)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .base: return .white.opacity(0.5)
        case .vip: return Color.hex("#FFD700")
        case .year: return .white
        default: return .white.opacity(0.3)
        }
    }
    
    var iconName: String {
        switch self {
        case .base: return ""
        case .pro: return "star.fill"
        case .vip: return "crown.fill"
        case .streak: return "flame.fill"
        case .year: return "calendar"
        case .learned: return "book.closed.fill"
        }
    }
}
