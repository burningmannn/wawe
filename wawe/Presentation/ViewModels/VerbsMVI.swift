import SwiftUI
import Combine

enum VerbsIntent {
    case search(String)
    case add(infinitive: String, pastSimple: String, pastParticiple: String, translation: String)
    case delete(IndexSet)
    case deleteItem(IrregularVerb)
    case markCorrect(IrregularVerb)
}

struct VerbsViewState: Equatable {
    var all: [IrregularVerb] = []
    var filtered: [IrregularVerb] = []
    var search: String = ""
    var repeatLimit: Int = 0
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
        case .delete(let offsets):
            repo.remove(at: offsets)
        case .deleteItem(let verb):
            repo.remove(verb)
        case .markCorrect(let verb):
            repo.markCorrect(verb)
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
        guard !q.isEmpty else {
            state.filtered = state.all
            return
        }
        state.filtered = state.all.filter {
            $0.infinitive.normalizedCompareKey.contains(q) ||
            $0.pastSimple.normalizedCompareKey.contains(q) ||
            $0.pastParticiple.normalizedCompareKey.contains(q) ||
            $0.translation.normalizedCompareKey.contains(q)
        }
    }
}
