import SwiftUI
import Combine

enum VerbsIntent {
    case search(String)
    case add(infinitive: String, pastSimple: String, pastParticiple: String, translation: String)
    case update(IrregularVerb, infinitive: String, pastSimple: String, pastParticiple: String, translation: String, resetProgress: Bool)
    case delete(IndexSet)
    case deleteItem(IrregularVerb)
    case clearAll
    case markCorrect(IrregularVerb)
    case setSortOrder(SortOrder)
}

struct VerbsViewState: Equatable {
    var all: [IrregularVerb] = []
    var filtered: [IrregularVerb] = []
    var search: String = ""
    var repeatLimit: Int = 0
    var sortOrder: SortOrder = .date
}

final class VerbsViewModel: ObservableObject {
    @Published private(set) var state = VerbsViewState()
    private let repo: IrregularVerbsRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: IrregularVerbsRepository) {
        self.repo = repo
        bind()
    }
    
    func send(_ intent: VerbsIntent) {
        switch intent {
        case .search(let text):
            state.search = text
            filter()
        case .add(let i, let ps, let pp, let t):
            repo.add(infinitive: i, pastSimple: ps, pastParticiple: pp, translation: t)
        case .update(let verb, let i, let ps, let pp, let t, let reset):
            repo.update(verb, infinitive: i, pastSimple: ps, pastParticiple: pp, translation: t, resetProgress: reset)
        case .delete(let offsets):
            repo.remove(at: offsets)
        case .deleteItem(let verb):
            repo.remove(verb)
        case .clearAll:
            repo.clearVerbs()
        case .markCorrect(let verb):
            repo.markCorrect(verb)
        case .setSortOrder(let order):
            state.sortOrder = order
            filter()
        }
    }
    
    private func bind() {
        repo.verbsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] verbs in
                guard let self else { return }
                self.state.all = verbs
                self.state.repeatLimit = repo.verbRepeatLimit
                self.filter()
            }
            .store(in: &cancellables)
    }
    
    private func filter() {
        let q = state.search.normalizedCompareKey
        var result: [IrregularVerb]
        
        if q.isEmpty {
            result = state.all
        } else {
            result = state.all.filter {
                $0.infinitive.normalizedCompareKey.contains(q) ||
                $0.pastSimple.normalizedCompareKey.contains(q) ||
                $0.pastParticiple.normalizedCompareKey.contains(q) ||
                $0.translation.normalizedCompareKey.contains(q)
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
