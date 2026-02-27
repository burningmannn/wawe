//
//  ContentView.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI

// MARK: - Главный экран
struct ContentView: View {
    let container: AppContainer
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var systemScheme

    init(container: AppContainer) {
        self.container = container
    }

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// The effective scheme used to drive theming (respects system if set to "system")
    private var effectiveScheme: ColorScheme {
        preferredColorScheme ?? systemScheme
    }

    // #C8F135 — neon lime green, как на тёмном референсе
    private static let neonAccent = Color(red: 0.784, green: 0.945, blue: 0.208)

    private var accentColor: Color {
        effectiveScheme == .dark ? Self.neonAccent : .black
    }

    var body: some View {
        TabView {
            NavigationStack {
                WordsView(repo: container.wordsRepo)
            }
            .tabItem {
                Label("Слова", systemImage: "book")
            }

            NavigationStack {
                IrregularVerbsView(repo: container.verbsRepo)
            }
            .tabItem {
                Label("Глаголы", systemImage: "textformat.abc")
            }

            NavigationStack {
                QuestionsView(repo: container.questionsRepo)
            }
            .tabItem {
                Label("Вопросы", systemImage: "questionmark.circle")
            }

            NavigationStack {
                TestsView(repo: container.testsRepo)
            }
            .tabItem {
                Label("Тесты", systemImage: "pencil.and.list.clipboard")
            }

            NavigationStack {
                ProfileView(
                    wordsRepo: container.wordsRepo,
                    verbsRepo: container.verbsRepo,
                    questionsRepo: container.questionsRepo,
                    settingsRepo: container.settingsRepo,
                    notesRepo: container.notesRepo
                )
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle")
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
        .onAppear {
            AppAppearance.apply(scheme: effectiveScheme)
        }
        .onChange(of: appTheme) { _, _ in
            AppAppearance.apply(scheme: effectiveScheme)
        }
        .onChange(of: systemScheme) { _, _ in
            // Re-apply when system switches (only matters when theme = "system")
            if appTheme == "system" {
                AppAppearance.apply(scheme: effectiveScheme)
            }
        }
    }
}

// MARK: - Legacy / Migrated Views
// SettingsView -> UI/Views/SettingsView.swift
// ProfileView -> UI/Views/ProfileView.swift
// NotesView -> UI/Views/NotesView.swift
// WordsView -> UI/Views/WordsView.swift
// IrregularVerbsView -> UI/Views/IrregularVerbsView.swift
// QuestionsView -> UI/Views/QuestionsView.swift

#Preview {
    ContentView(container: AppContainer())
}
