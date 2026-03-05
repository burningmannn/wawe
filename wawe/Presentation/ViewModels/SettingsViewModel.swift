import SwiftUI
import Combine

final class SettingsViewModel: ObservableObject {
    @AppStorage("wordRepeatLimit") var wordRepeatLimit: Int = 30 {
        didSet { prune() }
    }
    @AppStorage("verbRepeatLimit") var verbRepeatLimit: Int = 30 {
        didSet { prune() }
    }
    @AppStorage("appTheme") var appTheme: String = "system"
    
    @Published var showingImportSheet = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var exportShareItem: ExportShareItem?
    @Published var showingAbout = false
    
    private let repo: SettingsRepository
    
    init(repo: SettingsRepository) {
        self.repo = repo
    }
    
    func prune() {
        repo.pruneReachedLimit()
    }
    
    func clearWords() {
        withAnimation { repo.clearWords() }
    }
    
    func clearVerbs() {
        withAnimation { repo.clearVerbs() }
    }
    
    func exportBackup() {
        if let url = repo.exportBackup() {
            exportShareItem = ExportShareItem(url: url)
        } else {
            alertMessage = "Ошибка при экспорте"
            showingAlert = true
        }
    }
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                alertMessage = "Файл не выбран"
                showingAlert = true
                return
            }
            
            let success = repo.importBackup(from: url)
            
            if success {
                alertMessage = "Импорт завершён"
            } else {
                alertMessage = "Ошибка при импорте. Попробуйте выбрать файл ещё раз или проверьте формат."
            }
            showingAlert = true
            
        case .failure(let error):
            alertMessage = "Ошибка выбора файла: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}
