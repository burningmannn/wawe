//
//  ContentView.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import PhotosUI
#if os(macOS)
import AppKit
#endif

import Foundation
import ImageIO


struct FlexNoteTable: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var headers: [String]
    var rows: [[String]]
    var footer: [String]

    init(id: UUID = UUID(), title: String, headers: [String] = [], rows: [[String]] = [], footer: [String] = []) {
        self.id = id
        self.title = title
        self.headers = headers
        self.rows = rows
        self.footer = footer
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



struct ToolbarSearchField: View {
    @Binding var text: String
    var prompt: String = "Поиск"
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField(prompt, text: $text)
                .font(.subheadline)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 200)
    }
}

// MARK: - Хранилище слов
class WordStore: ObservableObject {
    @AppStorage("wordRepeatLimit") var wordRepeatLimit: Int = 30
    @AppStorage("verbRepeatLimit") var verbRepeatLimit: Int = 30
    @AppStorage("questionRepeatLimit") var questionRepeatLimit: Int = 30
    @AppStorage("learnedWordsTotal") var learnedWordsTotal: Int = 0
    @AppStorage("learnedVerbsTotal") var learnedVerbsTotal: Int = 0
    @AppStorage("learnedQuestionsTotal") var learnedQuestionsTotal: Int = 0

    @Published var words: [Word] = [] {
        didSet { saveWords() }
    }
    
    @Published var irregularVerbs: [IrregularVerb] = [] {
        didSet { saveIrregularVerbs() }
    }

    @Published var questions: [QuestionItem] = [] {
        didSet { saveQuestions() }
    }

    @Published var imageNotes: [ImageNote] = [] {
        didSet { saveImageNotes() }
    }
    
    @Published var notesTables: [FlexNoteTable] = [] {
        didSet { saveNotes() }
    }

    init() {
        load()
        migrateLegacyRepeatLimit()
        pruneReachedLimit()
    }

    func addImageNote(title: String, imageURL: String, descriptionMarkdown: String) {
        let note = ImageNote(title: title.trimmed, imageURL: imageURL.trimmed, descriptionMarkdown: descriptionMarkdown)
        imageNotes.append(note)
    }
    
    func updateImageNote(_ note: ImageNote, title: String? = nil, imageURL: String? = nil, descriptionMarkdown: String? = nil) {
        guard let idx = imageNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var n = imageNotes[idx]
        if let title = title { n.title = title.trimmed }
        if let imageURL = imageURL { n.imageURL = imageURL.trimmed }
        if let descriptionMarkdown = descriptionMarkdown { n.descriptionMarkdown = descriptionMarkdown }
        imageNotes[idx] = n
    }
    
    func removeImageNote(_ note: ImageNote) {
        imageNotes.removeAll { $0.id == note.id }
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

    func clearWords() {
        words.removeAll()
    }
    
    func clearIrregularVerbs() {
        irregularVerbs.removeAll()
    }
    
    func clearQuestions() {
        questions.removeAll()
    }
    
    func clearImageNotes() {
        imageNotes.removeAll()
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
        recordDailyProgress()
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
        recordDailyProgress()
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
        recordDailyProgress()
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
        if countAsLearned { learnedWordsTotal += 1 }
        words.remove(at: index)
    }

    private func completeVerb(at index: Int, countAsLearned: Bool = true) {
        guard irregularVerbs.indices.contains(index) else { return }
        if countAsLearned { learnedVerbsTotal += 1 }
        irregularVerbs.remove(at: index)
    }

    private func completeQuestion(at index: Int, countAsLearned: Bool = true) {
        guard questions.indices.contains(index) else { return }
        if countAsLearned { learnedQuestionsTotal += 1 }
        questions.remove(at: index)
    }

    func addNoteTable(title: String, footer: [String] = []) {
        let defaultHeaders = ["Колонка 1", "Колонка 2"]
        notesTables.append(FlexNoteTable(title: title.trimmed, headers: defaultHeaders, rows: [], footer: footer))
    }

    func addNoteTable(title: String, headers: [String], footer: [String] = []) {
        let normalizedHeaders = headers.map { $0.trimmed }.filter { !$0.isEmpty }
        notesTables.append(FlexNoteTable(title: title.trimmed, headers: normalizedHeaders.isEmpty ? ["Колонка 1"] : normalizedHeaders, rows: [], footer: footer))
    }

    func addNoteRow(to table: FlexNoteTable) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        t.rows.append(Array(repeating: "", count: t.headers.count))
        notesTables[idx] = t
    }

    func updateNoteCell(in table: FlexNoteTable, row: Int, column: Int, value: String) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        guard t.rows.indices.contains(row) else { return }
        guard (0..<t.headers.count).contains(column) else { return }
        var r = t.rows[row]
        if r.count < t.headers.count {
            r += Array(repeating: "", count: t.headers.count - r.count)
        }
        r[column] = value.trimmed
        t.rows[row] = r
        notesTables[idx] = t
    }

    func addNoteColumn(to table: FlexNoteTable, header: String) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        t.headers.append(header.trimmed.isEmpty ? "Колонка \(t.headers.count + 1)" : header.trimmed)
        t.rows = t.rows.map { $0 + [""] }
        notesTables[idx] = t
    }

    func removeNoteColumn(from table: FlexNoteTable, at index: Int) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        guard t.headers.indices.contains(index) else { return }
        t.headers.remove(at: index)
        t.rows = t.rows.map { row in
            var r = row
            if r.indices.contains(index) { r.remove(at: index) }
            return r
        }
        notesTables[idx] = t
    }

    func updateNoteHeader(in table: FlexNoteTable, at index: Int, value: String) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        guard t.headers.indices.contains(index) else { return }
        t.headers[index] = value.trimmed
        notesTables[idx] = t
    }

    func updateNoteFooter(for table: FlexNoteTable, footer: [String]) {
        guard let idx = notesTables.firstIndex(where: { $0.id == table.id }) else { return }
        var t = notesTables[idx]
        t.footer = footer
        notesTables[idx] = t
    }

    func removeNoteTable(_ table: FlexNoteTable) {
        notesTables.removeAll { $0.id == table.id }
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

    private func mergeNotesTables(_ importedTables: [FlexNoteTable]) -> Int {
        var importedCount = 0
        for importedTable in importedTables {
            let titleKey = importedTable.title.normalizedCompareKey
            if let idx = notesTables.firstIndex(where: { $0.title.normalizedCompareKey == titleKey }) {
                var table = notesTables[idx]
                if table.headers.map(\.normalizedCompareKey) == importedTable.headers.map(\.normalizedCompareKey) {
                    for row in importedTable.rows {
                        let existsRow = table.rows.contains { $0 == row }
                        if !existsRow {
                            table.rows.append(row)
                            importedCount += 1
                        }
                    }
                } else {
                    notesTables.append(importedTable)
                    importedCount += 1
                    continue
                }
                var mergedFooter = table.footer
                for line in importedTable.footer {
                    if !mergedFooter.contains(where: { $0.normalizedCompareKey == line.normalizedCompareKey }) {
                        mergedFooter.append(line)
                        importedCount += 1
                    }
                }
                table.footer = mergedFooter
                notesTables[idx] = table
            } else {
                notesTables.append(importedTable)
                importedCount += 1
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
            
            let profileBadges = UserDefaults.standard.string(forKey: "profileBadges")

            let payload = BackupPayload(
                words: words,
                irregularVerbs: irregularVerbs,
                questions: questions,
                imageNotes: imageNotes,
                notesTables: notesTables,
                settings: BackupSettings(
                    wordRepeatLimit: wordRepeatLimit,
                    verbRepeatLimit: verbRepeatLimit,
                    questionRepeatLimit: questionRepeatLimit,
                    profileBadges: profileBadges
                ),
                version: "2.1",
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
        let importedImageNotes = mergeImageNotes(payload.imageNotes)
        let importedNotesTables = mergeNotesTables(payload.notesTables)

        let settings = payload.settings
        let settingsChanged =
            settings.wordRepeatLimit != wordRepeatLimit ||
            settings.verbRepeatLimit != verbRepeatLimit ||
            settings.questionRepeatLimit != questionRepeatLimit

        wordRepeatLimit = settings.wordRepeatLimit
        verbRepeatLimit = settings.verbRepeatLimit
        questionRepeatLimit = settings.questionRepeatLimit
        
        if let badges = settings.profileBadges {
            UserDefaults.standard.set(badges, forKey: "profileBadges")
            print("Imported profileBadges: \(badges)")
        }

        removeCompletedWords(countAsLearned: false)
        removeCompletedVerbs(countAsLearned: false)
        removeCompletedQuestions(countAsLearned: false)

        print("Payload import summary: +\(importedWords) words, +\(importedVerbs) verbs, +\(importedQuestions) questions, +\(importedImageNotes) imageNotes, +\(importedNotesTables) legacyNotesTables, settingsChanged: \(settingsChanged)")

        return (importedWords + importedVerbs + importedQuestions + importedImageNotes + importedNotesTables) > 0 || settingsChanged
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

    private func mergeImageNotes(_ imported: [ImageNote]) -> Int {
        var added = 0
        for note in imported {
            let key = "\(note.title.normalizedCompareKey)|\(note.imageURL.normalizedCompareKey)"
            let exists = imageNotes.contains {
                "\( $0.title.normalizedCompareKey)|\($0.imageURL.normalizedCompareKey)" == key
            }
            if !exists {
                imageNotes.append(note)
                added += 1
            }
        }
        return added
    }

    private func recordDailyProgress() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: "progressDays") ?? ""
        var set = Set(raw.split(separator: ",").map { String($0) })
        if !set.contains(todayKey) {
            set.insert(todayKey)
            defaults.set(Array(set).sorted().joined(separator: ","), forKey: "progressDays")
        }
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var map: [String: Int] = [:]
        if let data = defaults.data(forKey: "progressDayCounts"),
           let decoded = try? decoder.decode([String:Int].self, from: data) {
            map = decoded
        }
        map[todayKey] = (map[todayKey] ?? 0) + 1
        if let data = try? encoder.encode(map) {
            defaults.set(data, forKey: "progressDayCounts")
        }
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

    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notesTables)
            UserDefaults.standard.set(data, forKey: "notesTables")
        } catch {
            print("Save notes error: \(error)")
        }
    }
    
    private func saveImageNotes() {
        do {
            let data = try JSONEncoder().encode(imageNotes)
            UserDefaults.standard.set(data, forKey: "imageNotes")
        } catch {
            print("Save image notes error: \(error)")
        }
    }

    struct LegacyNoteRow: Codable {
        let situation: String
        let usage: String
    }
    struct LegacyNoteTable: Codable {
        let id: UUID
        let title: String
        let rows: [LegacyNoteRow]
        let footer: [String]
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "words") {
            do {
                let decoded = try JSONDecoder().decode([Word].self, from: data)
                words = decoded
            } catch {
                print("Load words error: \(error)")
            }
        }
        
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

        if let data = UserDefaults.standard.data(forKey: "notesTables") {
            do {
                let decoded = try JSONDecoder().decode([FlexNoteTable].self, from: data)
                notesTables = decoded
            } catch {
                if let legacyTables = try? JSONDecoder().decode([LegacyNoteTable].self, from: data) {
                    notesTables = legacyTables.map { legacy in
                        let headers = ["Ситуация", "Что использовать"]
                        let rows = legacy.rows.map { [$0.situation, $0.usage] }
                        return FlexNoteTable(id: legacy.id, title: legacy.title, headers: headers, rows: rows, footer: legacy.footer)
                    }
                } else {
                    print("Load notes error: \(error)")
                }
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: "imageNotes") {
            do {
                let decoded = try JSONDecoder().decode([ImageNote].self, from: data)
                imageNotes = decoded
            } catch {
                print("Load image notes error: \(error)")
            }
        }
    }
}

// MARK: - Главный экран
struct ContentView: View {
    @StateObject private var store = WordStore()
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    private var accentColor: Color {
        appTheme == "dark" ? .white : .black
    }

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
            
            NotesView(store: store)
                .tabItem {
                    Label("Заметки", systemImage: "note.text")
                }
            
            ProfileView(store: store)
                .tabItem {
                    Label("Профиль", systemImage: "person.crop.circle")
                }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
    }
}

// MARK: - Экран обычных слов
struct WordsView: View {
    @ObservedObject var store: WordStore
    @StateObject private var viewModel: WordsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""

    init(store: WordStore) {
        self._store = ObservedObject(initialValue: store)
        _viewModel = StateObject(wrappedValue: WordsViewModel(repo: WordsRepositoryStoreAdapter(store: store)))
    }

    var filteredWords: [Word] { viewModel.state.filtered }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section("Статистика") {
                StatisticRow(title: "Всего слов", systemImage: "number.square", value: viewModel.state.all.count)
                if filteredWords.count != viewModel.state.all.count {
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
                    Button(role: .destructive) { viewModel.send(.deleteItem(word)) } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading) {
                    Button { viewModel.send(.markCorrect(word)) } label: {
                        Label("+1 прогресс", systemImage: "checkmark.circle")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredWords.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Пока пусто", systemImage: "book", description: Text("Добавь слова через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    listContent
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            .onChange(of: search) { _, newValue in viewModel.send(.search(newValue)) }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
#else
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                    if !viewModel.state.all.isEmpty {
                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Label("Очистить", systemImage: "trash")
                        }
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
            .alert("Очистить все слова?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    store.clearWords()
                }
            } message: {
                Text("Действие нельзя отменить. Все слова будут удалены.")
            }
        }
    }
}

// MARK: - Экран неправильных глаголов
struct IrregularVerbsView: View {
    @ObservedObject var store: WordStore
    @StateObject private var viewModel: VerbsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""
    
    init(store: WordStore) {
        self._store = ObservedObject(initialValue: store)
        _viewModel = StateObject(wrappedValue: VerbsViewModel(repo: VerbsRepositoryStoreAdapter(store: store)))
    }
    
    var filteredVerbs: [IrregularVerb] { viewModel.state.filtered }

    var body: some View {
        NavigationStack {
            Group {
                if filteredVerbs.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Нет неправильных глаголов", systemImage: "textformat.abc", description: Text("Добавь глаголы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего глаголов", systemImage: "number.square", value: viewModel.state.all.count)
                            if filteredVerbs.count != viewModel.state.all.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredVerbs.count)
                            }
                        }

                        ForEach(filteredVerbs) { verb in
                            NavigationLink {
                                EditIrregularVerbView(store: store, verb: verb)
                            } label: {
                                IrregularVerbRow(verb: verb, repeatLimit: viewModel.state.repeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.send(.deleteItem(verb)) } label: {
                                    Label("Удалить", systemImage: "trash")
                    }
                    .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { viewModel.send(.markCorrect(verb)) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.primary)
                            }
                        }
                        .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            .onChange(of: search) { _, newValue in viewModel.send(.search(newValue)) }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
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
            .alert("Удалить все глаголы?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    store.clearIrregularVerbs()
                }
            } message: {
                Text("Действие нельзя отменить. Все глаголы будут удалены.")
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
            .navigationTitle("")
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
        .navigationTitle("")
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

struct NotesView: View {
    @ObservedObject var store: WordStore
    @State private var showingAddImageNote = false
    @State private var editingImageNote: ImageNote?
    @State private var showingClearAlert = false
    @State private var search = ""
    @State private var sortByTitle = false
    @State private var draggedNote: ImageNote?

    private var filteredNotes: [ImageNote] {
        let base = store.imageNotes.filter { note in
            let q = search.trimmed
            return q.isEmpty || note.title.localizedCaseInsensitiveContains(q)
        }
        return sortByTitle ? base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } : base
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredNotes.isEmpty {
                    if store.imageNotes.isEmpty {
                        ContentUnavailableView("Нет заметок", systemImage: "note.text", description: Text("Добавь заметку через +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNotes) { note in
                                NavigationLink {
                                    EditImageNoteView(store: store, note: note)
                                } label: {
                                    ImageNoteRow(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingImageNote = note
                                    } label: {
                                        Label("Редактировать", systemImage: "square.and.pencil")
                                    }
                                    Button(role: .destructive) {
                                        store.removeImageNote(note)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                                .onDrag {
                                    self.draggedNote = note
                                    return NSItemProvider(object: note.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: NoteDropDelegate(destinationItem: note, notes: $store.imageNotes, draggedItem: $draggedNote))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !store.imageNotes.isEmpty {
                            Button(role: .destructive) { showingClearAlert = true } label: { Label("Очистить", systemImage: "trash") }
                        }
                        Button { showingAddImageNote = true } label: { Image(systemName: "plus") }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Сортировка", selection: $sortByTitle) {
                            Text("По названию").tag(true)
                            Text("По добавлению").tag(false)
                        }
                    } label: {
                        Label("Фильтр", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button { showingAddImageNote = true } label: { Image(systemName: "plus") }
                }
#endif
            }
            .sheet(isPresented: $showingAddImageNote) {
                AddImageNoteView(store: store)
            }
            .sheet(item: $editingImageNote) { note in
                EditImageNoteView(store: store, note: note)
            }
            .alert("Удалить все заметки?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    store.clearImageNotes()
                }
            } message: {
                Text("Действие нельзя отменить. Все заметки будут удалены.")
            }
        }
    }
}

struct ImageNoteRow: View {
    let note: ImageNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: note.imageURL)) { phase in
                switch phase {
                case .empty:
                    SkeletonView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                        .clipped()
                case .failure:
                    ZStack {
                        Rectangle().fill(Color.secondary.opacity(0.1))
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                @unknown default:
                    EmptyView()
                }
            }
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                if !note.descriptionMarkdown.isEmpty {
                    Text(note.descriptionMarkdown)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Добавить заметку с картинкой
struct AddImageNoteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    @State private var title = ""
    @State private var imageURL = ""
    @State private var descriptionMarkdown = ""
    @State private var isValidResolution = false
    @State private var isChecking = false
    @State private var checkMessage = ""
    
    var canSave: Bool {
        !title.trimmed.isEmpty && URL(string: imageURL.trimmed) != nil && isValidResolution
    }
    
    private func checkResolution() {
        guard let url = URL(string: imageURL.trimmed) else { return }
        isChecking = true
        checkMessage = ""
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let cfData = data as CFData
                if let src = CGImageSourceCreateWithData(cfData, nil),
                   let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                   let w = props[kCGImagePropertyPixelWidth] as? Int,
                   let h = props[kCGImagePropertyPixelHeight] as? Int {
                    isValidResolution = (w == 1920 && h == 1080)
                    checkMessage = isValidResolution ? "ОК 1920×1080" : "Не 1920×1080 (\(w)×\(h))"
                } else {
                    isValidResolution = false
                    checkMessage = "Не удалось определить размер"
                }
            } catch {
                isValidResolution = false
                checkMessage = "Ошибка загрузки"
            }
            isChecking = false
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Новая заметка") {
                    TextField("Тема", text: $title)
                    TextField("Ссылка на картинку (URL)", text: $imageURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    HStack {
                        Button("Проверить 1920×1080") { checkResolution() }
                            .disabled(imageURL.trimmed.isEmpty)
                        Spacer()
                        if isChecking { ProgressView() }
                        if !checkMessage.isEmpty { Text(checkMessage).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Section("Описание") {
                    TextEditor(text: $descriptionMarkdown)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.addImageNote(title: title.trimmed, imageURL: imageURL.trimmed, descriptionMarkdown: descriptionMarkdown)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        if canSave {
                            store.addImageNote(title: title.trimmed, imageURL: imageURL.trimmed, descriptionMarkdown: descriptionMarkdown)
                            dismiss()
                        }
                    }
                }
#endif
            }
        }
    }
}

// MARK: - Редактировать заметку с картинкой
struct EditImageNoteView: View, Identifiable {
    let id = UUID()
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: WordStore
    let note: ImageNote
    @State private var title: String
    @State private var imageURL: String
    @State private var descriptionMarkdown: String
    @State private var isValidResolution = true
    @State private var isChecking = false
    @State private var checkMessage = ""
    
    init(store: WordStore, note: ImageNote) {
        self.store = store
        self.note = note
        _title = State(initialValue: note.title)
        _imageURL = State(initialValue: note.imageURL)
        _descriptionMarkdown = State(initialValue: note.descriptionMarkdown)
    }
    
    var canSave: Bool {
        !title.trimmed.isEmpty && URL(string: imageURL.trimmed) != nil && isValidResolution
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Редактировать заметку") {
                    TextField("Тема", text: $title)
                    TextField("Ссылка на картинку (URL)", text: $imageURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    HStack {
                        Button("Проверить 1920×1080") {
                            guard let url = URL(string: imageURL.trimmed) else { return }
                            isChecking = true
                            checkMessage = ""
                            Task {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    let cfData = data as CFData
                                    if let src = CGImageSourceCreateWithData(cfData, nil),
                                       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                                       let w = props[kCGImagePropertyPixelWidth] as? Int,
                                       let h = props[kCGImagePropertyPixelHeight] as? Int {
                                        isValidResolution = (w == 1920 && h == 1080)
                                        checkMessage = isValidResolution ? "ОК 1920×1080" : "Не 1920×1080 (\(w)×\(h))"
                                    } else {
                                        isValidResolution = false
                                        checkMessage = "Не удалось определить размер"
                                    }
                                } catch {
                                    isValidResolution = false
                                    checkMessage = "Ошибка загрузки"
                                }
                                isChecking = false
                            }
                        }
                        Spacer()
                        if isChecking { ProgressView() }
                        if !checkMessage.isEmpty { Text(checkMessage).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Section("Описание") {
                    TextEditor(text: $descriptionMarkdown)
                        .frame(minHeight: 120)
                }
                Section {
                    Button(role: .destructive) {
                        store.removeImageNote(note)
                        dismiss()
                    } label: {
                        Label("Удалить заметку", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if canSave {
                            store.updateImageNote(note, title: title.trimmed, imageURL: imageURL.trimmed, descriptionMarkdown: descriptionMarkdown)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        if canSave {
                            store.updateImageNote(note, title: title.trimmed, imageURL: imageURL.trimmed, descriptionMarkdown: descriptionMarkdown)
                            dismiss()
                        }
                    }
                }
#endif
            }
        }
    }
}


// MARK: - Экран вопросов
struct QuestionsView: View {
    @ObservedObject var store: WordStore
    @StateObject private var viewModel: QuestionsViewModel
    @State private var showingAdd = false
    @State private var showingTest = false
    @State private var showingClearAlert = false
    @State private var search = ""

    init(store: WordStore) {
        self._store = ObservedObject(initialValue: store)
        _viewModel = StateObject(wrappedValue: QuestionsViewModel(store: store))
    }
    
    var filteredQuestions: [QuestionItem] { viewModel.state.filtered }

    var body: some View {
        NavigationStack {
            Group {
                if filteredQuestions.isEmpty {
                    if viewModel.state.all.isEmpty {
                        ContentUnavailableView("Нет вопросов", systemImage: "questionmark.circle", description: Text("Добавь вопросы через кнопку +"))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text("Измени запрос поиска"))
                    }
                } else {
                    List {
                        Section("Статистика") {
                            StatisticRow(title: "Всего вопросов", systemImage: "number.square", value: viewModel.state.all.count)
                            if filteredQuestions.count != viewModel.state.all.count {
                                StatisticRow(title: "В подборке", systemImage: "line.3.horizontal.decrease.circle", value: filteredQuestions.count)
                            }
                        }

                        ForEach(filteredQuestions) { question in
                            NavigationLink {
                                EditQuestionView(store: store, question: question)
                            } label: {
                                QuestionRow(question: question, repeatLimit: viewModel.state.repeatLimit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { viewModel.send(.deleteItem(question)) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { viewModel.send(.markCorrect(question)) } label: {
                                    Label("+1 прогресс", systemImage: "checkmark.circle")
                                }
                                .tint(.primary)
                            }
                        }
                        .onDelete(perform: { offsets in viewModel.send(.delete(offsets)) })
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(.automatic)
#endif
                }
            }
            .onChange(of: search) { _, newValue in viewModel.send(.search(newValue)) }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarSearchField(text: $search, prompt: "Поиск")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Тест", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !viewModel.state.all.isEmpty {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
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
            .alert("Удалить все вопросы?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    store.clearQuestions()
                }
            } message: {
                Text("Действие нельзя отменить. Все вопросы будут удалены.")
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
                    TextField("Вопрос (например, What?)", text: $prompt, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)

                    TextField("Перевод (например, Что?)", text: $answer, axis: .vertical)
#if os(iOS)
                        .textInputAutocapitalization(.sentences)
#endif
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("")
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
                TextField("Вопрос (например, What?)", text: $prompt, axis: .vertical)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                TextField("Перевод (например, Что?)", text: $answer, axis: .vertical)
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
        .navigationTitle("")
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
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
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
            .navigationTitle("")
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
        .navigationTitle("")
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
                if currentVerb != nil {
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
            .navigationTitle("")
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
            return .primary // Завершенные шаги
        } else if step == currentStep {
            return .primary // Текущий шаг
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
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
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
    @State private var showingAbout = false

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

                Section {
                    Button {
                        showingAbout = true
                    } label: {
                        Text("О приложении v1.0")
                            .foregroundStyle(.primary)
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
            .navigationTitle("")
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
            .sheet(isPresented: $showingAbout) {
                AboutView()
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
extension String {
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

struct AppColors {
    static let sessionBlue = Color.primary
    static let badgeVIP = Color.hex("#FFD60A")
    static let badgeDay1Start = Color.hex("#0A84FF")
    static let badgeDay1End = Color.hex("#5E5CE6")
    static let badge10YR = Color.hex("#64D2FF")
    static let badge8YR = Color.hex("#FF375F")
    static let badgePro = Color.hex("#30D158")
    static let streak1 = Color.primary
    static let streak2 = Color.primary
    static let streak3 = Color.primary
    static let streak4 = Color.primary
    static let streak5 = Color.primary
    static let streak6 = Color.primary
}

extension Color {
    static func hex(_ hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
struct ProfileView: View {
    @AppStorage("profileName") private var profileName: String = "Пользователь"
    @AppStorage("profileBio") private var profileBio: String = ""
    @AppStorage("profileBadges") private var profileBadgesRaw: String = ""
    @AppStorage("profileAccountId") private var profileAccountId: String = ""
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("profileFeaturedBadge") private var profileFeaturedBadge: String = ""
    @AppStorage("profileBackgroundURL") private var profileBackgroundURL: String = ""
    @AppStorage("profileAvatarURL") private var profileAvatarURL: String = ""
    @ObservedObject var store: WordStore
    @State private var showingImportSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var exportShareItem: ExportShareItem?
    @AppStorage("profileBackgroundData") private var profileBackgroundData: Data = Data()
    @AppStorage("profileAvatarData") private var profileAvatarData: Data = Data()
    @State private var editing = false
    @State private var showingAbout = false
    @State private var showCopiedToast = false
    @State private var showMediaSheet = false
    @State private var bgPickerItem: PhotosPickerItem?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var showAvatarPicker = false
    @State private var showBgPicker = false

    private var progressDaysSet: Set<String> {
        let raw = UserDefaults.standard.string(forKey: "progressDays") ?? ""
        return Set(raw.split(separator: ",").map { String($0) })
    }
    private var progressDaysCount: Int { progressDaysSet.count }
    private var streakCount: Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var count = 0
        var day = Date()
        while progressDaysSet.contains(formatter.string(from: day)) {
            count += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }
    private var last30Keys: [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return (0..<30).map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return formatter.string(from: d)
        }.reversed()
    }
    private var currentStreakKeys: Set<String> {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var keys = Set<String>()
        var day = Date()
        var left = streakCount
        while left > 0 {
            keys.insert(formatter.string(from: day))
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
            left -= 1
        }
        return keys
    }
    private func streakTier(_ count: Int) -> Int {
        if count >= 120 { return 6 }
        if count >= 60 { return 5 }
        if count >= 30 { return 4 }
        if count >= 14 { return 3 }
        if count >= 7 { return 2 }
        if count >= 3 { return 1 }
        return 0
    }
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 6: return AppColors.streak6
        case 5: return AppColors.streak5
        case 4: return AppColors.streak4
        case 3: return AppColors.streak3
        case 2: return AppColors.streak2
        case 1: return AppColors.streak1
        default: return Color.secondary.opacity(0.5)
        }
    }
    private var streakTierValue: Int { streakTier(streakCount) }
    private var allStreakBadges: [String] { ["7DAY", "30DAY", "60DAY", "120DAY", "210DAY", "1YR"] }
    private var unlockedStreakBadges: [String] {
        var res: [String] = []
        if streakCount >= 7 { res.append("7DAY") }
        if streakCount >= 30 { res.append("30DAY") }
        if streakCount >= 60 { res.append("60DAY") }
        if streakCount >= 120 { res.append("120DAY") }
        if streakCount >= 210 { res.append("210DAY") }
        if streakCount >= 365 { res.append("1YR") }
        return res
    }
    private func badgeDisplayName(_ name: String) -> String {
        switch name {
        case "BASE": return "BASE"
        case "PRO": return "PRO"
        case "VIP": return "VIP"
        case "7DAY": return "7 DAY"
        case "30DAY": return "30 DAY"
        case "60DAY": return "60 DAY"
        case "120DAY": return "120 DAY"
        case "210DAY": return "210 DAY"
        case "1YR": return "1 YR"
        case "LEARNED100": return "100 Words"
        case "LEARNED500": return "500 Words"
        case "LEARNED1000": return "1000 Words"
        default: return name
        }
    }
    private func badgeStyle(_ name: String) -> BadgeStyle {
        switch name {
        case "BASE": return .base
        case "PRO": return .pro
        case "VIP": return .vip
        case "7DAY": return .streak(days: 7)
        case "30DAY": return .streak(days: 30)
        case "60DAY": return .streak(days: 60)
        case "120DAY": return .streak(days: 120)
        case "210DAY": return .streak(days: 210)
        case "1YR": return .streak(days: 365)
        case "LEARNED100": return .learned(count: 100)
        case "LEARNED500": return .learned(count: 500)
        case "LEARNED1000": return .learned(count: 1000)
        default: return .base
        }
    }

    private var badges: [String] { profileBadgesRaw.split(separator: ",").map { String($0) } }
    private func setBadges(_ b: [String]) { profileBadgesRaw = b.joined(separator: ",") }

    private let availableBadges = ["BASE", "PRO", "VIP", "7DAY", "30DAY", "60DAY", "120DAY", "210DAY", "1YR", "LEARNED100", "LEARNED500", "LEARNED1000"]
    
    private func ensureAccountId() {
        if profileAccountId.isEmpty {
            profileAccountId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
    }
    
    private func ensureFeaturedBadge() {
        if profileFeaturedBadge.isEmpty {
            profileFeaturedBadge = "BASE"
        }
    }
    private func ensureStreakBadges() {
        var set = Set(badges)
        for b in unlockedStreakBadges { set.insert(b) }
        setBadges(Array(set))
    }
    private var unlockedLearnedBadges: [String] {
        var res: [String] = []
        if store.learnedWordsTotal >= 100 { res.append("LEARNED100") }
        if store.learnedWordsTotal >= 500 { res.append("LEARNED500") }
        if store.learnedWordsTotal >= 1000 { res.append("LEARNED1000") }
        return res
    }
    private func ensureLearnedBadges() {
        var set = Set(badges)
        for b in unlockedLearnedBadges { set.insert(b) }
        setBadges(Array(set))
    }
    private func isUnlockedBadge(_ name: String) -> Bool {
        return true
    }
    private var progressCountsMap: [String:Int] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "progressDayCounts"),
           let decoded = try? JSONDecoder().decode([String:Int].self, from: data) {
            return decoded
        }
        return [:]
    }
    private var calendarStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
    }

    private func resolvedImageURL(from raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw) {
            if let ext = url.pathComponents.last?.lowercased(), ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg") || ext.hasSuffix(".png") || ext.hasSuffix(".gif") || ext.hasSuffix(".webp") {
                return url
            }
        }
        if var comps = URLComponents(string: raw), let host = comps.host, host.contains("google."), comps.path == "/url" {
            if let qi = comps.queryItems?.first(where: { $0.name == "url" || $0.name == "q" }), let v = qi.value, let direct = URL(string: v) {
                return direct
            }
        }
        return URL(string: raw)
    }

    private func toggleBadge(_ name: String) {
        var set = Set(badges)
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
        setBadges(Array(set))
    }

    private func copyAccountId() {
#if os(iOS)
        UIPasteboard.general.string = profileAccountId
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(profileAccountId, forType: .string)
#endif
    }

    @State private var showingSettingsSheet = false

    var body: some View {
        NavigationStack {
            profileContent
        }
        .sheet(isPresented: $showingSettingsSheet) {
            settingsView
        }
    }
    
    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                
                VStack(spacing: 4) {
                    if editing {
                        TextField("Имя", text: $profileName)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    } else {
                        Text(profileName)
                            .font(.title2.bold())
                    }
                    
                    if editing {
                        TextField("Bio", text: $profileBio)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    } else if !profileBio.isEmpty {
                        Text(profileBio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal)
                    
                if editing {
                    badgeSelector
                }

                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        let width = geo.size.width
                        // 53 недели. Вычислим размер ячейки
                        // width = 53 * size + 52 * spacing
                        // size = (width - 52 * spacing) / 53
                        let spacing: CGFloat = 2
                        let size = max((width - 52 * spacing) / 53, 4)
                        
                        YearProgressGrid(counts: progressCountsMap,
                                         startDate: calendarStartDate,
                                         weeks: 53,
                                         daySize: size,
                                         spacing: spacing,
                                         color: AppColors.sessionBlue)
                    }
                    .frame(height: 80) // Примерная высота: 7 строк * size + spacing... пусть будет фикс
                    
                    HStack {
                        Text("График активности")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(streakCount) дней стрик")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal)
                
                Spacer().frame(height: 40)
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { editing.toggle() }
                } label: {
                    Image(systemName: editing ? "checkmark" : "pencil")
                        .foregroundStyle(.primary)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            ensureAccountId()
            ensureFeaturedBadge()
            ensureStreakBadges()
            ensureLearnedBadges()
        }
        .onChange(of: store.wordRepeatLimit) { store.pruneReachedLimit() }
        .onChange(of: store.verbRepeatLimit) { store.pruneReachedLimit() }
        .onChange(of: store.questionRepeatLimit) { store.pruneReachedLimit() }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Toast(text: "ID скопирован")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .photosPicker(isPresented: $showAvatarPicker, selection: $avatarPickerItem, matching: .images)
        .photosPicker(isPresented: $showBgPicker, selection: $bgPickerItem, matching: .images)
        .sheet(isPresented: $showMediaSheet) { EditProfileMediaSheet(backgroundURL: $profileBackgroundURL, avatarURL: $profileAvatarURL) }
        .sheet(item: $exportShareItem) { item in ShareSheet(items: [item.url]) }
        .fileImporter(isPresented: $showingImportSheet, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) { result in handleImport(result: result) }
        .alert("Импорт", isPresented: $showingAlert) { Button("OK") { } } message: { Text(alertMessage) }
        .onChange(of: bgPickerItem) { _, newItem in
            #if os(iOS)
            guard let item = newItem else { return }
            Task { if let data = try? await item.loadTransferable(type: Data.self) { profileBackgroundData = data } }
            #endif
        }
        .onChange(of: avatarPickerItem) { _, newItem in
            #if os(iOS)
            guard let item = newItem else { return }
            Task { if let data = try? await item.loadTransferable(type: Data.self) { profileAvatarData = data } }
            #endif
        }
    }
    
    private var profileHeader: some View {
        Group {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    ZStack {
                        #if os(iOS)
                        if !profileBackgroundData.isEmpty, let ui = UIImage(data: profileBackgroundData) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else if let url = resolvedImageURL(from: profileBackgroundURL), !profileBackgroundURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Color.secondary.opacity(0.2) }
                            }
                        } else { Color.secondary.opacity(0.2) }
                        #else
                        if let url = resolvedImageURL(from: profileBackgroundURL), !profileBackgroundURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Color.secondary.opacity(0.2) }
                            }
                        } else { Color.secondary.opacity(0.2) }
                        #endif
                        
                        if editing {
                            Color.black.opacity(0.3)
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { showBgPicker = true }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .frame(height: 280)
            }
            .frame(height: 280)

            // Avatar centered on the bottom border
            ZStack(alignment: .top) {
                ZStack {
                    #if os(iOS)
                    if !profileAvatarData.isEmpty, let ui = UIImage(data: profileAvatarData) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let url = resolvedImageURL(from: profileAvatarURL), !profileAvatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.secondary.opacity(0.15)) }
                        }
                    } else { Circle().fill(Color.secondary.opacity(0.15)) }
                    #else
                    if let url = resolvedImageURL(from: profileAvatarURL), !profileAvatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.secondary.opacity(0.15)) }
                        }
                    } else { Circle().fill(Color.secondary.opacity(0.15)) }
                    #endif
                    
                    if editing {
                        Color.black.opacity(0.3)
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Circle())
                            .onTapGesture { showAvatarPicker = true }
                    }
                }
                .frame(width: 150, height: 150)
                .clipShape(Circle())
                .overlay(alignment: .top) {
                    if !profileFeaturedBadge.isEmpty {
                        StreakBadgeBanner(title: badgeDisplayName(profileFeaturedBadge), style: badgeStyle(profileFeaturedBadge))
                            .scaleEffect(0.9)
                            .fixedSize()
                            .offset(y: -40)
                    }
                }
                #if os(iOS)
                .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 4))
                .contextMenu {
                    Button { showAvatarPicker = true } label: { Label("Изменить фото", systemImage: "person.crop.circle") }
                    Button { showBgPicker = true } label: { Label("Изменить фон", systemImage: "photo") }
                }
                #else
                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 4))
                .contextMenu {
                    Button { showMediaSheet = true } label: { Text("Изменить фото/фон") }
                }
                #endif
            }
            .offset(y: -75)
            .padding(.bottom, -75)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var badgeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Выберите значок")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableBadges, id: \.self) { badge in
                        let selected = (profileFeaturedBadge == badge)
                        let style = badgeStyle(badge)
                        
                        HStack(spacing: 4) {
                            if !style.iconName.isEmpty {
                                Image(systemName: style.iconName).font(.caption2)
                            }
                            Text(badgeDisplayName(badge))
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            AnimatedBadgeBackground(style: style)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(selected ? Color.primary : style.borderColor, lineWidth: selected ? 2 : 1)
                                )
                        )
                        .scaleEffect(selected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            profileFeaturedBadge = (profileFeaturedBadge == badge) ? "" : badge
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var settingsView: some View {
        NavigationStack {
            List {
                Section(header: Text("Лимиты повторов")) {
                    HStack {
                        Text("Слова")
                        Spacer()
                        Stepper("", value: $store.wordRepeatLimit, in: 1...100)
                        Text("\(store.wordRepeatLimit)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Глаголы")
                        Spacer()
                        Stepper("", value: $store.verbRepeatLimit, in: 1...100)
                        Text("\(store.verbRepeatLimit)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Вопросы")
                        Spacer()
                        Stepper("", value: $store.questionRepeatLimit, in: 1...100)
                        Text("\(store.questionRepeatLimit)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("Внешний вид")) {
                    Picker("Тема", selection: $appTheme) {
                        Text("Авто").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }
                }
                
                Section(header: Text("Данные")) {
                    Button {
                        exportWords()
                    } label: {
                        Label("Экспорт", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Импорт", systemImage: "square.and.arrow.down")
                    }
                }
                
                Section {
                    Button {
                        showingAbout = true
                    } label: {
                        Text("О приложении v1.0")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        showingSettingsSheet = false
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    private func exportWords() {
        if let url = store.exportBackup() { exportShareItem = ExportShareItem(url: url) }
        else { alertMessage = "Ошибка при экспорте"; showingAlert = true }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { alertMessage = "Файл не выбран"; showingAlert = true; return }
            let success = store.importBackup(from: url)
            alertMessage = success ? "Импорт завершён" : "Ошибка при импорте. Проверьте формат."
            showingAlert = true
        case .failure(let error):
            alertMessage = "Ошибка выбора файла: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct LimitCard: View {
    let title: String
    @Binding var value: Int
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline.monospacedDigit())
            HStack(spacing: 0) {
                Button("-") { if value > 1 { value -= 1 } }
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                    .buttonStyle(.plain)
                Spacer()
                Button("+") { if value < 100 { value += 1 } }
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                    .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content

    init(items: [Item], spacing: CGFloat = 8, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], spacing: spacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

#if os(iOS) || os(macOS)
struct BadgeChip: View {
    let name: String
    let selected: Bool
    
    private var textColor: Color {
        switch name {
        case "VIP": return selected ? .black : .secondary
        case "Base": return selected ? .primary : .secondary
        default: return selected ? .white : .secondary
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if selected {
            switch name {
            case "VIP":
                Capsule().fill(AppColors.badgeVIP)
            case "DAY1":
                Capsule().fill(LinearGradient(colors: [AppColors.badgeDay1Start, AppColors.badgeDay1End], startPoint: .leading, endPoint: .trailing))
            case "10YR":
                Capsule().fill(AppColors.badge10YR)
            case "8YR":
                Capsule().fill(AppColors.badge8YR)
            case "Pro":
                Capsule().fill(AppColors.badgePro)
            case "Base":
                Capsule().fill(Color.secondary.opacity(0.25))
            default:
                Capsule().fill(Color.accentColor.opacity(0.2))
            }
        } else {
            Capsule().fill(Color.secondary.opacity(0.15))
        }
    }
    
    var body: some View {
        Text(name)
            .font(.caption)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundView)
    }
}
#endif

 

#if os(iOS) || os(macOS)
struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 8)
    }
}
#endif

#if os(iOS) || os(macOS)
struct EditProfileMediaSheet: View {
    @Binding var backgroundURL: String
    @Binding var avatarURL: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ссылка на фон")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $backgroundURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ссылка на аватар")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $avatarURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
                }
                Button("Готово") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
    }
}
#endif

#Preview {
    ContentView()
}
