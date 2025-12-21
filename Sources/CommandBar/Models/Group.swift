import Foundation

struct Group: Identifiable, Codable {
    var id = UUID()
    var name: String
    var color: String  // "blue", "red", "green", "orange", "purple", "gray"
    var order: Int
    var createdAt: Date = Date()
}
