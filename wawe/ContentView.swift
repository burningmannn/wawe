//
//  ContentView.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// MARK: - Модель
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

// MARK: - Модель неправильного глагола
struct IrregularVerb: Identifiable, Codable, Equatable {
    var id: UUID
    var infinitive: String      // be
    var pastSimple: String      // was/were
    var pastParticiple: String  // been
    var translation: String     // быть
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

// MARK: - Модель вопроса
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

// MARK: - Структура для экспорта/импорта
struct BackupSettings: Codable {
    var wordRepeatLimit: Int
    var verbRepeatLimit: Int
    var questionRepeatLimit: Int

    init(wordRepeatLimit: Int = 30,
         verbRepeatLimit: Int = 30,
         questionRepeatLimit: Int = 30) {
        self.wordRepeatLimit = wordRepeatLimit
        self.verbRepeatLimit = verbRepeatLimit
        self.questionRepeatLimit = questionRepeatLimit
    }
}

struct BackupPayload: Codable {
    var words: [Word]
    var irregularVerbs: [IrregularVerb]
    var questions: [QuestionItem]
    var settings: BackupSettings
    var version: String
    var exportDate: Date

    init(words: [Word],
         irregularVerbs: [IrregularVerb],
         questions: [QuestionItem],
         settings: BackupSettings,
         version: String,
         exportDate: Date) {
        self.words = words
        self.irregularVerbs = irregularVerbs
        self.questions = questions
        self.settings = settings
        self.version = version
        self.exportDate = exportDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        words = try container.decodeIfPresent([Word].self, forKey: .words) ?? []
        irregularVerbs = try container.decodeIfPresent([IrregularVerb].self, forKey: .irregularVerbs) ?? []
        questions = try container.decodeIfPresent([QuestionItem].self, forKey: .questions) ?? []
        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings) ?? BackupSettings()
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
    }
}

// MARK: - Структуры для обратной совместимости
struct ExportDataV1: Codable {
    let words: [Word]
    let irregularVerbs: [IrregularVerb]
    let settings: [String: Int]
    let version: String
    let exportDate: Date
}

struct LegacyExportData: Codable {
    let words: [Word]
    let settings: [String: Int]
    let version: String
    let exportDate: Date
}


// MARK: - Хранилище слов
class WordStore: ObservableObject {
    @AppStorage("wordRepeatLimit") var wordRepeatLimit: Int = 30
    @AppStorage("verbRepeatLimit") var verbRepeatLimit: Int = 30
    @AppStorage("questionRepeatLimit") var questionRepeatLimit: Int = 30

    @Published var words: [Word] = [] {
        didSet { saveWords() }
    }
    
    @Published var irregularVerbs: [IrregularVerb] = [] {
        didSet { saveIrregularVerbs() }
    }

    @Published var questions: [QuestionItem] = [] {
        didSet { saveQuestions() }
    }

    init() {
        load()
        migrateLegacyRepeatLimit()
        pruneReachedLimit() // на случай, если лимит уменьшили
    }

    // Добавление
    func addWord(original: String, translation: String) {
        words.append(Word(original: original.trimmedLowercasedIfNeeded(), translation: translation.trimmedLowercasedIfNeeded()))
    }

    // Удаление
    func removeWord(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
    }

    func removeWord(_ word: Word) {
        words.removeAll { $0.id == word.id }
    }

    // Обновление/редактирование
    func updateWord(_ word: Word, original: String, translation: String, resetProgress: Bool = false) {
        guard let idx = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[idx].original = original
        words[idx].translation = translation
        if resetProgress {
            words[idx].correctCount = 0
        }
    }

    // Отметить правильный ответ
    func markCorrect(_ word: Word) {
        guard let idx = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[idx].correctCount += 1
        if words[idx].correctCount >= wordRepeatLimit {
            completeWord(at: idx)
        }
    }

    // Подчистить слова, которые уже превысили новый лимит
    func pruneReachedLimit() {
        removeCompletedWords(countAsLearned: false)
        removeCompletedVerbs(countAsLearned: false)
        removeCompletedQuestions(countAsLearned: false)
    }

    // MARK: - Методы для неправильных глаголов
    func addIrregularVerb(infinitive: String, pastSimple: String, pastParticiple: String, translation: String) {
        irregularVerbs.append(IrregularVerb(
            infinitive: infinitive.trimmedLowercasedIfNeeded(),
            pastSimple: pastSimple.trimmedLowercasedIfNeeded(),
            pastParticiple: pastParticiple.trimmedLowercasedIfNeeded(),
            translation: translation.trimmedLowercasedIfNeeded()
        ))
    }
    
    func removeIrregularVerb(at offsets: IndexSet) {
        irregularVerbs.remove(atOffsets: offsets)
    }
    
    func removeIrregularVerb(_ verb: IrregularVerb) {
        irregularVerbs.removeAll { $0.id == verb.id }
    }
    
    func updateIrregularVerb(_ verb: IrregularVerb, infinitive: String, pastSimple: String, pastParticiple: String, translation: String, resetProgress: Bool = false) {
        guard let idx = irregularVerbs.firstIndex(where: { $0.id == verb.id }) else { return }
        irregularVerbs[idx].infinitive = infinitive
        irregularVerbs[idx].pastSimple = pastSimple
        irregularVerbs[idx].pastParticiple = pastParticiple
        irregularVerbs[idx].translation = translation
        if resetProgress {
            irregularVerbs[idx].correctCount = 0
        }
    }
    
    func markIrregularVerbCorrect(_ verb: IrregularVerb) {
        guard let idx = irregularVerbs.firstIndex(where: { $0.id == verb.id }) else { return }
        irregularVerbs[idx].correctCount += 1
        if irregularVerbs[idx].correctCount >= verbRepeatLimit {
            completeVerb(at: idx)
        }
    }

    // MARK: - Методы для вопросов
    func addQuestion(prompt: String, answer: String) {
        questions.append(QuestionItem(
            prompt: prompt.trimmedLowercasedIfNeeded(),
            answer: answer.trimmedLowercasedIfNeeded()
        ))
    }

    func removeQuestion(at offsets: IndexSet) {
        questions.remove(atOffsets: offsets)
    }

    func removeQuestion(_ question: QuestionItem) {
        questions.removeAll { $0.id == question.id }
    }

    func updateQuestion(_ question: QuestionItem, prompt: String, answer: String, resetProgress: Bool = false) {
        guard let idx = questions.firstIndex(where: { $0.id == question.id }) else { return }
        questions[idx].prompt = prompt
        questions[idx].answer = answer
        if resetProgress {
            questions[idx].correctCount = 0
        }
    }

    func markQuestionCorrect(_ question: QuestionItem) {
        guard let idx = questions.firstIndex(where: { $0.id == question.id }) else { return }
        questions[idx].correctCount += 1
        if questions[idx].correctCount >= questionRepeatLimit {
            completeQuestion(at: idx)
        }
    }

    func resetAllProgress(resetCounters: Bool = true) {
        words = words.map { word in
            var mutableWord = word
            mutableWord.correctCount = 0
            return mutableWord
        }

        irregularVerbs = irregularVerbs.map { verb in
            var mutableVerb = verb
            mutableVerb.correctCount = 0
            return mutableVerb
        }

        questions = questions.map { question in
            var mutableQuestion = question
            mutableQuestion.correctCount = 0
            return mutableQuestion
        }
    }

    func resetProgress(for section: StudySection) {
        switch section {
        case .words:
            words = words.map { word in
                var mutableWord = word
                mutableWord.correctCount = 0
                return mutableWord
            }
        case .verbs:
            irregularVerbs = irregularVerbs.map { verb in
                var mutableVerb = verb
                mutableVerb.correctCount = 0
                return mutableVerb
            }
        case .questions:
            questions = questions.map { question in
                var mutableQuestion = question
                mutableQuestion.correctCount = 0
                return mutableQuestion
            }
        }
    }

    func repeatLimit(for section: StudySection) -> Int {
        switch section {
        case .words: return wordRepeatLimit
        case .verbs: return verbRepeatLimit
        case .questions: return questionRepeatLimit
        }
    }

    func activeItemsCount(for section: StudySection) -> Int {
        switch section {
        case .words: return words.count
        case .verbs: return irregularVerbs.count
        case .questions: return questions.count
        }
    }

    private func completeWord(at index: Int, countAsLearned: Bool = true) {
        guard words.indices.contains(index) else { return }
        words.remove(at: index)
    }

    private func completeVerb(at index: Int, countAsLearned: Bool = true) {
        guard irregularVerbs.indices.contains(index) else { return }
        irregularVerbs.remove(at: index)
    }

    private func completeQuestion(at index: Int, countAsLearned: Bool = true) {
        guard questions.indices.contains(index) else { return }
        questions.remove(at: index)
    }

    private func removeCompletedWords(countAsLearned: Bool = true) {
        guard wordRepeatLimit > 0 else { return }
        for index in words.indices.reversed() where words[index].correctCount >= wordRepeatLimit {
            completeWord(at: index, countAsLearned: countAsLearned)
        }
    }

    private func removeCompletedVerbs(countAsLearned: Bool = true) {
        guard verbRepeatLimit > 0 else { return }
        for index in irregularVerbs.indices.reversed() where irregularVerbs[index].correctCount >= verbRepeatLimit {
            completeVerb(at: index, countAsLearned: countAsLearned)
        }
    }

    private func removeCompletedQuestions(countAsLearned: Bool = true) {
        guard questionRepeatLimit > 0 else { return }
        for index in questions.indices.reversed() where questions[index].correctCount >= questionRepeatLimit {
            completeQuestion(at: index, countAsLearned: countAsLearned)
        }
    }

    private func mergeWords(_ importedWords: [Word]) -> Int {
        var importedCount = 0
        for importedWord in importedWords {
            let exists = words.contains { word in
                word.original.normalizedCompareKey == importedWord.original.normalizedCompareKey &&
                word.translation.normalizedCompareKey == importedWord.translation.normalizedCompareKey
            }
            if !exists {
                words.append(importedWord)
                importedCount += 1
                print("Imported word: \(importedWord.original) -> \(importedWord.translation)")
            } else {
                print("Word already exists: \(importedWord.original) -> \(importedWord.translation)")
            }
        }
        return importedCount
    }

    private func mergeVerbs(_ importedVerbs: [IrregularVerb]) -> Int {
        var importedCount = 0
        for importedVerb in importedVerbs {
            let exists = irregularVerbs.contains { verb in
                verb.infinitive.normalizedCompareKey == importedVerb.infinitive.normalizedCompareKey &&
                verb.pastSimple.normalizedCompareKey == importedVerb.pastSimple.normalizedCompareKey &&
                verb.pastParticiple.normalizedCompareKey == importedVerb.pastParticiple.normalizedCompareKey
            }
            if !exists {
                irregularVerbs.append(importedVerb)
                importedCount += 1
                print("Imported verb: \(importedVerb.infinitive) - \(importedVerb.pastSimple) - \(importedVerb.pastParticiple)")
            } else {
                print("Verb already exists: \(importedVerb.infinitive) - \(importedVerb.pastSimple) - \(importedVerb.pastParticiple)")
            }
        }
        return importedCount
    }

    private func mergeQuestions(_ importedQuestions: [QuestionItem]) -> Int {
        var importedCount = 0
        for importedQuestion in importedQuestions {
            let exists = questions.contains { question in
                question.prompt.normalizedCompareKey == importedQuestion.prompt.normalizedCompareKey &&
                question.answer.normalizedCompareKey == importedQuestion.answer.normalizedCompareKey
            }
            if !exists {
                questions.append(importedQuestion)
                importedCount += 1
                print("Imported question: \(importedQuestion.prompt) -> \(importedQuestion.answer)")
            } else {
                print("Question already exists: \(importedQuestion.prompt) -> \(importedQuestion.answer)")
            }
        }
        return importedCount
    }

    private func migrateLegacyRepeatLimit() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "repeatLimit") != nil else { return }
        let legacyLimit = defaults.integer(forKey: "repeatLimit")

        if defaults.object(forKey: "wordRepeatLimit") == nil {
            wordRepeatLimit = legacyLimit
        }
        if defaults.object(forKey: "verbRepeatLimit") == nil {
            verbRepeatLimit = legacyLimit
        }
        if defaults.object(forKey: "questionRepeatLimit") == nil {
            questionRepeatLimit = legacyLimit
        }

        defaults.removeObject(forKey: "repeatLimit")
    }

    // MARK: - Экспорт/Импорт
    func exportBackup() -> URL? {
        do {
            print("Starting export for all sections")

            let payload = BackupPayload(
                words: words,
                irregularVerbs: irregularVerbs,
                questions: questions,
                settings: BackupSettings(
                    wordRepeatLimit: wordRepeatLimit,
                    verbRepeatLimit: verbRepeatLimit,
                    questionRepeatLimit: questionRepeatLimit
                ),
                version: "2.0",
                exportDate: Date()
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            print("Encoded data size: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                print("Export JSON preview: \(String(jsonString.prefix(500)))")
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "waweApp_\(dateString).json"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            print("Export completed. File saved to: \(fileURL)")
            return fileURL
        } catch {
            print("Export error: \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    func importBackup(from url: URL) -> Bool {
        do {
            print("Starting import from: \(url) for all sections")

            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return false
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("import_\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("File copied to temp location: \(tempURL)")

            let data = try Data(contentsOf: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            print("File size: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON content preview: \(String(jsonString.prefix(500)))")
            }

            if let payload = decodeBackupPayload(from: data) {
                print("Decoded BackupPayload version: \(payload.version)")
                return apply(payload: payload)
            }

            let decoder = JSONDecoder()

            if let exportData = try? decoder.decode(ExportDataV1.self, from: data) {
                print("Decoded ExportDataV1 version: \(exportData.version)")
                return apply(exportData: exportData)
            }

            if let legacyData = try? decoder.decode(LegacyExportData.self, from: data) {
                print("Decoded LegacyExportData version: \(legacyData.version)")
                return apply(legacyData: legacyData)
            }

            if let importedWords = try? decoder.decode([Word].self, from: data) {
                print("Decoded plain word array with \(importedWords.count) entries")
                let count = mergeWords(importedWords)
                print("Import completed: \(count) new words from array format")
                return count > 0
            }

            if let content = String(data: data, encoding: .utf8) {
                print("Trying to parse as text file")
                return importFromText(content)
            }

            print("Unsupported import format")
            return false
        } catch {
            print("Import error: \(error)")
            print("Error details: \(error.localizedDescription)")

            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")

                if nsError.domain == NSCocoaErrorDomain && nsError.code == 257 {
                    print("File access permission error - this is expected on iOS")
                    return false
                }
            }

            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }

            return false
        }
    }
    
    private func decodeBackupPayload(from data: Data) -> BackupPayload? {
        let decoder = JSONDecoder()
        return try? decoder.decode(BackupPayload.self, from: data)
    }

    private func apply(payload: BackupPayload) -> Bool {
        print("Applying BackupPayload with \(payload.words.count) words, \(payload.irregularVerbs.count) verbs, \(payload.questions.count) questions")

        let importedWords = mergeWords(payload.words)
        let importedVerbs = mergeVerbs(payload.irregularVerbs)
        let importedQuestions = mergeQuestions(payload.questions)

        let settings = payload.settings
        let settingsChanged =
            settings.wordRepeatLimit != wordRepeatLimit ||
            settings.verbRepeatLimit != verbRepeatLimit ||
            settings.questionRepeatLimit != questionRepeatLimit

        wordRepeatLimit = settings.wordRepeatLimit
        verbRepeatLimit = settings.verbRepeatLimit
        questionRepeatLimit = settings.questionRepeatLimit

        removeCompletedWords(countAsLearned: false)
        removeCompletedVerbs(countAsLearned: false)
        removeCompletedQuestions(countAsLearned: false)

        print("Payload import summary: +\(importedWords) words, +\(importedVerbs) verbs, +\(importedQuestions) questions, settingsChanged: \(settingsChanged)")

        return (importedWords + importedVerbs + importedQuestions) > 0 || settingsChanged
    }

    private func apply(exportData: ExportDataV1) -> Bool {
        print("Applying ExportDataV1 with \(exportData.words.count) words and \(exportData.irregularVerbs.count) verbs")

        let importedWords = mergeWords(exportData.words)
        let importedVerbs = mergeVerbs(exportData.irregularVerbs)

        var settingsChanged = false
        if let newLimit = exportData.settings["repeatLimit"] {
            settingsChanged = newLimit != wordRepeatLimit || newLimit != verbRepeatLimit || newLimit != questionRepeatLimit
            wordRepeatLimit = newLimit
            verbRepeatLimit = newLimit
            questionRepeatLimit = newLimit
            removeCompletedWords(countAsLearned: false)
            removeCompletedVerbs(countAsLearned: false)
            removeCompletedQuestions(countAsLearned: false)
            print("Settings updated from ExportDataV1: repeatLimit = \(newLimit)")
        }

        return (importedWords + importedVerbs) > 0 || settingsChanged
    }

    private func apply(legacyData: LegacyExportData) -> Bool {
        print("Applying LegacyExportData with \(legacyData.words.count) words")

        let importedWords = mergeWords(legacyData.words)

        var settingsChanged = false
        if let newLimit = legacyData.settings["repeatLimit"] {
            settingsChanged = newLimit != wordRepeatLimit || newLimit != verbRepeatLimit || newLimit != questionRepeatLimit
            wordRepeatLimit = newLimit
            verbRepeatLimit = newLimit
            questionRepeatLimit = newLimit
            removeCompletedWords(countAsLearned: false)
            removeCompletedVerbs(countAsLearned: false)
            removeCompletedQuestions(countAsLearned: false)
            print("Settings updated from LegacyExportData: repeatLimit = \(newLimit)")
        }

        return importedWords > 0 || settingsChanged
    }

    private func importFromText(_ content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        var parsedWords: [Word] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }

            let separators = [" - ", ":", "=", " — "]
            var original = ""
            var translation = ""

            for separator in separators {
                let components = trimmedLine.components(separatedBy: separator)
                if components.count >= 2 {
                    original = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    translation = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }

            if original.isEmpty && translation.isEmpty {
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 2 {
                    original = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    translation = components.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if !original.isEmpty && !translation.isEmpty {
                parsedWords.append(
                    Word(
                        original: original.trimmedLowercasedIfNeeded(),
                        translation: translation.trimmedLowercasedIfNeeded()
                    )
                )
            } else {
                print("Failed to parse line: \(trimmedLine)")
            }
        }

        let importedCount = mergeWords(parsedWords)
        print("Text import completed: \(importedCount) new words")
        return importedCount > 0
    }

    // MARK: - Persistence
    private func saveWords() {
        do {
            let data = try JSONEncoder().encode(words)
            UserDefaults.standard.set(data, forKey: "words")
        } catch {
            print("Save words error: \(error)")
        }
    }
    
    private func saveIrregularVerbs() {
        do {
            let data = try JSONEncoder().encode(irregularVerbs)
            UserDefaults.standard.set(data, forKey: "irregularVerbs")
        } catch {
            print("Save irregular verbs error: \(error)")
        }
    }

    private func saveQuestions() {
        do {
            let data = try JSONEncoder().encode(questions)
            UserDefaults.standard.set(data, forKey: "questions")
        } catch {
            print("Save questions error: \(error)")
        }
    }

    private func load() {
        // Загружаем обычные слова
        if let data = UserDefaults.standard.data(forKey: "words") {
            do {
                let decoded = try JSONDecoder().decode([Word].self, from: data)
                words = decoded
            } catch {
                print("Load words error: \(error)")
            }
        }
        
        // Загружаем неправильные глаголы
        if let data = UserDefaults.standard.data(forKey: "irregularVerbs") {
            do {
                let decoded = try JSONDecoder().decode([IrregularVerb].self, from: data)
                irregularVerbs = decoded
            } catch {
                print("Load irregular verbs error: \(error)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "questions") {
            do {
                let decoded = try JSONDecoder().decode([QuestionItem].self, from: data)
                questions = decoded
            } catch {
                print("Load questions error: \(error)")
            }
        }
    }
}

// MARK: - Главный экран
struct ContentView: View {
    @StateObject private var store = WordStore()

    var body: some View {
        TabView {
            WordsView(store: store)
                .tabItem {
                    Label("Слова", systemImage: "book")
                }
            
            IrregularVerbsView(store: store)
                .tabItem {
                    Label("Глаголы", systemImage: "textformat.abc")
                }

            QuestionsView(store: store)
                .tabItem {
                    Label("Вопросы", systemImage: "questionmark.circle")
                }
        }
    }
}

// MARK: - Экран обычных слов
struct WordsView: View {
    @ObservedObject var store: WordStore
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingSettings = false
    @State private var search = ""

    var filteredWords: [Word] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return store.words }
        let q = search.normalizedCompareKey
        return store.words.filter {
            $0.original.normalizedCompareKey.contains(q) || $0.translation.normalizedCompareKey.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredWords.isEmpty {
                    if store.words.isEmpty {
                        ContentUnavailableView("Пока пусто", systemImage: "book", description: Text("Добавь слова через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего слов", systemImage: "number.square", value: store.words.count)
                            if filteredWords.count != store.words.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredWords.count)
                            }
                        }

                        ForEach(filteredWords) { word in
                            NavigationLink {
                                EditWordView(store: store, word: word)
                            } label: {
                                WordRow(word: word, repeatLimit: store.wordRepeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.removeWord(word) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { store.markCorrect(word) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: store.removeWord)
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            #if os(iOS)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по словам")
            #else
            .searchable(text: $search, prompt: "Поиск по словам")
            #endif
            .navigationTitle("Словарь")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showingTest = true
                        } label: {
                            Label("Тест", systemImage: "play.circle")
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Настройки", systemImage: "gearshape")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Настройки", systemImage: "gearshape")
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddWordView(store: store)
            }
            .sheet(isPresented: $showingTest) {
                TestView(store: store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
                    .onChange(of: store.wordRepeatLimit) { store.pruneReachedLimit() }
            }
        }
    }
}

// MARK: - Экран неправильных глаголов
struct IrregularVerbsView: View {
    @ObservedObject var store: WordStore
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var search = ""

    var filteredVerbs: [IrregularVerb] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return store.irregularVerbs }
        let q = search.normalizedCompareKey
        return store.irregularVerbs.filter {
            $0.infinitive.normalizedCompareKey.contains(q) ||
            $0.pastSimple.normalizedCompareKey.contains(q) ||
            $0.pastParticiple.normalizedCompareKey.contains(q) ||
            $0.translation.normalizedCompareKey.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredVerbs.isEmpty {
                    if store.irregularVerbs.isEmpty {
                        ContentUnavailableView("Нет неправильных глаголов", systemImage: "textformat.abc", description: Text("Добавь глаголы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего глаголов", systemImage: "number.square", value: store.irregularVerbs.count)
                            if filteredVerbs.count != store.irregularVerbs.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredVerbs.count)
                            }
                        }

                        ForEach(filteredVerbs) { verb in
                            NavigationLink {
                                EditIrregularVerbView(store: store, verb: verb)
                            } label: {
                                IrregularVerbRow(verb: verb, repeatLimit: store.verbRepeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.removeIrregularVerb(verb) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { store.markIrregularVerbCorrect(verb) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: store.removeIrregularVerb)
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            #if os(iOS)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по глаголам")
            #else
            .searchable(text: $search, prompt: "Поиск по глаголам")
            #endif
            .navigationTitle("Неправильные глаголы")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddIrregularVerbView(store: store)
            }
            .sheet(isPresented: $showingTest) {
                StepByStepVerbTestView(store: store)
            }
        }
    }
}

// MARK: - Ячейка неправильного глагола
struct IrregularVerbRow: View {
    let verb: IrregularVerb
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(verb.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verb.infinitive)
                    .font(.headline)
                Text("–")
                    .foregroundStyle(.secondary)
                Text(verb.pastSimple)
                    .font(.headline)
                Text("–")
                    .foregroundStyle(.secondary)
                Text(verb.pastParticiple)
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Text(verb.translation)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(verb.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Добавление неправильного глагола
struct AddIrregularVerbView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    @State private var infinitive = ""
    @State private var pastSimple = ""
    @State private var pastParticiple = ""
    @State private var translation = ""

    var canSave: Bool {
        !infinitive.trimmed.isEmpty &&
        !pastSimple.trimmed.isEmpty &&
        !pastParticiple.trimmed.isEmpty &&
        !translation.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый неправильный глагол") {
                    TextField("Инфинитив (be)", text: $infinitive)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Past Simple (was/were)", text: $pastSimple)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Past Participle (been)", text: $pastParticiple)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Перевод (быть)", text: $translation)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                }
                
                Section {
                    Text("Пример: be – was/were – been (быть)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Добавить глагол")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.addIrregularVerb(
                            infinitive: infinitive,
                            pastSimple: pastSimple,
                            pastParticiple: pastParticiple,
                            translation: translation
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button("Сохранить") {
                        store.addIrregularVerb(
                            infinitive: infinitive,
                            pastSimple: pastSimple,
                            pastParticiple: pastParticiple,
                            translation: translation
                        )
                        dismiss()
                    }
                    .disabled(!canSave)

                    Button("Отмена") { dismiss() }
                }
#endif
            }
        }
    }
}

// MARK: - Редактирование неправильного глагола
struct EditIrregularVerbView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    let verb: IrregularVerb

    @State private var infinitive: String
    @State private var pastSimple: String
    @State private var pastParticiple: String
    @State private var translation: String

    init(store: WordStore, verb: IrregularVerb) {
        self.store = store
        self.verb = verb
        _infinitive = State(initialValue: verb.infinitive)
        _pastSimple = State(initialValue: verb.pastSimple)
        _pastParticiple = State(initialValue: verb.pastParticiple)
        _translation = State(initialValue: verb.translation)
    }

    var body: some View {
        Form {
            Section("Редактировать глагол") {
                TextField("Инфинитив", text: $infinitive)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Past Simple", text: $pastSimple)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Past Participle", text: $pastParticiple)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Перевод", text: $translation)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
            }

            Section {
                Button("Сбросить прогресс") {
                    store.updateIrregularVerb(verb,
                                            infinitive: infinitive.trimmedLowercasedIfNeeded(),
                                            pastSimple: pastSimple.trimmedLowercasedIfNeeded(),
                                            pastParticiple: pastParticiple.trimmedLowercasedIfNeeded(),
                                            translation: translation.trimmedLowercasedIfNeeded(),
                                            resetProgress: true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    store.removeIrregularVerb(verb)
                    dismiss()
                } label: {
                    Label("Удалить глагол", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Правка")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    store.updateIrregularVerb(verb,
                                            infinitive: infinitive.trimmedLowercasedIfNeeded(),
                                            pastSimple: pastSimple.trimmedLowercasedIfNeeded(),
                                            pastParticiple: pastParticiple.trimmedLowercasedIfNeeded(),
                                            translation: translation.trimmedLowercasedIfNeeded(),
                                            resetProgress: false)
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button("Готово") {
                    store.updateIrregularVerb(verb,
                                            infinitive: infinitive.trimmedLowercasedIfNeeded(),
                                            pastSimple: pastSimple.trimmedLowercasedIfNeeded(),
                                            pastParticiple: pastParticiple.trimmedLowercasedIfNeeded(),
                                            translation: translation.trimmedLowercasedIfNeeded(),
                                            resetProgress: false)
                    dismiss()
                }
            }
#endif
        }
    }
}

// MARK: - Экран вопросов
struct QuestionsView: View {
    @ObservedObject var store: WordStore
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var search = ""

    var filteredQuestions: [QuestionItem] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return store.questions }
        let q = search.normalizedCompareKey
        return store.questions.filter {
            $0.prompt.normalizedCompareKey.contains(q) ||
            $0.answer.normalizedCompareKey.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredQuestions.isEmpty {
                    if store.questions.isEmpty {
                        ContentUnavailableView("Нет вопросов", systemImage: "questionmark.circle", description: Text("Добавь вопросы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего вопросов", systemImage: "number.square", value: store.questions.count)
                            if filteredQuestions.count != store.questions.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredQuestions.count)
                            }
                        }

                        ForEach(filteredQuestions) { question in
                            NavigationLink {
                                EditQuestionView(store: store, question: question)
                            } label: {
                                QuestionRow(question: question, repeatLimit: store.questionRepeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.removeQuestion(question) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { store.markQuestionCorrect(question) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: store.removeQuestion)
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            #if os(iOS)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по вопросам")
            #else
            .searchable(text: $search, prompt: "Поиск по вопросам")
            #endif
            .navigationTitle("Вопросы")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAdd) {
                AddQuestionView(store: store)
            }
            .sheet(isPresented: $showingTest) {
                QuestionTestView(store: store)
            }
        }
    }
}

// MARK: - Ячейка вопроса
struct QuestionRow: View {
    let question: QuestionItem
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(question.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt)
                .font(.headline)

            Text(question.answer)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(question.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Добавление вопроса
struct AddQuestionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    @State private var prompt = ""
    @State private var answer = ""

    var canSave: Bool {
        !prompt.trimmed.isEmpty && !answer.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый вопрос") {
                    TextField("Вопрос", text: $prompt, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)

                    TextField("Ответ", text: $answer, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("Добавить вопрос")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.addQuestion(prompt: prompt, answer: answer)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Редактирование вопроса
struct EditQuestionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    let question: QuestionItem

    @State private var prompt: String
    @State private var answer: String

    init(store: WordStore, question: QuestionItem) {
        self.store = store
        self.question = question
        _prompt = State(initialValue: question.prompt)
        _answer = State(initialValue: question.answer)
    }

    var body: some View {
        Form {
            Section("Редактировать вопрос") {
                TextField("Вопрос", text: $prompt, axis: .vertical)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                TextField("Ответ", text: $answer, axis: .vertical)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
            }

            Section {
                Button("Сбросить прогресс") {
                    store.updateQuestion(question,
                                         prompt: prompt.trimmedLowercasedIfNeeded(),
                                         answer: answer.trimmedLowercasedIfNeeded(),
                                         resetProgress: true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    store.removeQuestion(question)
                    dismiss()
                } label: {
                    Label("Удалить вопрос", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Правка")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    store.updateQuestion(question,
                                         prompt: prompt.trimmedLowercasedIfNeeded(),
                                         answer: answer.trimmedLowercasedIfNeeded(),
                                         resetProgress: false)
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                Button("Готово") {
                    store.updateQuestion(question,
                                         prompt: prompt.trimmedLowercasedIfNeeded(),
                                         answer: answer.trimmedLowercasedIfNeeded(),
                                         resetProgress: false)
                    dismiss()
                }
            }
#endif
        }
    }
}

// MARK: - Тест по вопросам
struct QuestionTestView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore

    @State private var currentQuestion: QuestionItem?
    @State private var askForAnswer = true
    @State private var answer = ""
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let question = currentQuestion {
                    Text(askForAnswer ? question.prompt : question.answer)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextField(askForAnswer ? "Ваш ответ" : "Формулировка вопроса", text: $answer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)
                        .onSubmit(checkAnswer)

                    if let feedback {
                        Text(feedback)
                            .font(.headline)
                            .foregroundStyle(feedback.starts(with: "Верно") ? .green : .red)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    if let idx = store.questions.firstIndex(where: { $0.id == question.id }) {
                        let progressItem = store.questions[idx]
                        ProgressView(value: min(Double(progressItem.correctCount) / Double(max(store.questionRepeatLimit, 1)), 1.0))
                        Text("Прогресс: \(progressItem.correctCount)/\(store.questionRepeatLimit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Проверить", action: checkAnswer)
                            .buttonStyle(.borderedProminent)
                            .disabled(answer.trimmed.isEmpty)

                        Button("Пропустить", action: nextQuestion)
                            .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView("Нет вопросов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь вопросы или снизь порог повторов в Настройках"))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Тест по вопросам")
            .onAppear(perform: nextQuestion)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Закрыть") { dismiss() }
                }
#endif
            }
        }
    }

    private func checkAnswer() {
        guard let question = currentQuestion else { return }
        let correct = askForAnswer ? question.answer : question.prompt
        let normalizedUser = answer.normalizedCompareKey
        let normalizedCorrect = correct.normalizedCompareKey

        if normalizedUser == normalizedCorrect {
            feedback = "Верно!"
            if let existing = store.questions.first(where: { $0.id == question.id }) {
                store.markQuestionCorrect(existing)
            }
            nextQuestion()
        } else {
            feedback = "Правильно: \(correct)"
        }

        answer = ""
    }

    private func nextQuestion() {
        guard !store.questions.isEmpty else {
            currentQuestion = nil
            return
        }
        currentQuestion = store.questions.randomElement()
        askForAnswer = Bool.random()
        feedback = nil
        answer = ""
    }
}

// MARK: - Общая строка статистики
struct StatisticRow: View {
    let title: String
    let systemImage: String
    let value: Int

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Ячейка слова с прогрессом
struct WordRow: View {
    let word: Word
    let repeatLimit: Int

    var progress: Double {
        guard repeatLimit > 0 else { return 0 }
        return min(Double(word.correctCount) / Double(repeatLimit), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(word.original)
                    .font(.headline)
                Spacer()
                Text(word.translation)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: 10) {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(word.correctCount)/\(repeatLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Добавление слова
struct AddWordView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    @State private var original = ""
    @State private var translation = ""

    var canSave: Bool {
        !original.trimmed.isEmpty && !translation.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новое слово") {
                    TextField("Слово (например, apple)", text: $original)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    TextField("Перевод (например, яблоко)", text: $translation)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Добавить")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.addWord(original: original, translation: translation)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button("Сохранить") {
                        store.addWord(original: original, translation: translation)
                        dismiss()
                    }
                    .disabled(!canSave)

                    Button("Отмена") { dismiss() }
                }
#endif
            }
        }
    }
}

// MARK: - Редактирование слова
struct EditWordView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    let word: Word

    @State private var original: String
    @State private var translation: String

    init(store: WordStore, word: Word) {
        self.store = store
        self.word = word
        _original = State(initialValue: word.original)
        _translation = State(initialValue: word.translation)
    }

    var body: some View {
        Form {
            Section("Редактировать") {
                TextField("Слово (EN или RU)", text: $original)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                TextField("Перевод", text: $translation)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
            }

            Section {
                Button("Сбросить прогресс") {
                    store.updateWord(word,
                                     original: original.trimmedLowercasedIfNeeded(),
                                     translation: translation.trimmedLowercasedIfNeeded(),
                                     resetProgress: true)
                    dismiss()
                }
                .tint(.orange)

                Button(role: .destructive) {
                    store.removeWord(word)
                    dismiss()
                } label: {
                    Label("Удалить слово", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Правка")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    store.updateWord(word,
                                     original: original.trimmedLowercasedIfNeeded(),
                                     translation: translation.trimmedLowercasedIfNeeded(),
                                     resetProgress: false)
                    dismiss()
                }
            }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        store.updateWord(word,
                                         original: original.trimmedLowercasedIfNeeded(),
                                         translation: translation.trimmedLowercasedIfNeeded(),
                                         resetProgress: false)
                        dismiss()
                    }
                }
#endif
        }
    }
}

// MARK: - Пошаговый тест неправильных глаголов
struct StepByStepVerbTestView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    
    @State private var currentVerb: IrregularVerb?
    @State private var currentStep = 1 // 1: infinitive, 2: past simple, 3: past participle
    @State private var answer = ""
    @State private var feedback: String?
    @State private var isCorrect = false
    
    var totalSteps: Int { 3 }
    
    var currentPrompt: String {
        guard let verb = currentVerb else { return "" }
        switch currentStep {
        case 1: return "Введите инфинитив для: \(verb.translation)"
        case 2: return "Введите Past Simple для: \(verb.infinitive)"
        case 3: return "Введите Past Participle для: \(verb.infinitive)"
        default: return ""
        }
    }
    
    var correctAnswer: String {
        guard let verb = currentVerb else { return "" }
        switch currentStep {
        case 1: return verb.infinitive
        case 2: return verb.pastSimple
        case 3: return verb.pastParticiple
        default: return ""
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if let verb = currentVerb {
                    // Progress indicator как на картинке
                    StepProgressView(currentStep: currentStep, totalSteps: totalSteps, isCorrect: isCorrect)
                        .padding(.horizontal)
                    
                    // Текущий вопрос
                    VStack(spacing: 20) {
                        Text(currentPrompt)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        TextField("Ваш ответ", text: $answer)
                            .textFieldStyle(.roundedBorder)
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .autocorrectionDisabled()
                            .onSubmit(checkAnswer)
#if os(iOS)
                            .font(.title3)
#else
                            .font(.title2)
#endif
                    }
                    
                    if let feedback {
                        Text(feedback)
                            .font(.headline)
                            .foregroundStyle(isCorrect ? .green : .red)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    
                    // Кнопки
                    HStack(spacing: 20) {
                        Button("Проверить", action: checkAnswer)
                            .buttonStyle(.borderedProminent)
                            .disabled(answer.trimmed.isEmpty)
                        
                        Button("Пропустить", action: skipStep)
                            .buttonStyle(.bordered)
                    }
                    
                } else {
                    ContentUnavailableView("Нет глаголов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь глаголы или снизь порог повторов в Настройках"))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Пошаговый тест")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Закрыть") { dismiss() }
                }
#endif
            }
            .onAppear(perform: startNewVerb)
        }
    }
    
    func checkAnswer() {
        let userAnswer = answer.normalizedCompareKey
        let correct = correctAnswer.normalizedCompareKey
        
        if userAnswer == correct {
            isCorrect = true
            feedback = nil
            nextStep()
        } else {
            isCorrect = false
            feedback = "Правильно: \(correctAnswer)"
        }
    }
    
    func skipStep() {
        isCorrect = false
        feedback = "Правильно: \(correctAnswer)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            startNewVerb() // Переходим к новому слову, а не к следующему этапу
        }
    }
    
    func nextStep() {
        if currentStep < totalSteps {
            currentStep += 1
            answer = ""
            feedback = nil
            isCorrect = false
        } else {
            // Завершили все шаги для этого глагола
            if let verb = currentVerb {
                store.markIrregularVerbCorrect(verb)
            }
            startNewVerb()
        }
    }
    
    func startNewVerb() {
        guard !store.irregularVerbs.isEmpty else {
            currentVerb = nil
            return
        }
        currentVerb = store.irregularVerbs.randomElement()
        currentStep = 1
        answer = ""
        feedback = nil
        isCorrect = false
    }
}

// MARK: - Индикатор прогресса по шагам
struct StepProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    let isCorrect: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...totalSteps, id: \.self) { step in
                HStack(spacing: 0) {
                    // Кружок для шага
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 40, height: 40)
                        
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                        } else if step == currentStep {
                            Text("\(step)")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Text("\(step)")
                                .foregroundColor(.gray)
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    
                    // Линия между шагами
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    func stepColor(for step: Int) -> Color {
        if step < currentStep {
            return .blue // Завершенные шаги
        } else if step == currentStep {
            return .blue // Текущий шаг
        } else {
            return .gray.opacity(0.3) // Будущие шаги
        }
    }
}

// MARK: - Тест
struct TestView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore

    @State private var currentWord: Word?
    @State private var answer = ""
    @State private var feedback: String?
    @State private var askTranslation = Bool.random() // true: original->translation, false: translation->original

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let word = currentWord {
                    Text(askTranslation ? word.original : word.translation)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextField("Ваш ответ", text: $answer, prompt: Text("Введите перевод"))
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                        .onSubmit(checkAnswer)

                    if let feedback {
                        Text(feedback)
                            .font(.headline)
                            .foregroundStyle(feedback == "Верно!" ? .green : .red)
                            .transition(.opacity)
                    }

                    // Прогресс по этому слову
                    if let idx = store.words.firstIndex(where: { $0.id == word.id }) {
                        let w = store.words[idx]
                        ProgressView(value: min(Double(w.correctCount) / Double(max(store.wordRepeatLimit, 1)), 1.0))
                        Text("Прогресс: \(w.correctCount)/\(store.wordRepeatLimit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Проверить", action: checkAnswer)
                            .buttonStyle(.borderedProminent)
                        Button("Пропустить", action: nextWord)
                            .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView("Нет слов для теста 🎉",
                                           systemImage: "checkmark.seal",
                                           description: Text("Добавь слова или снизь порог повторов в Настройках"))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Тест")
            .onAppear(perform: nextWord)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Закрыть") { dismiss() }
                }
#endif
            }
        }
    }

    func checkAnswer() {
        guard let word = currentWord else { return }
        let correct = askTranslation ? word.translation : word.original
        let normalizedUser = answer.normalizedCompareKey
        let normalizedCorrect = correct.normalizedCompareKey

        if normalizedUser == normalizedCorrect {
            feedback = "Верно!"
            withAnimation {
                store.markCorrect(word)
            }
            nextWord()
        } else {
            feedback = "Правильно: \(correct)"
        }
        answer = ""
    }

    func nextWord() {
        guard !store.words.isEmpty else {
            currentWord = nil
            return
        }
        currentWord = store.words.randomElement()
        askTranslation = Bool.random()
        feedback = nil
    }
}

// MARK: - Настройки
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    @State private var showingImportSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var exportShareItem: ExportShareItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Лимиты повторов") {
                    Stepper("Слова: \(store.wordRepeatLimit)", value: $store.wordRepeatLimit, in: 1...100)
                    Stepper("Глаголы: \(store.verbRepeatLimit)", value: $store.verbRepeatLimit, in: 1...100)
                    Stepper("Вопросы: \(store.questionRepeatLimit)", value: $store.questionRepeatLimit, in: 1...100)
                    Text("После достижения лимита элемент автоматически переносится в изученные.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Экспорт и импорт") {
                    Button(action: exportWords) {
                        Label("Экспортировать данные", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Импортировать данные", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Очистка") {
                    Button(role: .destructive) {
                        withAnimation { store.words.removeAll() }
                    } label: {
                        Label("Очистить все слова", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        withAnimation { store.irregularVerbs.removeAll() }
                    } label: {
                        Label("Очистить все глаголы", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        withAnimation { store.questions.removeAll() }
                    } label: {
                        Label("Очистить все вопросы", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") { dismiss() }
                }
#endif
            }
            .sheet(item: $exportShareItem) { item in
                ShareSheet(items: [item.url])
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Импорт", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: store.wordRepeatLimit) { store.pruneReachedLimit() }
            .onChange(of: store.verbRepeatLimit) { store.pruneReachedLimit() }
            .onChange(of: store.questionRepeatLimit) { store.pruneReachedLimit() }
        }
    }
    
    private func exportWords() {
        if let url = store.exportBackup() {
            exportShareItem = ExportShareItem(url: url)
        } else {
            alertMessage = "Ошибка при экспорте"
            showingAlert = true
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                alertMessage = "Файл не выбран"
                showingAlert = true
                return
            }
            
            print("Selected file: \(url.lastPathComponent)")
            print("File extension: \(url.pathExtension)")

            let success = store.importBackup(from: url)

            if success {
                alertMessage = "Импорт завершён"
            } else {
                alertMessage = "Ошибка при импорте. Попробуйте выбрать файл ещё раз или проверьте формат."
            }
            showingAlert = true
            
        case .failure(let error):
            print("File selection error: \(error)")
            alertMessage = "Ошибка выбора файла: \(error.localizedDescription)"
            showingAlert = true
        }
    }

}

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet для экспорта
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: View {
    let items: [Any]
    
    var body: some View {
        Text("Экспорт завершен")
            .onAppear {
                // На macOS можно использовать NSSharingService или просто показать уведомление
                if let url = items.first as? URL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
    }
}
#endif

// MARK: - Утилиты
fileprivate extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCompareKey: String {
        self.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func trimmedLowercasedIfNeeded() -> String {
        // лёгкая нормализация: убираем лишние пробелы; регистр не ломаем принудительно,
        // но можно привести к нижнему для консистентности:
        self.trimmed
    }
}

#Preview {
    ContentView()
}
