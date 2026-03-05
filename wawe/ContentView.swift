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

    // Deep purple — единый акцент для тёмной и светлой темы
    private static let crimsonAccent = Color(red: 0.58, green: 0.28, blue: 0.88)

    private var accentColor: Color {
        Self.crimsonAccent
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
                NotesView(repo: container.notesRepo)
            }
            .tabItem {
                Label("Заметки", systemImage: "note.text")
            }

            NavigationStack {
                ProfileView(
                    wordsRepo: container.wordsRepo,
                    verbsRepo: container.verbsRepo,
                    settingsRepo: container.settingsRepo
                )
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle")
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
        .onAppear {
            #if canImport(UIKit)
            AppAppearance.apply(scheme: effectiveScheme)
            #endif
        }
        .onChange(of: appTheme) { _, _ in
            #if canImport(UIKit)
            AppAppearance.apply(scheme: effectiveScheme)
            #endif
        }
        .onChange(of: systemScheme) { _, _ in
            if appTheme == "system" {
                #if canImport(UIKit)
                AppAppearance.apply(scheme: effectiveScheme)
                #endif
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

#Preview {
    ContentView(container: AppContainer())
}
