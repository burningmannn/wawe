import SwiftUI
import Combine

enum NotesIntent {
    case search(String)
    case sortByTitle(Bool)
    case add(title: String, imageURL: String, descriptionMarkdown: String)
    case update(ImageNote, title: String?, imageURL: String?, descriptionMarkdown: String?)
    case delete(ImageNote)
    case clearAll
    case move(IndexSet, Int)
    case addRandom
    case addTwoRandom
    case addSamples
}

struct NotesViewState: Equatable {
    var all: [ImageNote] = []
    var filtered: [ImageNote] = []
    var search: String = ""
    var sortByTitle: Bool = false
}

final class NotesViewModel: ObservableObject {
    @Published private(set) var state = NotesViewState()
    
    private let repo: NotesRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: NotesRepository) {
        self.repo = repo
        bind()
    }
    
    var allNotesBinding: Binding<[ImageNote]> {
        Binding(
            get: { self.state.all },
            set: { _ in } // Changes are driven by repo updates via move/add/delete
        )
    }
    
    func send(_ intent: NotesIntent) {
        switch intent {
        case .addRandom:
            let titles = ["SwiftUI Tips", "Core Data Basics", "Networking Guide", "Design Patterns", "Performance"]
            let images = [
                "https://picsum.photos/seed/\(UUID().uuidString)/1200/675",
                "https://picsum.photos/seed/\(UUID().uuidString)/1200/675",
                "https://picsum.photos/seed/\(UUID().uuidString)/1200/675"
            ]
            let descriptions = [
                "Use **SwiftUI** for declarative UI development.",
                "Always handle *errors* gracefully.",
                "Dependency Injection makes testing easier."
            ]
            
            repo.addImageNote(
                title: titles.randomElement() ?? "Random Note",
                imageURL: images.randomElement() ?? "",
                descriptionMarkdown: descriptions.randomElement() ?? ""
            )
        case .addTwoRandom:
            let titles = ["Random A", "Random B", "Random C", "Random D"]
            let descriptions = [
                "Авто-заметка для проверки загрузки картинок.",
                "Тестовая заметка с произвольной картинкой."
            ]
            let url1 = "https://picsum.photos/seed/\(UUID().uuidString)/1200/675"
            let url2 = "https://picsum.photos/seed/\(UUID().uuidString)/1200/675"
            repo.addImageNote(title: titles.randomElement() ?? "Random 1", imageURL: url1, descriptionMarkdown: descriptions.randomElement() ?? "")
            repo.addImageNote(title: titles.randomElement() ?? "Random 2", imageURL: url2, descriptionMarkdown: descriptions.randomElement() ?? "")
        case .addSamples:
            let descriptions = [
                "Пример заметки с изображением.",
                "Случайное фото для проверки макета.",
                "Проверка загрузчика изображений."
            ]
            let samples = (0..<6).map { i in
                (title: "Пример \(i+1)",
                 url: "https://picsum.photos/seed/\(UUID().uuidString)/1200/675",
                 desc: descriptions.randomElement() ?? "")
            }
            for s in samples {
                repo.addImageNote(title: s.title, imageURL: s.url, descriptionMarkdown: s.desc)
            }
            
        case .search(let text):
            state.search = text
            filter()
            
        case .sortByTitle(let enabled):
            state.sortByTitle = enabled
            filter()
            
        case .add(let title, let url, let desc):
            repo.addImageNote(title: title, imageURL: url, descriptionMarkdown: desc)
            
        case .update(let note, let title, let url, let desc):
            repo.updateImageNote(note, title: title, imageURL: url, descriptionMarkdown: desc)
            
        case .delete(let note):
            repo.removeImageNote(note)
            
        case .clearAll:
            repo.clearImageNotes()
            
        case .move(let from, let to):
            repo.moveImageNotes(from: from, to: to)
        }
    }
    
    private func bind() {
        repo.imageNotesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] notes in
                guard let self else { return }
                self.state.all = notes
                self.filter()
            }
            .store(in: &cancellables)
    }
    
    private func filter() {
        let q = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = state.all.filter { note in
            q.isEmpty || 
            note.title.localizedCaseInsensitiveContains(q) ||
            note.descriptionMarkdown.localizedCaseInsensitiveContains(q)
        }
        
        if state.sortByTitle {
            state.filtered = base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            state.filtered = base
        }
    }
}
