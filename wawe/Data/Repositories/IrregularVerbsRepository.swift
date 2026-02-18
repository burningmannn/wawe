import Foundation
import Combine

protocol IrregularVerbsRepository {
    var verbRepeatLimit: Int { get }
    var learnedVerbsCount: Int { get }
    var verbsPublisher: AnyPublisher<[IrregularVerb], Never> { get }
    func add(infinitive: String, pastSimple: String, pastParticiple: String, translation: String)
    func remove(_ verb: IrregularVerb)
    func remove(at offsets: IndexSet)
    func update(_ verb: IrregularVerb, infinitive: String, pastSimple: String, pastParticiple: String, translation: String, resetProgress: Bool)
    func markCorrect(_ verb: IrregularVerb)
    func clearVerbs()
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
    var learnedVerbsCount: Int { store.learnedVerbsTotal }
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
    func clearVerbs() { store.clearIrregularVerbs() }
}
