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
}
