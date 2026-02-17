import Foundation

final class AppContainer {
    let store: WordStore
    let wordsRepo: WordsRepositoryStoreAdapter
    let verbsRepo: VerbsRepositoryStoreAdapter
    let questionsRepo: QuestionsRepositoryStoreAdapter
    let notesRepo: NotesRepositoryStoreAdapter

    init(store: WordStore = WordStore()) {
        self.store = store
        self.wordsRepo = WordsRepositoryStoreAdapter(store: store)
        self.verbsRepo = VerbsRepositoryStoreAdapter(store: store)
        self.questionsRepo = QuestionsRepositoryStoreAdapter(store: store)
        self.notesRepo = NotesRepositoryStoreAdapter(store: store)
    }
}
