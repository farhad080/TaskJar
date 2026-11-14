import Foundation
import Observation
import OSLog
import FirebaseFirestore

/// Reads and writes the signed-in user's tasks at `users/{uid}/tasks`.
@MainActor
@Observable
final class TaskViewModel {
    /// Tasks for the current user, newest first. Kept live by the snapshot listener.
    private(set) var tasks: [TodoTask] = []
    /// True until the first snapshot arrives after `startListening(uid:)`.
    private(set) var isLoading = false
    /// Set when a Firestore operation fails; the view presents it as an alert.
    var errorMessage: String?

    /// Tasks still in the jar.
    var incompleteTasks: [TodoTask] { tasks.filter { !$0.isCompleted } }

    // `nonisolated(unsafe)` so `deinit` (which is nonisolated) can remove the listener.
    @ObservationIgnored nonisolated(unsafe) private var listener: ListenerRegistration?
    @ObservationIgnored private var uid: String?

    private static let logger = Logger(subsystem: "com.taskjar.TaskJar", category: "Tasks")

    /// Resolved on use rather than at init, so creating the view model
    /// (e.g. in SwiftUI previews) doesn't require a configured FirebaseApp.
    private var db: Firestore { Firestore.firestore() }

    private var tasksCollection: CollectionReference? {
        guard let uid else { return nil }
        return db.collection("users").document(uid).collection("tasks")
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listening

    /// Starts the real-time listener for `uid`. No-op if it's already running for that user.
    func startListening(uid: String) {
        guard uid != self.uid || listener == nil else { return }
        stopListening()

        self.uid = uid
        isLoading = true
        attachListener(uid: uid)
    }

    /// Re-attaches the listener if it was terminated by an error (e.g. network or permissions).
    func retryIfNeeded() {
        guard let uid, listener == nil else { return }
        attachListener(uid: uid)
    }

    /// Removes the listener and clears local data. Call before/when the user signs out.
    func stopListening() {
        listener?.remove()
        listener = nil
        uid = nil
        tasks = []
        isLoading = false
        errorMessage = nil
    }

    private func attachListener(uid: String) {
        listener = db.collection("users").document(uid).collection("tasks")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                // Firestore delivers snapshot callbacks on the main queue.
                MainActor.assumeIsolated {
                    // Ignore late callbacks for a user who has since signed out.
                    guard let self, self.uid == uid else { return }
                    self.isLoading = false

                    if let error {
                        // Firestore ends a listener after an error. Drop the dead registration
                        // so `retryIfNeeded()` can attach a fresh one.
                        self.listener?.remove()
                        self.listener = nil
                        Self.logger.error("Tasks listener failed: \(error.localizedDescription)")
                        self.errorMessage = Self.message(for: error)
                        return
                    }
                    guard let snapshot else { return }

                    self.tasks = snapshot.documents.compactMap { (document) -> TodoTask? in
                        do {
                            return try document.data(as: TodoTask.self)
                        } catch {
                            Self.logger.error("Skipping malformed task \(document.documentID): \(error.localizedDescription)")
                            return nil
                        }
                    }
                }
            }
    }

    // MARK: - CRUD

    func addTask(title: String, description: String = "") {
        guard let tasksCollection else { return reportNotSignedIn() }
        guard let fields = validated(title: title, description: description) else { return }

        let task = TodoTask(title: fields.title, description: fields.description)
        do {
            // Fire-and-forget: the snapshot listener shows the task immediately (latency
            // compensation), and the completion only reports a server-side failure.
            _ = try tasksCollection.addDocument(from: task, completion: handleWriteResult)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func updateTask(_ task: TodoTask) {
        guard let id = task.id else { return }
        guard let tasksCollection else { return reportNotSignedIn() }
        guard let fields = validated(title: task.title, description: task.description) else { return }

        // `updateData` (not `setData(merge:)`) so editing a task that was deleted meanwhile
        // fails with "not found" instead of silently re-creating it. `createdAt` is left as is.
        tasksCollection.document(id).updateData(
            [
                "title": fields.title,
                "description": fields.description,
                "isCompleted": task.isCompleted
            ],
            completion: handleWriteResult
        )
    }

    func toggleComplete(_ task: TodoTask) {
        setCompleted(task, to: !task.isCompleted)
    }

    /// Marks a task done (idempotent, unlike `toggleComplete`).
    func markComplete(_ task: TodoTask) {
        setCompleted(task, to: true)
    }

    private func setCompleted(_ task: TodoTask, to isCompleted: Bool) {
        guard let id = task.id else { return }
        guard let tasksCollection else { return reportNotSignedIn() }

        tasksCollection.document(id).updateData(
            ["isCompleted": isCompleted],
            completion: handleWriteResult
        )
    }

    func deleteTask(_ task: TodoTask) {
        guard let id = task.id else { return }
        guard let tasksCollection else { return reportNotSignedIn() }

        tasksCollection.document(id).delete(completion: handleWriteResult)
    }

    // MARK: - Helpers

    /// Trims and checks fields against the same limits the security rules enforce.
    private func validated(title: String, description: String) -> (title: String, description: String)? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            errorMessage = "Task title can't be empty."
            return nil
        }
        if title.count > TodoTask.maxTitleLength {
            errorMessage = "Title can be at most \(TodoTask.maxTitleLength) characters."
            return nil
        }
        if description.count > TodoTask.maxDescriptionLength {
            errorMessage = "Description can be at most \(TodoTask.maxDescriptionLength) characters."
            return nil
        }
        return (title, description)
    }

    /// Completion for Firestore writes: surfaces a failure as an alert.
    private var handleWriteResult: (Error?) -> Void {
        { [weak self] error in
            guard let error else { return }
            // Firestore write completions are delivered on the main queue.
            MainActor.assumeIsolated {
                Self.logger.error("Task write failed: \(error.localizedDescription)")
                self?.errorMessage = Self.message(for: error)
            }
        }
    }

    private func reportNotSignedIn() {
        errorMessage = "You need to be signed in to change tasks."
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain,
              let code = FirestoreErrorCode.Code(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .permissionDenied, .unauthenticated:
            return "You don't have access to these tasks. Try signing out and back in."
        case .notFound:
            return "That task no longer exists."
        case .unavailable, .deadlineExceeded:
            return "Can't reach the server. Your changes will sync when you're back online."
        case .resourceExhausted:
            return "Too many requests right now. Please try again shortly."
        case .invalidArgument, .failedPrecondition:
            return "That change couldn't be saved. Please check the task and try again."
        default:
            return error.localizedDescription
        }
    }
}
