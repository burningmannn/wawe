import Foundation
import SwiftUI

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
    var imageNotes: [ImageNote]
    var notesTables: [FlexNoteTable]
    var testItems: [TestItem]
    var settings: BackupSettings
    var version: String
    var exportDate: Date

    init(words: [Word],
         irregularVerbs: [IrregularVerb],
         questions: [QuestionItem],
         imageNotes: [ImageNote],
         notesTables: [FlexNoteTable],
         testItems: [TestItem] = [],
         settings: BackupSettings,
         version: String,
         exportDate: Date) {
        self.words = words
        self.irregularVerbs = irregularVerbs
        self.questions = questions
        self.imageNotes = imageNotes
        self.notesTables = notesTables
        self.testItems = testItems
        self.settings = settings
        self.version = version
        self.exportDate = exportDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        words = (try? container.decode([Word].self, forKey: .words)) ?? []
        irregularVerbs = (try? container.decode([IrregularVerb].self, forKey: .irregularVerbs)) ?? []
        questions = (try? container.decode([QuestionItem].self, forKey: .questions)) ?? []
        imageNotes = (try? container.decode([ImageNote].self, forKey: .imageNotes)) ?? []
        notesTables = (try? container.decode([FlexNoteTable].self, forKey: .notesTables)) ?? []
        testItems = (try? container.decode([TestItem].self, forKey: .testItems)) ?? []
        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings) ?? BackupSettings()
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
    }
}

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

enum ImportResult {
    case payload(BackupPayload)
    case exportV1(ExportDataV1)
    case legacy(LegacyExportData)
    case words([Word])
    case text(String)
    case failure(Error)
}

final class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    func export(payload: BackupPayload) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            print("Encoded data size: \(data.count) bytes")

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
            return nil
        }
    }
    
    func importFile(at url: URL) -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            let decoder = JSONDecoder()
            
            if let payload = try? decoder.decode(BackupPayload.self, from: data) {
                return .payload(payload)
            }
            if let exportData = try? decoder.decode(ExportDataV1.self, from: data) {
                return .exportV1(exportData)
            }
            if let legacyData = try? decoder.decode(LegacyExportData.self, from: data) {
                return .legacy(legacyData)
            }
            if let importedWords = try? decoder.decode([Word].self, from: data) {
                return .words(importedWords)
            }
            if let content = String(data: data, encoding: .utf8) {
                return .text(content)
            }
            
            return .failure(NSError(domain: "BackupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported import format"]))
        } catch {
            return .failure(error)
        }
    }
    
    func parseText(_ content: String) -> [Word] {
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
            }
        }
        return parsedWords
    }
}
