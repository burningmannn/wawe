import Foundation

struct IrregularVerb: LearnableItem {
    var id: UUID
    var infinitive: String
    var pastSimple: String
    var pastParticiple: String
    var translation: String
    var correctCount: Int
    
    var comparisonKey: String {
        "\(infinitive.normalizedCompareKey)|\(pastSimple.normalizedCompareKey)|\(pastParticiple.normalizedCompareKey)"
    }

    init(id: UUID = UUID(), infinitive: String, pastSimple: String, pastParticiple: String, translation: String, correctCount: Int = 0) {
        self.id = id
        self.infinitive = infinitive
        self.pastSimple = pastSimple
        self.pastParticiple = pastParticiple
        self.translation = translation
        self.correctCount = correctCount
    }
}
