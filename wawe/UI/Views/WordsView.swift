import SwiftUI

struct WordsView: View {
    private let repo: WordsRepository
    @StateObject private var viewModel: WordsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""
    @Environment(\.colorScheme) private var colorScheme

    init(repo: WordsRepository) {
        self.repo = repo
        _viewModel = StateObject(wrappedValue: WordsViewModel(repo: repo))
    }

    var filteredWords: [Word] { viewModel.state.filtered }

    @ViewBuilder
    private var listContent: some View {
        List {
            ForEach(filteredWords) { word in
                NavigationLink {
                    EditWordView(
                        word: word,
                        onUpdate: { o, t, reset in
                            viewModel.send(.update(word, original: o, translation: t, resetProgress: reset))
                        },
                        onDelete: {
                            viewModel.send(.deleteItem(word))
                        }
                    )
                } label: {
                    WordRow(word: word, repeatLimit: viewModel.state.repeatLimit)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.send(.deleteItem(word)) } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading) {
                    Button { viewModel.send(.markCorrect(word)) } label: {
                        Label("+1 прогресс", systemImage: "checkmark.circle")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
        }
    }

    var body: some View {
            Group {
                if filteredWords.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Пока пусто", systemImage: "book", description: Text("Добавь слова через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    listContent
#if os(iOS)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            .onChange(of: search) { _, newValue in viewModel.send(.search(newValue)) }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск", count: viewModel.state.all.count)
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Picker("Сортировка", selection: Binding(get: { viewModel.state.sortOrder }, set: { viewModel.send(.setSortOrder($0)) })) {
                                ForEach(SortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        Picker("Сортировка", selection: Binding(get: { viewModel.state.sortOrder }, set: { viewModel.send(.setSortOrder($0)) })) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                    if !viewModel.state.all.isEmpty {
                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Label("Очистить", systemImage: "trash")
                        }
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddWordView { o, t in
                    viewModel.send(.add(original: o, translation: t))
                }
            }
            .sheet(isPresented: $showingTest) {
                TestView(repo: repo)
            }
            .alert("Очистить все слова?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    viewModel.send(.clearAll)
                }
            } message: {
                Text("Действие нельзя отменить. Все слова будут удалены.")
            }
    }
}



// MARK: - Ячейка слова с прогрессом
struct WordRow: View {
    let word: Word
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(word.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(word.original)
                    .font(.headline)
                Spacer()
                Text(word.translation)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(word.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Добавление слова
struct AddWordView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String) -> Void
    @State private var original = ""
    @State private var translation = ""

    var canSave: Bool {
        !original.trimmed.isEmpty && !translation.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новое слово") {
                    TextField("Слово (например, apple)", text: $original)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Перевод (например, яблоко)", text: $translation)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(original, translation)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button("Сохранить") {
                        onSave(original, translation)
                        dismiss()
                    }
                    .disabled(!canSave)

                    Button("Отмена") { dismiss() }
                }
#endif
            }
        }
    }
}

// MARK: - Редактирование слова
struct EditWordView: View {
    @Environment(\.dismiss) var dismiss
    let word: Word
    let onUpdate: (String, String, Bool) -> Void
    let onDelete: () -> Void

    @State private var original: String
    @State private var translation: String

    init(word: Word, onUpdate: @escaping (String, String, Bool) -> Void, onDelete: @escaping () -> Void) {
        self.word = word
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _original = State(initialValue: word.original)
        _translation = State(initialValue: word.translation)
    }

    var body: some View {
        Form {
            Section("Редактировать") {
                TextField("Слово (EN или RU)", text: $original)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Перевод", text: $translation)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
            }

            Section {
                Button("Сбросить прогресс") {
                    onUpdate(original.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Удалить слово", systemImage: "trash")
                }
            }
        }
        .navigationTitle("")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    onUpdate(original.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             false)
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button("Готово") {
                    onUpdate(original.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             false)
                    dismiss()
                }
            }
#endif
        }
    }
}

// MARK: - Тест
struct TestView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: TestViewModel

    init(repo: WordsRepository) {
        _viewModel = StateObject(wrappedValue: TestViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let word = viewModel.currentWord {
                    Text(viewModel.askTranslation ? word.original : word.translation)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextField("Ваш ответ", text: $viewModel.answer, prompt: Text("Введите перевод"))
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                        .onSubmit { viewModel.checkAnswer() }

                    if let feedback = viewModel.feedback {
                        Text(feedback)
                            .font(.headline)
                            .foregroundStyle(feedback == "Верно!" ? .green : .red)
                            .transition(.opacity)
                    }

                    // Прогресс по этому слову
                    ProgressView(value: viewModel.getProgress(for: word))
                    Text("Прогресс: \(word.correctCount)/\(viewModel.wordRepeatLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Проверить") { viewModel.checkAnswer() }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                        Button("Пропустить") { viewModel.nextWord() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView("Нет слов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь слова или снизь порог повторов в Настройках"))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .onAppear { viewModel.nextWord() }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Закрыть") { dismiss() }
                }
#endif
            }
        }
    }
}
