import Foundation

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
    
    enum CodingKeys: String, CodingKey {
        case id, title, headers, rows, footer
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        headers = try container.decodeIfPresent([String].self, forKey: .headers) ?? []
        rows = try container.decodeIfPresent([[String]].self, forKey: .rows) ?? []
        footer = try container.decodeIfPresent([String].self, forKey: .footer) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(headers, forKey: .headers)
        try container.encode(rows, forKey: .rows)
        try container.encode(footer, forKey: .footer)
    }
}
