import SwiftUI

// MARK: - Тест по вопросам
struct QuestionTestView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: QuestionsTestViewModel
    
    init(repo: QuestionsRepository) {
        _viewModel = StateObject(wrappedValue: QuestionsTestViewModel(repo: repo))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let question = viewModel.currentQuestion {
                    Text(viewModel.askForAnswer ? question.prompt : question.answer)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextField(viewModel.askForAnswer ? "Ваш ответ" : "Формулировка вопроса", text: $viewModel.answer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)
                        .onSubmit {
                            viewModel.checkAnswer()
                        }

                    if let feedback = viewModel.feedback {
                        Text(feedback)
                        .font(.headline)
                        .foregroundStyle(viewModel.isCorrect ? .green : .red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                    }
                    
                    ProgressView(value: viewModel.getProgress(for: question))
                    Text("Прогресс: \(question.correctCount)/\(viewModel.repeatLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("Проверить") {
                            viewModel.checkAnswer()
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(.black)
                        .disabled(viewModel.answer.trimmed.isEmpty)

                        Button("Пропустить") {
                            viewModel.nextQuestion()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView("Нет вопросов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь вопросы или снизь порог повторов в Настройках"))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
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
