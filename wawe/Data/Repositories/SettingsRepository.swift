import Foundation
import Combine

protocol SettingsRepository {
    func pruneReachedLimit()
    func clearWords()
    func clearVerbs()
    func clearQuestions()
    func exportBackup() -> URL?
    func importBackup(from url: URL) -> Bool
}

final class SettingsRepositoryStoreAdapter: SettingsRepository {
    private let store: WordStore

    init(store: WordStore) {
        self.store = store
    }

    func pruneReachedLimit() {
        store.pruneReachedLimit()
    }

    func clearWords() {
        store.clearWords()
    }

    func clearVerbs() {
        store.clearIrregularVerbs()
    }

    func clearQuestions() {
        store.clearQuestions()
    }

    func exportBackup() -> URL? {
        store.exportBackup()
    }

    func importBackup(from url: URL) -> Bool {
        store.importBackup(from: url)
    }
}
