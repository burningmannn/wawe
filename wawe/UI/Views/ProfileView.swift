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
    private let notesRepo: NotesRepository
    @Environment(\.colorScheme) private var colorScheme

    // Trigger for staggered entrance animations
    @State private var appeared = false
    @State private var showingNotes = false

    private var profileNameBinding: Binding<String> {
        Binding(get: { viewModel.profileName }, set: { viewModel.profileName = $0 })
    }
    private var profileBioBinding: Binding<String> {
        Binding(get: { viewModel.profileBio }, set: { viewModel.profileBio = $0 })
    }

    init(wordsRepo: WordsRepository, verbsRepo: IrregularVerbsRepository,
         questionsRepo: QuestionsRepository, settingsRepo: SettingsRepository,
         notesRepo: NotesRepository) {
        self.settingsRepo = settingsRepo
        self.notesRepo = notesRepo
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingNotes = true } label: {
                        Image(systemName: "note.text")
                    }
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
            .sheet(isPresented: $showingNotes) {
                NavigationStack {
                    NotesView(repo: notesRepo)
                }
            }
    }

    // MARK: - Main content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakHeroSection
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appeared)

                progressSection
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: appeared)

                distributionBarSection
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.22), value: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
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

    private var streakHeroSection: some View {
        let count    = viewModel.streakCount
        let progress = count == 0 ? 0.0 : min(Double(count), 7.0) / 7.0
        let isActive = count > 0
        let ringColor: Color = isActive ? .accentColor : Color.secondary.opacity(0.4)

        return VStack(spacing: 10) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                // Fill
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.9), value: progress)
                // Centre
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: count)
                    Text("дней")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            Text("стрик")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress card

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Прогресс")
                .font(.title2.bold())

            VStack(spacing: 0) {
                ProgressRowCard(
                    icon: "book.fill",
                    label: "Слова",
                    learned: viewModel.learnedWordsCount,
                    total: viewModel.totalWordsCount,
                    color: .catWords
                )
                Divider().padding(.horizontal, 16)
                ProgressRowCard(
                    icon: "textformat.abc",
                    label: "Глаголы",
                    learned: viewModel.learnedVerbsCount,
                    total: viewModel.totalVerbsCount,
                    color: .catVerbs
                )
                Divider().padding(.horizontal, 16)
                ProgressRowCard(
                    icon: "questionmark.circle.fill",
                    label: "Вопросы",
                    learned: viewModel.learnedQuestionsCount,
                    total: viewModel.totalQuestionsCount,
                    color: .catQuestions
                )
            }
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Distribution bar (reference-inspired)

    private var distributionBarSection: some View {
        let w = max(viewModel.learnedWordsCount, 0)
        let v = max(viewModel.learnedVerbsCount, 0)
        let q = max(viewModel.learnedQuestionsCount, 0)
        let total = w + v + q

        return VStack(alignment: .leading, spacing: 12) {
            // Labels row
            HStack(spacing: 0) {
                ForEach([
                    ("Слова",    Color.catWords,     w),
                    ("Глаголы",  Color.catVerbs,     v),
                    ("Вопросы",  Color.catQuestions, q)
                ], id: \.0) { name, color, count in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(color)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(count)")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Coloured strip
            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        if w > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.catWords)
                                .frame(width: geo.size.width * CGFloat(w) / CGFloat(total))
                        }
                        if v > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.catVerbs)
                                .frame(width: geo.size.width * CGFloat(v) / CGFloat(total))
                        }
                        if q > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.catQuestions)
                                .frame(width: geo.size.width * CGFloat(q) / CGFloat(total))
                        }
                    }
                }
                .frame(height: 10)
                .animation(.easeOut(duration: 0.7), value: total)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 10)
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helpers

    private var cardBg: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(white: 0.12))
            : AnyShapeStyle(Color.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: 3)))
    }
}

// MARK: - Progress Row Card

private struct ProgressRowCard: View {
    let icon: String
    let label: String
    let learned: Int
    let total: Int
    let color: Color

    @State private var animProgress: Double = 0

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(learned) / Double(total), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // "X / Y" or just "X изучено"
                Group {
                    if total > 0 {
                        Text("\(learned)")
                            .foregroundStyle(color)
                            .bold()
                        + Text(" / \(total)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(learned) изучено")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.monospacedDigit())
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: learned)
            }

            // Animated progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * animProgress)
                        .animation(.easeOut(duration: 0.85), value: animProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear {
            // Slight delay so the card entrance animation completes first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.85)) {
                    animProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.easeOut(duration: 0.6)) { animProgress = new }
        }
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
