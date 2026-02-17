import Foundation

struct BackupSettings: Codable {
    var wordRepeatLimit: Int
    var verbRepeatLimit: Int
    var questionRepeatLimit: Int
    var profileBadges: String?

    init(wordRepeatLimit: Int = 30,
         verbRepeatLimit: Int = 30,
         questionRepeatLimit: Int = 30,
         profileBadges: String? = nil) {
        self.wordRepeatLimit = wordRepeatLimit
        self.verbRepeatLimit = verbRepeatLimit
        self.questionRepeatLimit = questionRepeatLimit
        self.profileBadges = profileBadges
    }
}

struct BackupPayload: Codable {
    var words: [Word]
    var irregularVerbs: [IrregularVerb]
    var questions: [QuestionItem]
    var imageNotes: [ImageNote]
    var notesTables: [FlexNoteTable]
    var settings: BackupSettings
    var version: String
    var exportDate: Date

    init(words: [Word],
         irregularVerbs: [IrregularVerb],
         questions: [QuestionItem],
         imageNotes: [ImageNote],
         notesTables: [FlexNoteTable],
         settings: BackupSettings,
         version: String,
         exportDate: Date) {
        self.words = words
        self.irregularVerbs = irregularVerbs
        self.questions = questions
        self.imageNotes = imageNotes
        self.notesTables = notesTables
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
