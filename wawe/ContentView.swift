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
    private var accentColor: Color {
        appTheme == "dark" ? .white : .black
    }

    var body: some View {
        TabView {
            WordsView(repo: container.wordsRepo)
                .tabItem {
                    Label("Слова", systemImage: "book")
                }
            
            IrregularVerbsView(repo: container.verbsRepo)
                .tabItem {
                    Label("Глаголы", systemImage: "textformat.abc")
                }

            QuestionsView(repo: container.questionsRepo)
                .tabItem {
                    Label("Вопросы", systemImage: "questionmark.circle")
                }
            
            NotesView(repo: container.notesRepo)
                .tabItem {
                    Label("Заметки", systemImage: "note.text")
                }
            
            ProfileView(
                wordsRepo: container.wordsRepo,
                verbsRepo: container.verbsRepo,
                questionsRepo: container.questionsRepo,
                settingsRepo: container.settingsRepo
            )
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle")
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
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
