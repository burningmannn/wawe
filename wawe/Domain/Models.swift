import Foundation

struct Word: Identifiable, Codable, Equatable {
    var id: UUID
    var original: String
    var translation: String
    var correctCount: Int

    init(id: UUID = UUID(), original: String, translation: String, correctCount: Int = 0) {
        self.id = id
        self.original = original
        self.translation = translation
        self.correctCount = correctCount
    }
}

struct IrregularVerb: Identifiable, Codable, Equatable {
    var id: UUID
    var infinitive: String
    var pastSimple: String
    var pastParticiple: String
    var translation: String
    var correctCount: Int

    init(id: UUID = UUID(), infinitive: String, pastSimple: String, pastParticiple: String, translation: String, correctCount: Int = 0) {
        self.id = id
        self.infinitive = infinitive
        self.pastSimple = pastSimple
        self.pastParticiple = pastParticiple
        self.translation = translation
        self.correctCount = correctCount
    }
}

struct QuestionItem: Identifiable, Codable, Equatable {
    var id: UUID
    var prompt: String
    var answer: String
    var correctCount: Int

    init(id: UUID = UUID(), prompt: String, answer: String, correctCount: Int = 0) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.correctCount = correctCount
    }
}

struct ImageNote: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var imageURL: String
    var descriptionMarkdown: String
    
    init(id: UUID = UUID(), title: String, imageURL: String, descriptionMarkdown: String = "") {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.descriptionMarkdown = descriptionMarkdown
    }
}
