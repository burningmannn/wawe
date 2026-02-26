import Foundation
import Combine

final class AppContainer: ObservableObject {
    let store: WordStore
    let wordsRepo: WordsRepositoryStoreAdapter
    let verbsRepo: VerbsRepositoryStoreAdapter
    let questionsRepo: QuestionsRepositoryStoreAdapter
    let notesRepo: NotesRepositoryStoreAdapter
    let testsRepo: TestsRepositoryStoreAdapter
    let settingsRepo: SettingsRepositoryStoreAdapter

    init(store: WordStore = WordStore()) {
        self.store = store
        self.wordsRepo = WordsRepositoryStoreAdapter(store: store)
        self.verbsRepo = VerbsRepositoryStoreAdapter(store: store)
        self.questionsRepo = QuestionsRepositoryStoreAdapter(store: store)
        self.notesRepo = NotesRepositoryStoreAdapter(store: store)
        self.testsRepo = TestsRepositoryStoreAdapter(store: store)
        self.settingsRepo = SettingsRepositoryStoreAdapter(store: store)
    }
}
