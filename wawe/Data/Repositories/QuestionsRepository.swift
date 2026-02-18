import Foundation
import Combine

protocol QuestionsRepository {
    var questionRepeatLimit: Int { get }
    var learnedQuestionsCount: Int { get }
    var questionsPublisher: AnyPublisher<[QuestionItem], Never> { get }
    func add(prompt: String, answer: String)
    func remove(_ question: QuestionItem)
    func remove(at offsets: IndexSet)
    func update(_ question: QuestionItem, prompt: String, answer: String, resetProgress: Bool)
    func markCorrect(_ question: QuestionItem)
    func clearQuestions()
}

final class QuestionsRepositoryStoreAdapter: QuestionsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[QuestionItem], Never>([])
    
    init(store: WordStore) {
        self.store = store
        store.$questions
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
    
    var questionRepeatLimit: Int { store.questionRepeatLimit }
    var learnedQuestionsCount: Int { store.learnedQuestionsTotal }
    var questionsPublisher: AnyPublisher<[QuestionItem], Never> { subject.eraseToAnyPublisher() }
    
    func add(prompt: String, answer: String) { store.addQuestion(prompt: prompt, answer: answer) }
    func remove(_ question: QuestionItem) { store.removeQuestion(question) }
    func remove(at offsets: IndexSet) { store.removeQuestion(at: offsets) }
    func update(_ question: QuestionItem, prompt: String, answer: String, resetProgress: Bool) {
        store.updateQuestion(question, prompt: prompt, answer: answer, resetProgress: resetProgress)
    }
    func markCorrect(_ question: QuestionItem) { store.markQuestionCorrect(question) }
    func clearQuestions() { store.clearQuestions() }
}
