import Foundation

struct Word: LearnableItem {
    var id: UUID
    var original: String
    var translation: String
    var correctCount: Int
    
    var comparisonKey: String {
        "\(original.normalizedCompareKey)|\(translation.normalizedCompareKey)"
    }

    init(id: UUID = UUID(), original: String, translation: String, correctCount: Int = 0) {
        self.id = id
        self.original = original
        self.translation = translation
        self.correctCount = correctCount
    }
}
