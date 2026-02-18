import SwiftUI

// MARK: - Редактирование вопроса
struct EditQuestionView: View {
    @Environment(\.dismiss) var dismiss
    let question: QuestionItem
    
    var onSave: (QuestionItem, String, String, Bool) -> Void
    var onDelete: (QuestionItem) -> Void

    @State private var prompt: String
    @State private var answer: String

    init(question: QuestionItem, 
         onSave: @escaping (QuestionItem, String, String, Bool) -> Void,
         onDelete: @escaping (QuestionItem) -> Void) {
        self.question = question
        self.onSave = onSave
        self.onDelete = onDelete
        _prompt = State(initialValue: question.prompt)
        _answer = State(initialValue: question.answer)
    }

    var body: some View {
        Form {
            Section("Редактировать вопрос") {
                TextField("Вопрос (например, What?)", text: $prompt, axis: .vertical)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                TextField("Перевод (например, Что?)", text: $answer, axis: .vertical)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
            }

            Section {
                Button("Сбросить прогресс") {
                    onSave(question,
                           prompt.trimmedLowercasedIfNeeded(),
                           answer.trimmedLowercasedIfNeeded(),
                           true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    onDelete(question)
                    dismiss()
                } label: {
                    Label("Удалить вопрос", systemImage: "trash")
                }
            }
        }
        .navigationTitle("")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    onSave(question,
                           prompt.trimmedLowercasedIfNeeded(),
                           answer.trimmedLowercasedIfNeeded(),
                           false)
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button("Готово") {
                    onSave(question,
                           prompt.trimmedLowercasedIfNeeded(),
                           answer.trimmedLowercasedIfNeeded(),
                           false)
                    dismiss()
                }
            }
#endif
        }
    }
}
