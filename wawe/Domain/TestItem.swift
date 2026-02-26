import Foundation

// MARK: - Domain Model

struct TestItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var type: TestType
    var rawContent: String
    var createdAt: Date

    init(title: String, type: TestType, rawContent: String) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.rawContent = rawContent
        self.createdAt = Date()
    }

    enum TestType: String, Codable, CaseIterable {
        case chooseCorrect = "chooseCorrect"
        case fillInBlanks  = "fillInBlanks"

        var displayName: String {
            switch self {
            case .chooseCorrect: return "Выбери верное"
            case .fillInBlanks:  return "Заполни пропуски"
            }
        }
    }
}

// MARK: - Choose Correct

struct ChoiceItem: Identifiable {
    let id: UUID
    let text: String
    let isCorrect: Bool

    init(text: String, isCorrect: Bool) {
        self.id = UUID()
        self.text = text
        self.isCorrect = isCorrect
    }
}

/// One question: one correct answer + its incorrect alternatives
struct ChoiceGroup: Identifiable {
    let id: UUID
    let items: [ChoiceItem]  // contains exactly 1 correct + N incorrect

    init(items: [ChoiceItem]) {
        self.id = UUID()
        self.items = items
    }
}

extension TestItem {
    /// Parses rawContent into sequential question groups.
    /// Each "+" line starts a new group; following "*" lines are alternatives for that group.
    /// First plain line (no marker) becomes the instruction.
    static func parseChooseCorrectGroups(_ raw: String) -> (instruction: String, groups: [ChoiceGroup]) {
        var instruction = ""
        var groups: [ChoiceGroup] = []
        var currentCorrect: ChoiceItem? = nil
        var currentIncorrect: [ChoiceItem] = []

        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }

            if t.hasPrefix("+") {
                if let correct = currentCorrect {
                    groups.append(ChoiceGroup(items: [correct] + currentIncorrect))
                    currentIncorrect = []
                }
                let text = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { currentCorrect = ChoiceItem(text: text, isCorrect: true) }
            } else if t.hasPrefix("*") {
                let text = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { currentIncorrect.append(ChoiceItem(text: text, isCorrect: false)) }
            } else if instruction.isEmpty {
                instruction = t
            }
        }

        if let correct = currentCorrect {
            groups.append(ChoiceGroup(items: [correct] + currentIncorrect))
        }

        return (instruction, groups)
    }
}

// MARK: - Fill in Blanks

struct BlankItem: Identifiable {
    let id: UUID
    let answer: String
    let hint: String

    init(answer: String, hint: String) {
        self.id = UUID()
        self.answer = answer
        self.hint = hint
    }
}

enum BlankSegment {
    case text(String)
    case blank(BlankItem)
}

struct BlankSentence: Identifiable {
    let id: UUID
    let segments: [BlankSegment]

    init(segments: [BlankSegment]) {
        self.id = UUID()
        self.segments = segments
    }
}

extension TestItem {
    /// Parses rawContent for "Fill in Blanks" type.
    /// First non-empty line without "*" becomes the instruction.
    /// *answer* marks the expected answer; (hint) is the placeholder.
    static func parseFillInBlanks(_ raw: String) -> (instruction: String, sentences: [BlankSentence]) {
        var instruction = ""
        var sentences: [BlankSentence] = []
        var foundInstruction = false

        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }

            if !foundInstruction && !t.contains("*") {
                instruction = t
                foundInstruction = true
                continue
            }
            foundInstruction = true
            if t.contains("*") {
                let sentence = parseFillSentence(t)
                if !sentence.segments.isEmpty {
                    sentences.append(sentence)
                }
            }
        }

        return (instruction, sentences)
    }

    static func parseFillSentence(_ line: String) -> BlankSentence {
        var segments: [BlankSegment] = []
        var remaining = line

        while !remaining.isEmpty {
            if let starStart = remaining.firstIndex(of: "*") {
                // Text before the blank
                let before = String(remaining[remaining.startIndex..<starStart])
                if !before.isEmpty { segments.append(.text(before)) }

                let afterFirst = remaining.index(after: starStart)
                guard afterFirst < remaining.endIndex else { break }

                if let starEnd = remaining[afterFirst...].firstIndex(of: "*") {
                    let answer = String(remaining[afterFirst..<starEnd])
                    let afterSecond = remaining.index(after: starEnd)
                    remaining = afterSecond < remaining.endIndex
                        ? String(remaining[afterSecond...])
                        : ""

                    // Look for (hint) immediately after the blank
                    var hint = ""
                    let stripped = remaining.trimmingCharacters(in: .init(charactersIn: " "))
                    if stripped.hasPrefix("("), let parenEnd = stripped.firstIndex(of: ")") {
                        hint = String(stripped[stripped.index(after: stripped.startIndex)..<parenEnd])
                        if let hintRange = remaining.range(of: "(\(hint))") {
                            remaining = String(remaining[hintRange.upperBound...])
                        }
                    }

                    segments.append(.blank(BlankItem(answer: answer, hint: hint)))
                } else {
                    // No closing star – treat the rest as plain text
                    segments.append(.text(String(remaining[starStart...])))
                    break
                }
            } else {
                segments.append(.text(remaining))
                break
            }
        }

        return BlankSentence(segments: segments)
    }
}
