import SwiftUI
import Combine

enum QuestionsIntent {
    case search(String)
    case add(prompt: String, answer: String)
    case delete(IndexSet)
    case deleteItem(QuestionItem)
    case update(QuestionItem, prompt: String, answer: String, resetProgress: Bool)
    case markCorrect(QuestionItem)
    case clearAll
    case setSortOrder(SortOrder)
}

struct QuestionsViewState: Equatable {
    var all: [QuestionItem] = []
    var filtered: [QuestionItem] = []
    var search: String = ""
    var repeatLimit: Int = 0
    var sortOrder: SortOrder = .date
}

final class QuestionsViewModel: ObservableObject {
    @Published private(set) var state = QuestionsViewState()
    
    private var cancellables: Set<AnyCancellable> = []
    private let repo: QuestionsRepository
    
    init(repo: QuestionsRepository) {
        self.repo = repo
        bind()
    }
    
    private func bind() {
        repo.questionsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.state.all = items
                self.state.repeatLimit = repo.questionRepeatLimit
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
            repo.add(prompt: prompt, answer: answer)
            
        case .delete(let offsets):
            repo.remove(at: offsets)
            
        case .deleteItem(let item):
            repo.remove(item)

        case .update(let item, let prompt, let answer, let reset):
            repo.update(item, prompt: prompt, answer: answer, resetProgress: reset)
            
        case .markCorrect(let item):
            repo.markCorrect(item)
            
        case .clearAll:
            repo.clearQuestions()
            
        case .setSortOrder(let order):
            state.sortOrder = order
            applyFilter()
        }
    }
    
    private func applyFilter() {
        let q = state.search.normalizedCompareKey
        var result: [QuestionItem]
        
        if q.isEmpty {
            result = state.all
        } else {
            result = state.all.filter {
                $0.prompt.normalizedCompareKey.contains(q) ||
                $0.answer.normalizedCompareKey.contains(q)
            }
        }
        
        switch state.sortOrder {
        case .date: break
        case .progressLowToHigh:
            result.sort { $0.correctCount < $1.correctCount }
        case .progressHighToLow:
            result.sort { $0.correctCount > $1.correctCount }
        }
        
        state.filtered = result
    }
}
