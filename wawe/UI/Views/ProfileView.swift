//
//  ProfileView.swift
//  wawe
//

import SwiftUI
import PhotosUI
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Palette (reference-inspired vibrant colours)
private extension Color {
    static let catWords     = Color(red: 0.784, green: 0.945, blue: 0.208) // lime
    static let catVerbs     = Color(red: 0.278, green: 0.784, blue: 0.925) // cyan
    static let catQuestions = Color(red: 0.969, green: 0.420, blue: 0.420) // coral
}

// MARK: - ProfileView
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    private let settingsRepo: SettingsRepository
    @Environment(\.colorScheme) private var colorScheme

    // Trigger for staggered entrance animations
    @State private var appeared = false

    private var profileNameBinding: Binding<String> {
        Binding(get: { viewModel.profileName }, set: { viewModel.profileName = $0 })
    }
    private var profileBioBinding: Binding<String> {
        Binding(get: { viewModel.profileBio }, set: { viewModel.profileBio = $0 })
    }

    init(wordsRepo: WordsRepository, verbsRepo: IrregularVerbsRepository,
         questionsRepo: QuestionsRepository, settingsRepo: SettingsRepository) {
        self.settingsRepo = settingsRepo
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            wordsRepo: wordsRepo, verbsRepo: verbsRepo, questionsRepo: questionsRepo))
    }

    var body: some View {
        profileContent
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .principal) {
                    Text("Профиль")
                        .font(.subheadline.weight(.semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { viewModel.showingSettingsSheet = true } label: {
                            Image(systemName: "gearshape")
                        }
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                viewModel.editing.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.editing ? "checkmark" : "pencil")
                        }
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button { viewModel.showingSettingsSheet = true } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.editing.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.editing ? "checkmark" : "pencil")
                    }
                }
#endif
            }
            .sheet(isPresented: $viewModel.showingSettingsSheet) {
                SettingsView(repo: settingsRepo)
            }
    }

    // MARK: - Main content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                streakHeroSection
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appeared)

                bookReadCard
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18), value: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(colorScheme == .dark ? .black : .white).ignoresSafeArea())
        .onAppear { appeared = true }
        .overlay(alignment: .bottom) {
            if viewModel.showCopiedToast {
                Toast(text: "ID скопирован")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .photosPicker(isPresented: $viewModel.showAvatarPicker,
                      selection: $viewModel.avatarPickerItem, matching: .images)
        .sheet(isPresented: $viewModel.showMediaSheet) {
            EditProfileMediaSheet(
                avatarURL: Binding(get: { viewModel.profileAvatarURL },
                                   set: { viewModel.profileAvatarURL = $0 })
            )
        }
        .onChange(of: viewModel.avatarPickerItem) { _, newItem in
#if os(iOS)
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { viewModel.profileAvatarData = data }
                }
            }
#endif
        }
    }

    // MARK: - Streak hero

    /// Opacity for a segment: 4 categories × 25% each = 100%
    private func segmentOpacity(catCount: Int) -> Double {
        switch catCount {
        case 0:     return 0.0
        case 1:     return 0.25
        case 2:     return 0.50
        case 3:     return 0.75
        default:    return 1.0
        }
    }

    /// Get Russian weekday abbreviation for the given number of days ago
    private func weekdayAbbrev(daysAgo: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let idx = cal.component(.weekday, from: date) - 1
        let symbols = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        return symbols[idx]
    }

    private var streakHeroSection: some View {
        let count    = viewModel.streakCount
        let isActive = count > 0
        let countsMap = viewModel.progressCategoryCountsMap
        let cal       = Calendar.current

        // Date formatter (same key format as WordStore)
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale   = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"

        // Last 7 days: index 0 = 6 days ago, index 6 = today
        let opacities: [Double] = (0..<7).map { i in
            let daysAgo = 6 - i
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let catCount = countsMap[fmt.string(from: date)] ?? 0
            return segmentOpacity(catCount: catCount)
        }

        // Ring geometry: 7 equal arcs with small gaps
        let gapFraction  = 2.5 / 360.0
        let segFraction  = (1.0 - 7.0 * gapFraction) / 7.0

        return VStack(spacing: 20) {
            // Premium card container
            VStack(spacing: 20) {
                // Ring with segments
                ZStack {
                    // Background track
                    Circle()
                        .stroke(Color.secondary.opacity(0.10), lineWidth: 12)

                    // 7 daily segments with glow
                    ForEach(0..<7, id: \.self) { i in
                        let start   = Double(i) * (segFraction + gapFraction)
                        let end     = start + segFraction
                        let opacity = opacities[i]

                        Circle()
                            .trim(from: start, to: end)
                            .stroke(
                                opacity > 0
                                    ? Color.accentColor.opacity(opacity)
                                    : Color.clear,
                                style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: opacity > 0 ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8)
                            .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.07), value: opacity)
                    }

                    // Centre label
                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? Color.primary : Color.secondary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: count)
                        Text("дней")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 160, height: 160)

                // Weekday labels below ring
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let daysAgo = 6 - i
                        let isToday = daysAgo == 0
                        VStack {
                            Text(weekdayAbbrev(daysAgo: daysAgo))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)

                // Streak label
                VStack(spacing: 3) {
                    Text("стрик")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("последние 7 дней")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .background(
                colorScheme == .dark
                    ? Color(white: 0.08)
                    : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(
                color: colorScheme == .dark
                    ? Color.clear
                    : Color.black.opacity(0.08),
                radius: 12,
                y: 4
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Book read card

    private var bookReadCard: some View {
        let done = viewModel.bookReadToday
        @GestureState var isPressed = false

        return Button { viewModel.toggleBookRead() } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(done ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: done ? "book.fill" : "book")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(done ? Color.accentColor : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Читал книгу")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(done ? "Отмечено на сегодня" : "Нажми, чтобы отметить")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(done ? Color.accentColor : Color.secondary.opacity(0.3))
                    .animation(.spring(response: 0.3), value: done)
            }
            .padding(16)
            .background(
                done
                    ? LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.12),
                            Color.accentColor.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark
                                ? Color(white: 0.12)
                                : Color.white,
                            colorScheme == .dark
                                ? Color(white: 0.12)
                                : Color.white
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in }
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
    }

    // MARK: - Helpers

    var cardBg: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(white: 0.12))
            : AnyShapeStyle(Color.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: 3)))
    }
}

// MARK: - Progress Row Card

// MARK: - Stat Tile

private struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    let bg: AnyShapeStyle

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: value)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Toast

#if os(iOS) || os(macOS)
struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 8)
    }
}
#endif

// MARK: - EditProfileMediaSheet

#if os(iOS) || os(macOS)
struct EditProfileMediaSheet: View {
    @Binding var avatarURL: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ссылка на аватар")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $avatarURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25)))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Ссылка на аватар")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
#endif
