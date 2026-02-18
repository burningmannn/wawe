import Foundation

protocol LearnableItem: Identifiable, Codable, Equatable {
    var id: UUID { get }
    var correctCount: Int { get set }
    var comparisonKey: String { get }
}
