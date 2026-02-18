import SwiftUI
import Combine

enum WordsIntent {
    case search(String)
    case add(original: String, translation: String)
    case update(Word, original: String, translation: String, resetProgress: Bool)
    case delete(IndexSet)
    case deleteItem(Word)
    case clearAll
    case markCorrect(Word)
    case setSortOrder(SortOrder)
}

struct WordsViewState: Equatable {
    var all: [Word] = []
    var filtered: [Word] = []
    var search: String = ""
    var repeatLimit: Int = 0
    var sortOrder: SortOrder = .date
}

final class WordsViewModel: ObservableObject {
    @Published private(set) var state = WordsViewState()

    private let repo: WordsRepository
    private var cancellables = Set<AnyCancellable>()

    init(repo: WordsRepository) {
        self.repo = repo
        bind()
    }

    func send(_ intent: WordsIntent) {
        switch intent {
        case .search(let text):
            state.search = text
            filter()
        case .add(let original, let translation):
            repo.addWord(original: original, translation: translation)
        case .update(let word, let original, let translation, let reset):
            repo.updateWord(word, original: original, translation: translation, resetProgress: reset)
        case .delete(let offsets):
            repo.removeWord(at: offsets)
        case .deleteItem(let word):
            repo.removeWord(word)
        case .clearAll:
            repo.clearWords()
        case .markCorrect(let word):
            repo.markCorrect(word)
        case .setSortOrder(let order):
            state.sortOrder = order
            filter()
        }
    }

    private func bind() {
        repo.wordsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] words in
                guard let self else { return }
                self.state.all = words
                self.state.repeatLimit = repo.wordRepeatLimit
                self.filter()
            }
            .store(in: &cancellables)
    }

    private func filter() {
        let q = state.search.normalizedCompareKey
        var result: [Word]
        
        if q.isEmpty {
            result = state.all
        } else {
            result = state.all.filter {
                $0.original.normalizedCompareKey.contains(q) ||
                $0.translation.normalizedCompareKey.contains(q)
            }
        }
        
        switch state.sortOrder {
        case .date:
            // Assuming creation order is stable or we don't care
            break
        case .progressLowToHigh:
            result.sort { $0.correctCount < $1.correctCount }
        case .progressHighToLow:
            result.sort { $0.correctCount > $1.correctCount }
        }
        
        state.filtered = result
    }
}
