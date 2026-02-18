import SwiftUI
import Combine

final class QuestionsTestViewModel: ObservableObject {
    @Published var currentQuestion: QuestionItem?
    @Published var answer = ""
    @Published var feedback: String?
    @Published var isCorrect = false
    @Published var askForAnswer = true
    
    private let repo: QuestionsRepository
    private var allQuestions: [QuestionItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: QuestionsRepository) {
        self.repo = repo
        bind()
    }
    
    private func bind() {
        repo.questionsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.allQuestions = items
                
                // Update current question with latest data if it exists
                if let current = self?.currentQuestion,
                   let updated = items.first(where: { $0.id == current.id }) {
                    self?.currentQuestion = updated
                }
                
                if self?.currentQuestion == nil {
                    self?.nextQuestion()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkAnswer() {
        guard let question = currentQuestion else { return }
        let userAnswer = answer.normalizedCompareKey
        let correct = askForAnswer ? question.answer : question.prompt
        let normalizedCorrect = correct.normalizedCompareKey
        
        if userAnswer == normalizedCorrect {
            isCorrect = true
            feedback = "Верно!"
            repo.markCorrect(question)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.nextQuestion()
            }
        } else {
            isCorrect = false
            feedback = "Правильно: \(correct)"
        }
    }
    
    func nextQuestion() {
        answer = ""
        feedback = nil
        isCorrect = false
        
        guard !allQuestions.isEmpty else {
            currentQuestion = nil
            return
        }
        currentQuestion = allQuestions.randomElement()
        askForAnswer = Bool.random()
    }
    
    var repeatLimit: Int {
        repo.questionRepeatLimit
    }
    
    func getProgress(for question: QuestionItem) -> Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(question.correctCount) / Double(repeatLimit), 1.0)
    }
}
