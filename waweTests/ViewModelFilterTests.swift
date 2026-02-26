 #if canImport(XCTest)
 import XCTest
 @testable import wawe
 
 final class ViewModelFilterTests: XCTestCase {
     func testWordsFilter() {
         let store = WordStore()
         store.words = [
             Word(original: "Apple", translation: "яблоко"),
             Word(original: "Orange", translation: "апельсин"),
         ]
         let vm = WordsViewModel(repo: WordsRepositoryStoreAdapter(store: store))
         vm.send(.search("app"))
         XCTAssertEqual(vm.state.filtered.count, 1)
         XCTAssertEqual(vm.state.filtered.first?.original, "Apple")
     }
     
     func testVerbsFilter() {
         let store = WordStore()
         store.irregularVerbs = [
             IrregularVerb(infinitive: "be", pastSimple: "was/were", pastParticiple: "been", translation: "быть"),
             IrregularVerb(infinitive: "go", pastSimple: "went", pastParticiple: "gone", translation: "идти"),
         ]
         let vm = VerbsViewModel(repo: VerbsRepositoryStoreAdapter(store: store))
         vm.send(.search("go"))
         XCTAssertEqual(vm.state.filtered.count, 1)
         XCTAssertEqual(vm.state.filtered.first?.infinitive, "go")
     }
     
     func testQuestionsFilter() {
         let store = WordStore()
         store.questions = [
             QuestionItem(prompt: "Who are you?", answer: "I am John"),
             QuestionItem(prompt: "Where are you?", answer: "In London"),
         ]
         let vm = QuestionsViewModel(store: store)
         vm.send(.search("london"))
         XCTAssertEqual(vm.state.filtered.count, 1)
         XCTAssertEqual(vm.state.filtered.first?.answer, "In London")
     }
 }
 #endif
