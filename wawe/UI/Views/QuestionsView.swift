
import SwiftUI
import Combine

// MARK: - Экран вопросов
struct QuestionsView: View {
    @StateObject private var viewModel: QuestionsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""
    private let repo: QuestionsRepository

    init(repo: QuestionsRepository) {
        self.repo = repo
        _viewModel = StateObject(wrappedValue: QuestionsViewModel(repo: repo))
    }
    
    var filteredQuestions: [QuestionItem] { viewModel.state.filtered }

    var body: some View {
        NavigationStack {
            Group {
                if filteredQuestions.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Нет вопросов", systemImage: "questionmark.circle", description: Text("Добавь вопросы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего вопросов", systemImage: "number.square", value: viewModel.state.all.count)
                            if filteredQuestions.count != viewModel.state.all.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredQuestions.count)
                            }
                        }

                        ForEach(filteredQuestions) { question in
                            NavigationLink {
                                EditQuestionView(question: question,
                                                 onSave: { q, p, a, r in
                                    viewModel.send(.update(q, prompt: p, answer: a, resetProgress: r))
                                }, onDelete: { q in
                                    viewModel.send(.deleteItem(q))
                                })
                            } label: {
                                QuestionRow(question: question, repeatLimit: viewModel.state.repeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { viewModel.send(.deleteItem(question)) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { viewModel.send(.markCorrect(question)) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.primary)
                            }
                        }
                        .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
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
                    ToolbarSearchField(text: $search, prompt: "Поиск")
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
                AddQuestionView { p, a in
                    viewModel.send(.add(prompt: p, answer: a))
                }
            }
            .sheet(isPresented: $showingTest) {
                QuestionTestView(repo: repo)
            }
            .alert("Удалить все вопросы?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    viewModel.send(.clearAll)
                }
            } message: {
                Text("Действие нельзя отменить. Все вопросы будут удалены.")
            }
        }
    }
}

// MARK: - Ячейка вопроса
struct QuestionRow: View {
    let question: QuestionItem
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(question.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt)
                .font(.headline)

            Text(question.answer)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(question.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}
