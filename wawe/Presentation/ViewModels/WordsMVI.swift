import SwiftUI
import Combine

enum WordsIntent {
    case search(String)
    case add(original: String, translation: String)
    case delete(IndexSet)
    case deleteItem(Word)
    case markCorrect(Word)
}

struct WordsViewState: Equatable {
    var all: [Word] = []
    var filtered: [Word] = []
    var search: String = ""
    var repeatLimit: Int = 0
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
        case .delete(let offsets):
            repo.removeWord(at: offsets)
        case .deleteItem(let word):
            repo.removeWord(word)
        case .markCorrect(let word):
            repo.markCorrect(word)
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
        guard !q.isEmpty else {
            state.filtered = state.all
            return
        }
        state.filtered = state.all.filter {
            $0.original.normalizedCompareKey.contains(q) ||
            $0.translation.normalizedCompareKey.contains(q)
        }
    }
}
