
import SwiftUI
import Combine

// MARK: - Экран неправильных глаголов
struct IrregularVerbsView: View {
    private let repo: IrregularVerbsRepository
    @StateObject private var viewModel: VerbsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""
    @Environment(\.colorScheme) private var colorScheme
    
    init(repo: IrregularVerbsRepository) {
        self.repo = repo
        _viewModel = StateObject(wrappedValue: VerbsViewModel(repo: repo))
    }
    
    var filteredVerbs: [IrregularVerb] { viewModel.state.filtered }

    var body: some View {
            Group {
                if filteredVerbs.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Нет неправильных глаголов", systemImage: "textformat.abc", description: Text("Добавь глаголы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        ForEach(filteredVerbs) { verb in
                            NavigationLink {
                                EditIrregularVerbView(
                                    verb: verb,
                                    onUpdate: { inf, ps, pp, tr, reset in
                                        viewModel.send(.update(verb, infinitive: inf, pastSimple: ps, pastParticiple: pp, translation: tr, resetProgress: reset))
                                    },
                                    onDelete: {
                                        viewModel.send(.deleteItem(verb))
                                    }
                                )
                            } label: {
                                IrregularVerbRow(verb: verb, repeatLimit: viewModel.state.repeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.send(.deleteItem(verb)) } label: {
                                    Label("Удалить", systemImage: "trash")
                    }
                    .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { viewModel.send(.markCorrect(verb)) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.primary)
                            }
                        }
                        .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
                    }
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
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddIrregularVerbView { inf, ps, pp, tr in
                    viewModel.send(.add(infinitive: inf, pastSimple: ps, pastParticiple: pp, translation: tr))
                }
            }
            .sheet(isPresented: $showingTest) {
                StepByStepVerbTestView(repo: repo)
            }
            .alert("Удалить все глаголы?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    viewModel.send(.clearAll)
                }
            } message: {
                Text("Действие нельзя отменить. Все глаголы будут удалены.")
            }
    }
}

// MARK: - Ячейка неправильного глагола
struct IrregularVerbRow: View {
    let verb: IrregularVerb
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(verb.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verb.infinitive)
                    .font(.headline)
                Text("–")
                    .foregroundStyle(.secondary)
                Text(verb.pastSimple)
                    .font(.headline)
                Text("–")
                    .foregroundStyle(.secondary)
                Text(verb.pastParticiple)
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Text(verb.translation)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                .frame(maxWidth: .infinity)
                Text("\(verb.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Добавление неправильного глагола
struct AddIrregularVerbView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String, String) -> Void
    
    @State private var infinitive = ""
    @State private var pastSimple = ""
    @State private var pastParticiple = ""
    @State private var translation = ""
    
    var canSave: Bool {
        !infinitive.trimmed.isEmpty &&
        !pastSimple.trimmed.isEmpty &&
        !pastParticiple.trimmed.isEmpty &&
        !translation.trimmed.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Новый глагол") {
                    TextField("Инфинитив (be)", text: $infinitive)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Past Simple (was/were)", text: $pastSimple)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Past Participle (been)", text: $pastParticiple)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Перевод (быть)", text: $translation)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                }
                
                Section {
                    Text("Пример: be – was/were – been (быть)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(infinitive, pastSimple, pastParticiple, translation)
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
                        onSave(infinitive, pastSimple, pastParticiple, translation)
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

// MARK: - Редактирование неправильного глагола
struct EditIrregularVerbView: View {
    @Environment(\.dismiss) var dismiss
    let verb: IrregularVerb
    let onUpdate: (String, String, String, String, Bool) -> Void
    let onDelete: () -> Void

    @State private var infinitive: String
    @State private var pastSimple: String
    @State private var pastParticiple: String
    @State private var translation: String

    init(verb: IrregularVerb,
         onUpdate: @escaping (String, String, String, String, Bool) -> Void,
         onDelete: @escaping () -> Void) {
        self.verb = verb
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _infinitive = State(initialValue: verb.infinitive)
        _pastSimple = State(initialValue: verb.pastSimple)
        _pastParticiple = State(initialValue: verb.pastParticiple)
        _translation = State(initialValue: verb.translation)
    }

    var body: some View {
        Form {
            Section("Редактировать глагол") {
                TextField("Инфинитив", text: $infinitive)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Past Simple", text: $pastSimple)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Past Participle", text: $pastParticiple)
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
                    onUpdate(infinitive.trimmedLowercasedIfNeeded(),
                             pastSimple.trimmedLowercasedIfNeeded(),
                             pastParticiple.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Удалить глагол", systemImage: "trash")
                }
            }
        }
        .navigationTitle("")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    onUpdate(infinitive.trimmedLowercasedIfNeeded(),
                             pastSimple.trimmedLowercasedIfNeeded(),
                             pastParticiple.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             false)
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button("Готово") {
                    onUpdate(infinitive.trimmedLowercasedIfNeeded(),
                             pastSimple.trimmedLowercasedIfNeeded(),
                             pastParticiple.trimmedLowercasedIfNeeded(),
                             translation.trimmedLowercasedIfNeeded(),
                             false)
                    dismiss()
                }
            }
#endif
        }
    }
}

// MARK: - Пошаговый тест неправильных глаголов
struct StepByStepVerbTestView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: VerbsTestViewModel
    
    init(repo: IrregularVerbsRepository) {
        _viewModel = StateObject(wrappedValue: VerbsTestViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if viewModel.currentVerb != nil {
                    // Progress indicator как на картинке
                    StepProgressView(currentStep: viewModel.currentStep, totalSteps: viewModel.totalSteps, isCorrect: viewModel.isCorrect)
                        .padding(.horizontal)
                    
                    // Текущий вопрос
                    VStack(spacing: 20) {
                        Text(viewModel.currentPrompt)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        TextField("Ваш ответ", text: $viewModel.answer)
                            .textFieldStyle(.roundedBorder)
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .autocorrectionDisabled()
                            .onSubmit { viewModel.checkAnswer() }
#if os(iOS)
                            .font(.title3)
#else
                            .font(.title2)
#endif
                    }
                    
                    if let feedback = viewModel.feedback {
                        Text(feedback)
                            .font(.headline)
                            .foregroundStyle(viewModel.isCorrect ? .green : .red)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    
                    // Кнопки
                    HStack(spacing: 20) {
                        Button("Проверить") { viewModel.checkAnswer() }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                            .disabled(viewModel.answer.trimmed.isEmpty)
                        
                        Button("Пропустить") { viewModel.skipStep() }
                            .buttonStyle(.bordered)
                    }
                    
                } else {
                    ContentUnavailableView("Нет глаголов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь глаголы или снизь порог повторов в Настройках"))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
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
            .onAppear { viewModel.startNewVerb() }
        }
    }
}

// MARK: - Индикатор прогресса по шагам
struct StepProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    let isCorrect: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...totalSteps, id: \.self) { step in
                HStack(spacing: 0) {
                    // Кружок для шага
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 40, height: 40)
                        
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                        } else if step == currentStep {
                            Text("\(step)")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Text("\(step)")
                                .foregroundColor(.gray)
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    
                    // Линия между шагами
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    func stepColor(for step: Int) -> Color {
        if step < currentStep {
            return .blue // Завершенные шаги
        } else if step == currentStep {
            return .blue // Текущий шаг
        } else {
            return .gray.opacity(0.3) // Будущие шаги
        }
    }
}
