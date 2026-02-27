import SwiftUI

// MARK: - Flow Layout (inline text + input fields)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.frames[i].minX,
                            y: bounds.minY + result.frames[i].minY),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
        var result = LayoutResult()
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += lineHeight + spacing; lineHeight = 0
            }
            result.frames.append(CGRect(origin: .init(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        result.size = CGSize(width: maxWidth, height: y + lineHeight)
        return result
    }
}

// MARK: - Tests List View

struct TestsView: View {
    @StateObject private var viewModel: TestsViewModel
    @State private var search = ""
    @State private var showingAdd = false
    @State private var editingTest: TestItem?
    @State private var showingClearAlert = false

    init(repo: TestsRepository) {
        _viewModel = StateObject(wrappedValue: TestsViewModel(repo: repo))
    }

    var body: some View {
            Group {
                if viewModel.state.filtered.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView(
                            "Нет тестов",
                            systemImage: "pencil.and.list.clipboard",
                            description: Text("Добавь тест через кнопку +")
                        )
                    } else {
                        ContentUnavailableView(
                            "Ничего не найдено",
                            systemImage: "magnifyingglass",
                            description: Text("Измени запрос поиска")
                        )
                    }
                } else {
                    List {
                        ForEach(viewModel.state.filtered) { test in
                            NavigationLink {
                                TestDetailView(
                                    test: test,
                                    onEdit: { editingTest = test },
                                    onDelete: { viewModel.send(.delete(test)) }
                                )
                            } label: {
                                TestRow(test: test)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.send(.delete(test))
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .onDelete { viewModel.send(.deleteAtOffsets($0)) }
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
#if os(iOS)
            .toolbarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск тестов", count: viewModel.state.all.count)
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        Button { showingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    if !viewModel.state.all.isEmpty {
                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Label("Очистить", systemImage: "trash")
                        }
                    }
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddEditTestView { title, type, raw in
                    viewModel.send(.add(title: title, type: type, rawContent: raw))
                }
            }
            .sheet(item: $editingTest) { test in
                AddEditTestView(test: test) { title, type, raw in
                    viewModel.send(.update(test, title: title, type: type, rawContent: raw))
                }
            }
            .alert("Удалить все тесты?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    viewModel.state.all.forEach { viewModel.send(.delete($0)) }
                }
            } message: {
                Text("Действие нельзя отменить. Все тесты будут удалены.")
            }
    }
}

// MARK: - Row

private struct TestRow: View {
    let test: TestItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(test.title)
                .font(.headline)
            HStack(spacing: 6) {
                Image(systemName: test.type == .chooseCorrect ? "checkmark.circle" : "pencil.line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(test.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail View

private struct TestDetailView: View {
    let test: TestItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TestPlayerView(test: test)
            .navigationTitle(test.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Изменить") { onEdit() }
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button("Изменить") { onEdit() }
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                    }
                }
#endif
            }
    }
}

// MARK: - Add / Edit Sheet

struct AddEditTestView: View {
    @Environment(\.dismiss) private var dismiss

    private let existingTest: TestItem?
    private let onSave: (String, TestItem.TestType, String) -> Void

    @State private var title: String
    @State private var type: TestItem.TestType
    @State private var rawContent: String

    init(test: TestItem? = nil, onSave: @escaping (String, TestItem.TestType, String) -> Void) {
        self.existingTest = test
        self.onSave = onSave
        _title      = State(initialValue: test?.title ?? "")
        _type       = State(initialValue: test?.type ?? .chooseCorrect)
        _rawContent = State(initialValue: test?.rawContent ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Название теста", text: $title)
                }

                Section("Тип") {
                    Picker("Тип", selection: $type) {
                        ForEach(TestItem.TestType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextEditor(text: $rawContent)
                        .font(.body.monospaced())
                        .frame(minHeight: 200)
                } header: {
                    Text("Задание")
                } footer: {
                    Text(formatHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existingTest == nil ? "Новый тест" : "Редактировать")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(title, type, rawContent)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var formatHint: String {
        switch type {
        case .chooseCorrect:
            return "+ правильное предложение\n* неправильное предложение"
        case .fillInBlanks:
            return "I like *big orange* (cats). — текст в * * это ответ, (подсказка) — плейсхолдер"
        }
    }
}

// MARK: - Player Router

private struct TestPlayerView: View {
    let test: TestItem

    var body: some View {
        switch test.type {
        case .chooseCorrect:
            ChooseCorrectPlayerView(rawContent: test.rawContent)
        case .fillInBlanks:
            FillInBlanksPlayerView(rawContent: test.rawContent)
        }
    }
}

// MARK: - Choose Correct Player

private struct ChooseCorrectPlayerView: View {
    private let instruction: String
    private let groups: [ChoiceGroup]  // items pre-shuffled per group

    @State private var selectedPerGroup: [UUID: UUID] = [:]  // groupID → selectedItemID

    init(rawContent: String) {
        let parsed = TestItem.parseChooseCorrectGroups(rawContent)
        self.instruction = parsed.instruction
        self.groups = parsed.groups.map { ChoiceGroup(items: $0.items.shuffled()) }
    }

    var body: some View {
        List {
            if !instruction.isEmpty {
                Section {
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        Button {
                            guard selectedPerGroup[group.id] == nil else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPerGroup[group.id] = item.id
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)

                                if selectedPerGroup[group.id] != nil {
                                    if item.isCorrect {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .transition(.scale.combined(with: .opacity))
                                    } else if selectedPerGroup[group.id] == item.id {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedPerGroup[group.id] != nil)
                        .listRowBackground(rowBackground(for: item, in: group))
                    }
                }
            }

            Section {
                Button {
                    withAnimation { selectedPerGroup = [:] }
                } label: {
                    Label("Сбросить", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
    }

    private func rowBackground(for item: ChoiceItem, in group: ChoiceGroup) -> Color? {
        guard let selID = selectedPerGroup[group.id] else { return nil }
        if item.isCorrect   { return Color.green.opacity(0.18) }
        if selID == item.id { return Color.red.opacity(0.18) }
        return nil
    }
}

// MARK: - Fill in Blanks Player

private struct FillInBlanksPlayerView: View {
    private let instruction: String
    private let sentences: [BlankSentence]

    @State private var inputs: [UUID: String] = [:]

    init(rawContent: String) {
        let parsed = TestItem.parseFillInBlanks(rawContent)
        self.instruction = parsed.instruction
        self.sentences = parsed.sentences
    }

    var body: some View {
        List {
            if !instruction.isEmpty {
                Section {
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(sentences) { sentence in
                    SentenceRowView(sentence: sentence, inputs: $inputs)
                        .padding(.vertical, 4)
                }
            }

            Section {
                Button {
                    withAnimation { inputs = [:] }
                } label: {
                    Label("Сбросить", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
    }
}

// MARK: - Sentence Row

private struct SentenceRowView: View {
    let sentence: BlankSentence
    @Binding var inputs: [UUID: String]

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(sentence.segments.enumerated()), id: \.offset) { _, segment in
                segmentView(segment)
            }
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: BlankSegment) -> some View {
        switch segment {
        case .text(let t):
            Text(t).font(.body)
        case .blank(let item):
            BlankFieldView(
                item: item,
                input: Binding(
                    get: { inputs[item.id] ?? "" },
                    set: { inputs[item.id] = $0 }
                )
            )
        }
    }
}

// MARK: - Blank Field

private struct BlankFieldView: View {
    let item: BlankItem
    @Binding var input: String

    private var isEmpty: Bool { input.isEmpty }
    private var isCorrect: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
        item.answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        TextField(item.hint.isEmpty ? "···" : item.hint, text: $input)
            .textFieldStyle(.plain)
#if os(iOS)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
#endif
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 64)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
            )
    }

    private var strokeColor: Color {
        isEmpty ? Color.secondary.opacity(0.35) : (isCorrect ? .green : .red)
    }
    private var fillColor: Color {
        isEmpty ? Color.secondary.opacity(0.06) : (isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
    }
}
