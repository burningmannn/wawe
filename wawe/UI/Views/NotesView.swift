
import SwiftUI
import Combine
import UniformTypeIdentifiers
import PhotosUI
#if os(macOS)
import AppKit
#endif
import Foundation

enum NoteSortOrder: String, CaseIterable, Identifiable {
    case date = "По дате"
    case title = "По имени"
    var id: String { rawValue }
}

// MARK: - Экран заметок
struct NotesView: View {
    @StateObject private var viewModel: NotesViewModel
    @State private var showingAddImageNote = false
    @State private var showingClearAlert = false
    
    init(repo: NotesRepository) {
        _viewModel = StateObject(wrappedValue: NotesViewModel(repo: repo))
    }
    
    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.state.search },
            set: { viewModel.send(.search($0)) }
        )
    }
    
    var body: some View {
            List {
                ForEach(viewModel.state.filtered) { note in
                    NavigationLink {
                        EditImageNoteView(
                            note: note,
                            onSave: { title, url, desc in
                                viewModel.send(.update(note, title: title, imageURL: url, descriptionMarkdown: desc))
                            },
                            onDelete: {
                                viewModel.send(.delete(note))
                            }
                        )
                    } label: {
                        ImageNoteRow(note: note)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.send(.delete(note))
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { index in
                        if index < viewModel.state.filtered.count {
                            let note = viewModel.state.filtered[index]
                            viewModel.send(.delete(note))
                        }
                    }
                }
                .onMove { from, to in
                    viewModel.send(.move(from, to))
                }
            }
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: searchBinding, prompt: "Поиск заметок")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddImageNote = true }) {
                            Label("Создать заметку", systemImage: "plus")
                        }
                        Button(action: { viewModel.send(.addRandom) }) {
                            Label("Случайная заметка", systemImage: "dice")
                        }
                        Button(action: { viewModel.send(.addTwoRandom) }) {
                            Label("Случайные 2", systemImage: "die.face.2")
                        }
                        Button(action: { viewModel.send(.addSamples) }) {
                            Label("Заполнить примерами", systemImage: "photo.on.rectangle")
                        }
                        Divider()
                        Picker("Сортировка", selection: Binding(
                            get: { viewModel.state.sortByTitle ? NoteSortOrder.title : NoteSortOrder.date },
                            set: { viewModel.send(.sortByTitle($0 == .title)) }
                        )) {
                            ForEach(NoteSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        if !viewModel.state.all.isEmpty {
                            Divider()
                            Button(role: .destructive, action: { showingClearAlert = true }) {
                                Label("Удалить все", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        Button(action: { showingAddImageNote = true }) {
                            Label("Создать заметку", systemImage: "plus")
                        }
                        Button(action: { viewModel.send(.addRandom) }) {
                            Label("Случайная заметка", systemImage: "dice")
                        }
                        Picker("Сортировка", selection: Binding(
                            get: { viewModel.state.sortByTitle ? NoteSortOrder.title : NoteSortOrder.date },
                            set: { viewModel.send(.sortByTitle($0 == .title)) }
                        )) {
                            ForEach(NoteSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive, action: { showingClearAlert = true }) {
                                Label("Удалить все", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAddImageNote) {
                AddImageNoteView(onSave: { title, url, desc in
                    viewModel.send(.add(title: title, imageURL: url, descriptionMarkdown: desc))
                })
            }
            .alert("Удалить все заметки?", isPresented: $showingClearAlert) {
                Button("Удалить", role: .destructive) {
                    viewModel.send(.clearAll)
                }
                Button("Отмена", role: .cancel) { }
            }
    }
}

struct ImageNoteRow: View {
    let note: ImageNote
    
    private var imageURL: URL? {
        note.imageURL.normalizedURL
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = imageURL {
                RemoteImage(url: url)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .clipped()
            } else {
                 ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                    Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0/9.0, contentMode: .fit)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                if !note.descriptionMarkdown.isEmpty {
                    Text(note.descriptionMarkdown)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Добавить заметку с картинкой
struct AddImageNoteView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String) -> Void
    @State private var title = ""
    @State private var imageURL = ""
    @State private var descriptionMarkdown = ""
    
    var canSave: Bool {
        !title.trimmed.isEmpty && imageURL.normalizedURL != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Новая заметка") {
                    TextField("Тема", text: $title)
                    TextField("Ссылка на картинку (URL)", text: $imageURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                }
                Section("Описание") {
                    TextEditor(text: $descriptionMarkdown)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let urlToSave = imageURL.trimmed.normalizedURL?.absoluteString ?? imageURL.trimmed
                        onSave(title.trimmed, urlToSave, descriptionMarkdown)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        if canSave {
                            let urlToSave = imageURL.trimmed.normalizedURL?.absoluteString ?? imageURL.trimmed
                            onSave(title.trimmed, urlToSave, descriptionMarkdown)
                            dismiss()
                        }
                    }
                }
#endif
            }
        }
    }
}

// MARK: - Редактировать заметку с картинкой
struct EditImageNoteView: View, Identifiable {
    let id = UUID()
    @Environment(\.dismiss) var dismiss
    let note: ImageNote
    let onSave: (String, String, String) -> Void
    let onDelete: () -> Void
    
    @State private var title: String
    @State private var imageURL: String
    @State private var descriptionMarkdown: String
    
    init(note: ImageNote, onSave: @escaping (String, String, String) -> Void, onDelete: @escaping () -> Void) {
        self.note = note
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: note.title)
        _imageURL = State(initialValue: note.imageURL)
        _descriptionMarkdown = State(initialValue: note.descriptionMarkdown)
    }
    
    var canSave: Bool {
        !title.trimmed.isEmpty && imageURL.normalizedURL != nil
    }
    
    var body: some View {
        Form {
            Section("Редактировать заметку") {
                TextField("Тема", text: $title)
                TextField("Ссылка на картинку (URL)", text: $imageURL)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
            }
            Section("Описание") {
                TextEditor(text: $descriptionMarkdown)
                    .frame(minHeight: 120)
            }
            #if os(iOS)
            Section {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Удалить заметку", systemImage: "trash")
                }
            }
            #endif
        }
        .navigationTitle("")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    if canSave {
                        let urlToSave = imageURL.trimmed.normalizedURL?.absoluteString ?? imageURL.trimmed
                        onSave(title.trimmed, urlToSave, descriptionMarkdown)
                        dismiss()
                    }
                }
                .disabled(!canSave)
            }
#else
            ToolbarItemGroup(placement: .automatic) {
                Button("Готово") {
                    if canSave {
                        let urlToSave = imageURL.trimmed.normalizedURL?.absoluteString ?? imageURL.trimmed
                        onSave(title.trimmed, urlToSave, descriptionMarkdown)
                        dismiss()
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Удалить заметку", systemImage: "trash")
                }
            }
#endif
        }
    }
}
