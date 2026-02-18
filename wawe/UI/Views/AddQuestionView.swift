import SwiftUI

// MARK: - Добавление вопроса
struct AddQuestionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var prompt = ""
    @State private var answer = ""
    
    var onSave: (String, String) -> Void

    var canSave: Bool {
        !prompt.trimmed.isEmpty && !answer.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый вопрос") {
                    TextField("Вопрос (например, What?)", text: $prompt, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)

                    TextField("Перевод (например, Что?)", text: $answer, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(prompt, answer)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
