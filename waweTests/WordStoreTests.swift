 #if canImport(XCTest)
 import XCTest
 @testable import wawe
 
 final class WordStoreTests: XCTestCase {
     func testAddWordAndProgress() {
         let store = WordStore()
         store.words.removeAll()
         store.addWord(original: "apple", translation: "яблоко")
         XCTAssertEqual(store.words.count, 1)
         XCTAssertEqual(store.words[0].original, "apple")
         store.markCorrect(store.words[0])
         XCTAssertEqual(store.words[0].correctCount, 1)
     }
     
     func testIrregularVerbFlow() {
         let store = WordStore()
         store.irregularVerbs.removeAll()
         store.addIrregularVerb(infinitive: "be", pastSimple: "was/were", pastParticiple: "been", translation: "быть")
         XCTAssertEqual(store.irregularVerbs.count, 1)
         store.markIrregularVerbCorrect(store.irregularVerbs[0])
         XCTAssertEqual(store.irregularVerbs[0].correctCount, 1)
     }
     
     func testQuestionFlow() {
         let store = WordStore()
         store.questions.removeAll()
         store.addQuestion(prompt: "Who are you?", answer: "I am John")
         XCTAssertEqual(store.questions.count, 1)
         store.markQuestionCorrect(store.questions[0])
         XCTAssertEqual(store.questions[0].correctCount, 1)
     }
 }
 #endif
