import Foundation
import Observation
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

    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var uid: String?

    private var tasksCollection: CollectionReference? {
        guard let uid else { return nil }
        return db.collection("users").document(uid).collection("tasks")
    }

    // MARK: - Listening

    /// Starts the real-time listener for `uid`. Safe to call repeatedly; it's a no-op for the same user.
    func startListening(uid: String) {
        guard uid != self.uid || listener == nil else { return }
        stopListening()

        self.uid = uid
        isLoading = true

        listener = db.collection("users").document(uid).collection("tasks")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                // Firestore delivers snapshot callbacks on the main queue.
                MainActor.assumeIsolated {
                    guard let self, self.uid == uid else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let snapshot else { return }

                    self.tasks = snapshot.documents.compactMap { document in
                        try? document.data(as: TodoTask.self)
                    }
                }
            }
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

    // MARK: - CRUD

    func addTask(title: String, description: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Task title can't be empty."
            return
        }
        guard let tasksCollection else { return reportNotSignedIn() }

        let task = TodoTask(
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            // Fire-and-forget: the snapshot listener shows the task immediately (latency
            // compensation), and the completion only reports a server-side failure.
            _ = try tasksCollection.addDocument(from: task, completion: handleWriteResult)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ task: TodoTask) {
        guard let id = task.id else { return }
        guard let tasksCollection else { return reportNotSignedIn() }

        var updated = task
        updated.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.description = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.title.isEmpty else {
            errorMessage = "Task title can't be empty."
            return
        }

        do {
            try tasksCollection.document(id).setData(from: updated, merge: true, completion: handleWriteResult)
        } catch {
            errorMessage = error.localizedDescription
        }
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

    /// Completion for Firestore writes: surfaces a failure as an alert.
    private var handleWriteResult: (Error?) -> Void {
        { [weak self] error in
            guard let error else { return }
            // Firestore write completions are delivered on the main queue.
            MainActor.assumeIsolated {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func reportNotSignedIn() {
        errorMessage = "You need to be signed in to change tasks."
    }
}
