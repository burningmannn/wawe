import SwiftUI
import Combine

final class TestViewModel: ObservableObject {
    @Published var currentWord: Word?
    @Published var answer = ""
    @Published var feedback: String?
    @Published var askTranslation = Bool.random()
    
    private let repo: WordsRepository
    private var allWords: [Word] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: WordsRepository) {
        self.repo = repo
        bind()
    }
    
    private func bind() {
        repo.wordsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] words in
                self?.allWords = words
                if self?.currentWord == nil {
                    self?.nextWord()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkAnswer() {
        guard let word = currentWord else { return }
        let correct = askTranslation ? word.translation : word.original
        let normalizedUser = answer.normalizedCompareKey
        let normalizedCorrect = correct.normalizedCompareKey
        
        if normalizedUser == normalizedCorrect {
            feedback = "Верно!"
            repo.markCorrect(word)
            // Wait a bit or just let the view handle the transition?
            // For now, let's just mark it. The view might need to trigger animation.
            // But usually we want the feedback to show, then move to next.
            // Let's assume the View calls nextWord() after a delay or user action, 
            // OR we can trigger it here after a delay if we want.
            // The original code called nextWord() immediately after animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.nextWord()
            }
        } else {
            feedback = "Правильно: \(correct)"
        }
        answer = ""
    }
    
    func nextWord() {
        feedback = nil
        answer = ""
        askTranslation = Bool.random()
        
        guard !allWords.isEmpty else {
            currentWord = nil
            return
        }
        
        // Simple random selection for now, could be weighted by progress
        currentWord = allWords.randomElement()
    }
    
    var wordRepeatLimit: Int {
        repo.wordRepeatLimit
    }
    
    func getProgress(for word: Word) -> Double {
        guard wordRepeatLimit > 0 else { return 0 }
        return min(Double(word.correctCount) / Double(wordRepeatLimit), 1.0)
    }
}
