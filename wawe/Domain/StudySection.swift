import Foundation

enum StudySection: CaseIterable, Identifiable {
    case words
    case verbs

    var id: Self { self }

    var title: String {
        switch self {
        case .words: return "Слова"
        case .verbs: return "Глаголы"
        }
    }

    var systemImage: String {
        switch self {
        case .words: return "book"
        case .verbs: return "textformat.abc"
        }
    }
}
