import Foundation

enum StudySection: CaseIterable, Identifiable {
    case words
    case verbs
    case questions

    var id: Self { self }

    var title: String {
        switch self {
        case .words: return "Слова"
        case .verbs: return "Глаголы"
        case .questions: return "Вопросы"
        }
    }

    var systemImage: String {
        switch self {
        case .words: return "book"
        case .verbs: return "textformat.abc"
        case .questions: return "questionmark.circle"
        }
    }
}
