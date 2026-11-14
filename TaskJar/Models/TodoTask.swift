import Foundation
import FirebaseFirestore

struct TodoTask: Identifiable, Codable, Equatable {
    /// Filled in automatically with the Firestore document ID when decoding.
    @DocumentID var id: String?
    var title: String
    var description: String
    var isCompleted: Bool
    /// Stored in Firestore as a Timestamp.
    var createdAt: Date

    /// Field limits, mirrored in `firestore.rules`.
    static let maxTitleLength = 200
    static let maxDescriptionLength = 2000

    init(
        id: String? = nil,
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, isCompleted, createdAt
    }

    /// Lenient decoding: optional fields fall back to defaults, so a document that is missing
    /// one (e.g. created by hand in the Firebase console) still shows up instead of being dropped.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
