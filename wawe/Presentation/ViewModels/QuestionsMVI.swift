import SwiftUI
import Combine

enum QuestionsIntent {
    case search(String)
    case add(prompt: String, answer: String)
    case delete(IndexSet)
    case deleteItem(QuestionItem)
    case markCorrect(QuestionItem)
}

struct QuestionsViewState: Equatable {
    var all: [QuestionItem] = []
    var filtered: [QuestionItem] = []
    var search: String = ""
    var repeatLimit: Int = 0
}

final class QuestionsViewModel: ObservableObject {
    @Published private(set) var state = QuestionsViewState()
    
    private var cancellables: Set<AnyCancellable> = []
    private let store: WordStore
    
    init(store: WordStore) {
        self.store = store
        store.$questions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.state.all = items
                self.state.repeatLimit = store.questionRepeatLimit
                self.applyFilter()
            }
            .store(in: &cancellables)
    }
    
    func send(_ intent: QuestionsIntent) {
        switch intent {
        case .search(let q):
            state.search = q
            applyFilter()
            
        case .add(let prompt, let answer):
            store.addQuestion(prompt: prompt, answer: answer)
            
        case .delete(let offsets):
            store.removeQuestion(at: offsets)
            
        case .deleteItem(let item):
            store.removeQuestion(item)
            
        case .markCorrect(let item):
            store.markQuestionCorrect(item)
        }
    }
    
    private func applyFilter() {
        let q = state.search.normalizedCompareKey
        guard !q.isEmpty else {
            state.filtered = state.all
            return
        }
        state.filtered = state.all.filter {
            $0.prompt.normalizedCompareKey.contains(q) ||
            $0.answer.normalizedCompareKey.contains(q)
        }
    }
}
