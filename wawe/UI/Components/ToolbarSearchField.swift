
import SwiftUI

struct ToolbarSearchField: View {
    @Binding var text: String
    var prompt: String = "Поиск"
    /// Optional total count shown as a small badge when not searching
    var count: Int? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption.weight(.medium))
            TextField(prompt, text: $text)
                .font(.subheadline)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if let count {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(searchBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 200)
    }

    @ViewBuilder
    private var searchBg: some View {
        if colorScheme == .dark {
            Color.secondary.opacity(0.15)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        }
    }
}
