//
//  SettingsView.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Настройки
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage("appTheme") private var appTheme: String = "system"

    init(repo: SettingsRepository) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(repo: repo))
    }

    private var wordLimitBinding: Binding<Int> {
        Binding(
            get: { viewModel.wordRepeatLimit },
            set: { viewModel.wordRepeatLimit = $0 }
        )
    }
    
    private var verbLimitBinding: Binding<Int> {
        Binding(
            get: { viewModel.verbRepeatLimit },
            set: { viewModel.verbRepeatLimit = $0 }
        )
    }
    
    private var questionLimitBinding: Binding<Int> {
        Binding(
            get: { viewModel.questionRepeatLimit },
            set: { viewModel.questionRepeatLimit = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Лимиты повторов") {
                    Stepper("Слова: \(viewModel.wordRepeatLimit)", value: wordLimitBinding, in: 1...100)
                    Stepper("Глаголы: \(viewModel.verbRepeatLimit)", value: verbLimitBinding, in: 1...100)
                    Stepper("Вопросы: \(viewModel.questionRepeatLimit)", value: questionLimitBinding, in: 1...100)
                    Text("После достижения лимита элемент автоматически переносится в изученные.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Внешний вид") {
                    Picker("Тема", selection: $appTheme) {
                        Text("Авто").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }
                }

                Section("Экспорт и импорт") {
                    Button(action: { viewModel.exportBackup() }) {
                        Label("Экспортировать данные", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        viewModel.showingImportSheet = true
                    } label: {
                        Label("Импортировать данные", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    Button {
                        viewModel.showingAbout = true
                    } label: {
                        Text("О приложении v1.0")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Настройки")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") { dismiss() }
                }
#endif
            }
            .sheet(item: $viewModel.exportShareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $viewModel.showingAbout) {
                AboutView()
            }
            
            .fileImporter(
                isPresented: $viewModel.showingImportSheet,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleImport(result: result)
            }
            .alert("Импорт", isPresented: $viewModel.showingAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}
