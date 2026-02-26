import Foundation
import Combine

// MARK: - Intent

enum TestsIntent {
    case search(String)
    case add(title: String, type: TestItem.TestType, rawContent: String)
    case update(TestItem, title: String, type: TestItem.TestType, rawContent: String)
    case delete(TestItem)
    case deleteAtOffsets(IndexSet)
    case addSamples
}

// MARK: - ViewState

struct TestsViewState: Equatable {
    var all: [TestItem] = []
    var filtered: [TestItem] = []
    var searchText: String = ""
}

// MARK: - ViewModel

final class TestsViewModel: ObservableObject {
    @Published private(set) var state = TestsViewState()

    private let repo: TestsRepository
    private var cancellables = Set<AnyCancellable>()

    init(repo: TestsRepository) {
        self.repo = repo
        bind()
    }

    func send(_ intent: TestsIntent) {
        switch intent {
        case .search(let text):
            state.searchText = text
            filter()
        case .add(let title, let type, let rawContent):
            repo.addTestItem(title: title, type: type, rawContent: rawContent)
        case .update(let item, let title, let type, let rawContent):
            repo.updateTestItem(item, title: title, type: type, rawContent: rawContent)
        case .delete(let item):
            repo.removeTestItem(item)
        case .deleteAtOffsets(let offsets):
            offsets.forEach { idx in
                guard idx < state.filtered.count else { return }
                repo.removeTestItem(state.filtered[idx])
            }
        case .addSamples:
            repo.addSamples()
        }
    }

    private func bind() {
        repo.testsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.state.all = items
                self.filter()
            }
            .store(in: &cancellables)
    }

    private func filter() {
        let key = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty {
            state.filtered = state.all
        } else {
            state.filtered = state.all.filter {
                $0.title.lowercased().contains(key) ||
                $0.rawContent.lowercased().contains(key)
            }
        }
    }
}
