import Foundation
import Combine

protocol WordsRepository {
    var wordRepeatLimit: Int { get }
    var wordsPublisher: AnyPublisher<[Word], Never> { get }
    func addWord(original: String, translation: String)
    func removeWord(_ word: Word)
    func removeWord(at offsets: IndexSet)
    func updateWord(_ word: Word, original: String, translation: String, resetProgress: Bool)
    func markCorrect(_ word: Word)
}

protocol IrregularVerbsRepository {
    var verbRepeatLimit: Int { get }
    var verbsPublisher: AnyPublisher<[IrregularVerb], Never> { get }
    func add(infinitive: String, pastSimple: String, pastParticiple: String, translation: String)
    func remove(_ verb: IrregularVerb)
    func remove(at offsets: IndexSet)
    func update(_ verb: IrregularVerb, infinitive: String, pastSimple: String, pastParticiple: String, translation: String, resetProgress: Bool)
    func markCorrect(_ verb: IrregularVerb)
}

protocol QuestionsRepository {
    var questionRepeatLimit: Int { get }
    var questionsPublisher: AnyPublisher<[QuestionItem], Never> { get }
    func add(prompt: String, answer: String)
    func remove(_ question: QuestionItem)
    func remove(at offsets: IndexSet)
    func update(_ question: QuestionItem, prompt: String, answer: String, resetProgress: Bool)
    func markCorrect(_ question: QuestionItem)
}

protocol NotesRepository {
    var notesPublisher: AnyPublisher<[FlexNoteTable], Never> { get }
    func addTable(title: String, headers: [String], footer: [String])
    func updateCell(table: FlexNoteTable, row: Int, column: Int, value: String)
    func addRow(table: FlexNoteTable)
    func addColumn(table: FlexNoteTable, header: String)
    func removeColumn(table: FlexNoteTable, at index: Int)
    func updateHeader(table: FlexNoteTable, at index: Int, value: String)
    func updateFooter(table: FlexNoteTable, footer: [String])
    func removeTable(_ table: FlexNoteTable)
}

final class WordsRepositoryStoreAdapter: WordsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[Word], Never>([])

    init(store: WordStore) {
        self.store = store
        store.$words
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }

    var wordRepeatLimit: Int { store.wordRepeatLimit }
    var wordsPublisher: AnyPublisher<[Word], Never> { subject.eraseToAnyPublisher() }

    func addWord(original: String, translation: String) { store.addWord(original: original, translation: translation) }
    func removeWord(_ word: Word) { store.removeWord(word) }
    func removeWord(at offsets: IndexSet) { store.removeWord(at: offsets) }
    func updateWord(_ word: Word, original: String, translation: String, resetProgress: Bool) { store.updateWord(word, original: original, translation: translation, resetProgress: resetProgress) }
    func markCorrect(_ word: Word) { store.markCorrect(word) }
}

final class VerbsRepositoryStoreAdapter: IrregularVerbsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[IrregularVerb], Never>([])
    
    init(store: WordStore) {
        self.store = store
        store.$irregularVerbs
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
    
    var verbRepeatLimit: Int { store.verbRepeatLimit }
    var verbsPublisher: AnyPublisher<[IrregularVerb], Never> { subject.eraseToAnyPublisher() }
    
    func add(infinitive: String, pastSimple: String, pastParticiple: String, translation: String) {
        store.addIrregularVerb(infinitive: infinitive, pastSimple: pastSimple, pastParticiple: pastParticiple, translation: translation)
    }
    func remove(_ verb: IrregularVerb) { store.removeIrregularVerb(verb) }
    func remove(at offsets: IndexSet) { store.removeIrregularVerb(at: offsets) }
    func update(_ verb: IrregularVerb, infinitive: String, pastSimple: String, pastParticiple: String, translation: String, resetProgress: Bool) {
        store.updateIrregularVerb(verb, infinitive: infinitive, pastSimple: pastSimple, pastParticiple: pastParticiple, translation: translation, resetProgress: resetProgress)
    }
    func markCorrect(_ verb: IrregularVerb) { store.markIrregularVerbCorrect(verb) }
}

final class QuestionsRepositoryStoreAdapter: QuestionsRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[QuestionItem], Never>([])
    
    init(store: WordStore) {
        self.store = store
        store.$questions
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
    
    var questionRepeatLimit: Int { store.questionRepeatLimit }
    var questionsPublisher: AnyPublisher<[QuestionItem], Never> { subject.eraseToAnyPublisher() }
    
    func add(prompt: String, answer: String) { store.addQuestion(prompt: prompt, answer: answer) }
    func remove(_ question: QuestionItem) { store.removeQuestion(question) }
    func remove(at offsets: IndexSet) { store.removeQuestion(at: offsets) }
    func update(_ question: QuestionItem, prompt: String, answer: String, resetProgress: Bool) {
        store.updateQuestion(question, prompt: prompt, answer: answer, resetProgress: resetProgress)
    }
    func markCorrect(_ question: QuestionItem) { store.markQuestionCorrect(question) }
}

final class NotesRepositoryStoreAdapter: NotesRepository {
    private let store: WordStore
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<[FlexNoteTable], Never>([])
    
    init(store: WordStore) {
        self.store = store
        store.$notesTables
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
    
    var notesPublisher: AnyPublisher<[FlexNoteTable], Never> { subject.eraseToAnyPublisher() }
    
    func addTable(title: String, headers: [String], footer: [String]) { store.addNoteTable(title: title, headers: headers, footer: footer) }
    func updateCell(table: FlexNoteTable, row: Int, column: Int, value: String) { store.updateNoteCell(in: table, row: row, column: column, value: value) }
    func addRow(table: FlexNoteTable) { store.addNoteRow(to: table) }
    func addColumn(table: FlexNoteTable, header: String) { store.addNoteColumn(to: table, header: header) }
    func removeColumn(table: FlexNoteTable, at index: Int) { store.removeNoteColumn(from: table, at: index) }
    func updateHeader(table: FlexNoteTable, at index: Int, value: String) { store.updateNoteHeader(in: table, at: index, value: value) }
    func updateFooter(table: FlexNoteTable, footer: [String]) { store.updateNoteFooter(for: table, footer: footer) }
    func removeTable(_ table: FlexNoteTable) { store.removeNoteTable(table) }
}
