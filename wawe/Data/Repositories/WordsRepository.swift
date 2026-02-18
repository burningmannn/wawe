import Foundation
import Combine

protocol WordsRepository {
    var wordRepeatLimit: Int { get }
    var learnedWordsCount: Int { get }
    var wordsPublisher: AnyPublisher<[Word], Never> { get }
    func addWord(original: String, translation: String)
    func removeWord(_ word: Word)
    func removeWord(at offsets: IndexSet)
    func updateWord(_ word: Word, original: String, translation: String, resetProgress: Bool)
    func markCorrect(_ word: Word)
    func clearWords()
}

final class WordsRepositoryStoreAdapter: WordsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[Word], Never>([])

    init(store: WordStore) {
        self.store = store
        store.$words
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }

    var wordRepeatLimit: Int { store.wordRepeatLimit }
    var learnedWordsCount: Int { store.learnedWordsTotal }
    var wordsPublisher: AnyPublisher<[Word], Never> { subject.eraseToAnyPublisher() }

    func addWord(original: String, translation: String) { store.addWord(original: original, translation: translation) }
    func removeWord(_ word: Word) { store.removeWord(word) }
    func removeWord(at offsets: IndexSet) { store.removeWord(at: offsets) }
    func updateWord(_ word: Word, original: String, translation: String, resetProgress: Bool) { store.updateWord(word, original: original, translation: translation, resetProgress: resetProgress) }
    func markCorrect(_ word: Word) { store.markCorrect(word) }
    func clearWords() { store.clearWords() }
}
