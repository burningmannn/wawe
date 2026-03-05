import SwiftUI
import Combine
import Foundation

// MARK: - Хранилище слов
class WordStore: ObservableObject {
    @AppStorage("wordRepeatLimit") var wordRepeatLimit: Int = 30
    @AppStorage("verbRepeatLimit") var verbRepeatLimit: Int = 30
    @AppStorage("learnedWordsTotal") var learnedWordsTotal: Int = 0
    @AppStorage("learnedVerbsTotal") var learnedVerbsTotal: Int = 0

    @Published var words: [Word] = [] {
        didSet { saveWords() }
    }
    
    @Published var irregularVerbs: [IrregularVerb] = [] {
        didSet { saveIrregularVerbs() }
    }

    @Published var imageNotes: [ImageNote] = [] {
        didSet { saveImageNotes() }
    }
    
    @Published var notesTables: [FlexNoteTable] = [] {
        didSet { saveNotes() }
    }

    @Published var testItems: [TestItem] = [] {
        didSet { saveTestItems() }
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

    // MARK: - TestItems CRUD
    func addTestItem(title: String, type: TestItem.TestType, rawContent: String) {
        testItems.append(TestItem(title: title, type: type, rawContent: rawContent))
    }

    func updateTestItem(_ item: TestItem, title: String, type: TestItem.TestType, rawContent: String) {
        guard let idx = testItems.firstIndex(where: { $0.id == item.id }) else { return }
        testItems[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        testItems[idx].type = type
        testItems[idx].rawContent = rawContent
    }

    func removeTestItem(_ item: TestItem) {
        testItems.removeAll { $0.id == item.id }
    }

    func clearTestItems() {
        testItems.removeAll()
    }

    func addSampleTestItems() {
        let chooseRaw = """
+ The sky is blue.
* The sky is green.
* The sky is red.
+ My dress is beautiful.
* My dress is beauty.
* My dress is beautify.
+ The grass is wet.
* The grass is wetting.
* The grass is wetly.
+ The car is fast.
* The car is fastly.
* The car is fasting.
+ Her shoes are expensive.
* Her shoes is expensive.
* Her shoes were expensively.
+ The apple is sweet.
* The apple is sweetly.
* The apple is sweeting.
+ His glasses are old.
* His glasses is old.
* His glasses are older.
"""
        let fillRaw = """
The weather is *cold* (температура) today, so wear a *warm* (одежда) coat.
She has *long* (длина) hair and *blue* (цвет) eyes.
This is a *difficult* (сложность) test, but you are *smart* (способности) enough.
The room was *dark* (освещение) and *quiet* (звук) at night.
He is *tall* (рост) and *strong* (физическое состояние) for his age.
"""
        let sampleChoose = TestItem(title: "Прилагательные — выбери верное", type: .chooseCorrect, rawContent: chooseRaw)
        let sampleFill   = TestItem(title: "Прилагательные — заполни пропуски", type: .fillInBlanks, rawContent: fillRaw)

        for sample in [sampleChoose, sampleFill] {
            let exists = testItems.contains {
                $0.title.lowercased() == sample.title.lowercased() && $0.type == sample.type
            }
            if !exists {
                testItems.append(sample)
            }
        }
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
        markItemCorrect(word, in: \.words, limit: wordRepeatLimit, category: "word") { [weak self] idx in
            self?.completeWord(at: idx)
        }
    }

    // Подчистить слова, которые уже превысили новый лимит
    func pruneReachedLimit() {
        removeCompletedWords(countAsLearned: false)
        removeCompletedVerbs(countAsLearned: false)
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
        markItemCorrect(verb, in: \.irregularVerbs, limit: verbRepeatLimit, category: "verb") { [weak self] idx in
            self?.completeVerb(at: idx)
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
        }
    }

    func repeatLimit(for section: StudySection) -> Int {
        switch section {
        case .words: return wordRepeatLimit
        case .verbs: return verbRepeatLimit
        }
    }

    func activeItemsCount(for section: StudySection) -> Int {
        switch section {
        case .words: return words.count
        case .verbs: return irregularVerbs.count
        }
    }

    // MARK: - Generic Logic

    private func markItemCorrect<T: LearnableItem>(_ item: T, in keyPath: ReferenceWritableKeyPath<WordStore, [T]>, limit: Int, category: String, completeAction: (Int) -> Void) {
        var items = self[keyPath: keyPath]
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }

        items[idx].correctCount += 1
        self[keyPath: keyPath] = items

        recordDailyProgress(category: category)

        if items[idx].correctCount >= limit {
            completeAction(idx)
        }
    }

    private func completeItem<T>(at index: Int, in keyPath: ReferenceWritableKeyPath<WordStore, [T]>, counterKeyPath: ReferenceWritableKeyPath<WordStore, Int>, countAsLearned: Bool) {
        var items = self[keyPath: keyPath]
        guard items.indices.contains(index) else { return }
        
        if countAsLearned {
            self[keyPath: counterKeyPath] += 1
        }
        items.remove(at: index)
        self[keyPath: keyPath] = items
    }

    private func removeCompletedItems<T: LearnableItem>(
        in keyPath: ReferenceWritableKeyPath<WordStore, [T]>,
        limit: Int,
        counterKeyPath: ReferenceWritableKeyPath<WordStore, Int>,
        countAsLearned: Bool
    ) {
        guard limit > 0 else { return }
        let items = self[keyPath: keyPath]
        for index in items.indices.reversed() where items[index].correctCount >= limit {
             completeItem(at: index, in: keyPath, counterKeyPath: counterKeyPath, countAsLearned: countAsLearned)
        }
    }

    private func completeWord(at index: Int, countAsLearned: Bool = true) {
        completeItem(at: index, in: \.words, counterKeyPath: \.learnedWordsTotal, countAsLearned: countAsLearned)
    }

    private func completeVerb(at index: Int, countAsLearned: Bool = true) {
        completeItem(at: index, in: \.irregularVerbs, counterKeyPath: \.learnedVerbsTotal, countAsLearned: countAsLearned)
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
        removeCompletedItems(in: \.words, limit: wordRepeatLimit, counterKeyPath: \.learnedWordsTotal, countAsLearned: countAsLearned)
    }

    private func removeCompletedVerbs(countAsLearned: Bool = true) {
        removeCompletedItems(in: \.irregularVerbs, limit: verbRepeatLimit, counterKeyPath: \.learnedVerbsTotal, countAsLearned: countAsLearned)
    }

    private func merge<T: LearnableItem>(_ importedItems: [T], into existingItems: inout [T], itemDescription: (T) -> String) -> Int {
        var importedCount = 0
        for importedItem in importedItems {
            let exists = existingItems.contains { item in
                item.comparisonKey == importedItem.comparisonKey
            }
            if !exists {
                existingItems.append(importedItem)
                importedCount += 1
                print("Imported: \(itemDescription(importedItem))")
            } else {
                print("Already exists: \(itemDescription(importedItem))")
            }
        }
        return importedCount
    }
    
    private func mergeWords(_ importedWords: [Word]) -> Int {
        merge(importedWords, into: &words) { "\($0.original) -> \($0.translation)" }
    }

    private func mergeVerbs(_ importedVerbs: [IrregularVerb]) -> Int {
        merge(importedVerbs, into: &irregularVerbs) { "\($0.infinitive) - \($0.pastSimple) - \($0.pastParticiple)" }
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

        defaults.removeObject(forKey: "repeatLimit")
    }

    // MARK: - Экспорт/Импорт
    func exportBackup() -> URL? {
        print("Starting export for all sections")

        let payload = BackupPayload(
            words: words,
            irregularVerbs: irregularVerbs,
            imageNotes: imageNotes,
            notesTables: notesTables,
            testItems: testItems,
            settings: BackupSettings(
                wordRepeatLimit: wordRepeatLimit,
                verbRepeatLimit: verbRepeatLimit
            ),
            version: "2.3",
            exportDate: Date()
        )

        return BackupService.shared.export(payload: payload)
    }
    
    func importBackup(from url: URL) -> Bool {
        print("Starting import from: \(url) for all sections")

        let result = BackupService.shared.importFile(at: url)
        
        switch result {
        case .payload(let payload):
            print("Decoded BackupPayload version: \(payload.version)")
            return apply(payload: payload)
            
        case .exportV1(let exportData):
            print("Decoded ExportDataV1 version: \(exportData.version)")
            return apply(exportData: exportData)
            
        case .legacy(let legacyData):
            print("Decoded LegacyExportData version: \(legacyData.version)")
            return apply(legacyData: legacyData)
            
        case .words(let importedWords):
            print("Decoded plain word array with \(importedWords.count) entries")
            let count = mergeWords(importedWords)
            print("Import completed: \(count) new words from array format")
            return count > 0
            
        case .text(let content):
            print("Trying to parse as text file")
            let parsedWords = BackupService.shared.parseText(content)
            let importedCount = mergeWords(parsedWords)
            print("Text import completed: \(importedCount) new words")
            return importedCount > 0
            
        case .failure(let error):
            print("Import error: \(error)")
            print("Error details: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Apply Methods

    private func apply(payload: BackupPayload) -> Bool {
        print("Applying BackupPayload with \(payload.words.count) words, \(payload.irregularVerbs.count) verbs, \(payload.imageNotes.count) imageNotes, \(payload.notesTables.count) notesTables")

        let importedWords = mergeWords(payload.words)
        let importedVerbs = mergeVerbs(payload.irregularVerbs)
        let importedImageNotes = mergeImageNotes(payload.imageNotes)
        let importedNotesTables = mergeNotesTables(payload.notesTables)
        let importedTestItems = mergeTestItems(payload.testItems)

        let settings = payload.settings
        wordRepeatLimit = settings.wordRepeatLimit
        verbRepeatLimit = settings.verbRepeatLimit

        removeCompletedWords(countAsLearned: false)
        removeCompletedVerbs(countAsLearned: false)

        print("Payload import summary: +\(importedWords) words, +\(importedVerbs) verbs, +\(importedImageNotes) imageNotes, +\(importedNotesTables) notesTables, +\(importedTestItems) testItems")

        // Payload was valid — import is always considered successful
        return true
    }

    private func apply(exportData: ExportDataV1) -> Bool {
        print("Applying ExportDataV1 with \(exportData.words.count) words and \(exportData.irregularVerbs.count) verbs")

        let importedWords = mergeWords(exportData.words)
        let importedVerbs = mergeVerbs(exportData.irregularVerbs)

        var settingsChanged = false
        if let newLimit = exportData.settings["repeatLimit"] {
            settingsChanged = newLimit != wordRepeatLimit || newLimit != verbRepeatLimit
            wordRepeatLimit = newLimit
            verbRepeatLimit = newLimit
            removeCompletedWords(countAsLearned: false)
            removeCompletedVerbs(countAsLearned: false)
            print("Settings updated from ExportDataV1: repeatLimit = \(newLimit)")
        }

        return (importedWords + importedVerbs) > 0 || settingsChanged
    }

    private func apply(legacyData: LegacyExportData) -> Bool {
        print("Applying LegacyExportData with \(legacyData.words.count) words")

        let importedWords = mergeWords(legacyData.words)

        var settingsChanged = false
        if let newLimit = legacyData.settings["repeatLimit"] {
            settingsChanged = newLimit != wordRepeatLimit || newLimit != verbRepeatLimit
            wordRepeatLimit = newLimit
            verbRepeatLimit = newLimit
            removeCompletedWords(countAsLearned: false)
            removeCompletedVerbs(countAsLearned: false)
            print("Settings updated from LegacyExportData: repeatLimit = \(newLimit)")
        }

        return importedWords > 0 || settingsChanged
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

    private func mergeTestItems(_ imported: [TestItem]) -> Int {
        var added = 0
        for item in imported {
            let exists = testItems.contains {
                $0.title.normalizedCompareKey == item.title.normalizedCompareKey &&
                $0.type == item.type
            }
            if !exists {
                testItems.append(item)
                added += 1
            }
        }
        return added
    }

    private func recordDailyProgress(category: String) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        let defaults = UserDefaults.standard

        // Per-category tracking (used for calendar coloring)
        let catKey = "progressDays_\(category)"
        let catRaw = defaults.string(forKey: catKey) ?? ""
        var catSet = Set(catRaw.split(separator: ",").map { String($0) })
        if !catSet.contains(todayKey) {
            catSet.insert(todayKey)
            defaults.set(Array(catSet).sorted().joined(separator: ","), forKey: catKey)
        }

        // Combined key — used for streak count (any practice = day counts)
        let raw = defaults.string(forKey: "progressDays") ?? ""
        var set = Set(raw.split(separator: ",").map { String($0) })
        if !set.contains(todayKey) {
            set.insert(todayKey)
            defaults.set(Array(set).sorted().joined(separator: ","), forKey: "progressDays")
        }
    }

    // MARK: - Persistence
    
    private func save<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Save error for key \(key): \(error)")
        }
    }

    private func saveWords() {
        save(words, key: "words")
    }
    
    private func saveIrregularVerbs() {
        save(irregularVerbs, key: "irregularVerbs")
    }

    private func saveNotes() {
        save(notesTables, key: "notesTables")
    }
    
    private func saveImageNotes() {
        save(imageNotes, key: "imageNotes")
    }

    private func saveTestItems() {
        save(testItems, key: "testItems")
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
    
    private func load<T: Decodable>(key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Load error for key \(key): \(error)")
            return nil
        }
    }

    private func load() {
        if let loadedWords = load(key: "words", type: [Word].self) {
            words = loadedWords
        }
        
        if let loadedVerbs = load(key: "irregularVerbs", type: [IrregularVerb].self) {
            irregularVerbs = loadedVerbs
        }

        if let loadedImageNotes = load(key: "imageNotes", type: [ImageNote].self) {
            imageNotes = loadedImageNotes
        }

        if let loadedTestItems = load(key: "testItems", type: [TestItem].self) {
            testItems = loadedTestItems
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
    }
}
