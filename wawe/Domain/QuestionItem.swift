import Foundation

struct QuestionItem: LearnableItem {
    var id: UUID
    var prompt: String
    var answer: String
    var correctCount: Int
    
    var comparisonKey: String {
        "\(prompt.normalizedCompareKey)|\(answer.normalizedCompareKey)"
    }

    init(id: UUID = UUID(), prompt: String, answer: String, correctCount: Int = 0) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.correctCount = correctCount
    }
}
