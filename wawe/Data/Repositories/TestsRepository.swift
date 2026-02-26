import Foundation
import Combine

// MARK: - Protocol

protocol TestsRepository {
    var testsPublisher: AnyPublisher<[TestItem], Never> { get }
    func addTestItem(title: String, type: TestItem.TestType, rawContent: String)
    func updateTestItem(_ item: TestItem, title: String, type: TestItem.TestType, rawContent: String)
    func removeTestItem(_ item: TestItem)
    func clearTestItems()
    func addSamples()
}

// MARK: - Store Adapter

final class TestsRepositoryStoreAdapter: TestsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject: CurrentValueSubject<[TestItem], Never>

    init(store: WordStore) {
        self.store = store
        self.subject = CurrentValueSubject(store.testItems)
        store.$testItems
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }

    var testsPublisher: AnyPublisher<[TestItem], Never> {
        subject.eraseToAnyPublisher()
    }

    func addTestItem(title: String, type: TestItem.TestType, rawContent: String) {
        store.addTestItem(title: title, type: type, rawContent: rawContent)
    }

    func updateTestItem(_ item: TestItem, title: String, type: TestItem.TestType, rawContent: String) {
        store.updateTestItem(item, title: title, type: type, rawContent: rawContent)
    }

    func removeTestItem(_ item: TestItem) {
        store.removeTestItem(item)
    }

    func clearTestItems() {
        store.clearTestItems()
    }

    func addSamples() {
        store.addSampleTestItems()
    }
}
