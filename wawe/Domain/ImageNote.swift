import Foundation

struct ImageNote: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var imageURL: String
    var descriptionMarkdown: String
    
    init(id: UUID = UUID(), title: String, imageURL: String, descriptionMarkdown: String = "") {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.descriptionMarkdown = descriptionMarkdown
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, imageURL, descriptionMarkdown
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        descriptionMarkdown = try container.decodeIfPresent(String.self, forKey: .descriptionMarkdown) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(descriptionMarkdown, forKey: .descriptionMarkdown)
    }
}
