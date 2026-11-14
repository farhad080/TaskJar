import SwiftUI

struct TaskListView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(TaskViewModel.self) private var taskViewModel

    @State private var activeSheet: TaskSheet?

    /// Which form the add/edit sheet shows.
    private enum TaskSheet: Identifiable {
        case add
        case edit(TodoTask)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let task): "edit-\(task.id ?? "")"
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("TaskJar")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Sign Out", role: .destructive, action: signOut)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            activeSheet = .add
                        } label: {
                            Label("Add Task", systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .add:
                        AddEditTaskView()
                    case .edit(let task):
                        AddEditTaskView(task: task)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if taskViewModel.isLoading {
            ProgressView()
        } else if taskViewModel.tasks.isEmpty {
            ContentUnavailableView {
                Label("No Tasks Yet", systemImage: "checklist")
            } description: {
                Text("Your jar is empty. Add your first task to get started.")
            } actions: {
                Button("Add Task") { activeSheet = .add }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List(taskViewModel.tasks) { task in
                TaskRow(
                    task: task,
                    onToggle: { taskViewModel.toggleComplete(task) },
                    onEdit: { activeSheet = .edit(task) }
                )
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        taskViewModel.deleteTask(task)
                    }
                }
            }
            // The snapshot listener keeps data live; this only reconnects it after an error.
            .refreshable { taskViewModel.retryIfNeeded() }
        }
    }

    private func signOut() {
        // Detach the Firestore listener before the auth session ends.
        taskViewModel.stopListening()
        auth.signOut()
        // If sign-out failed, the user is still signed in: resume listening.
        if let uid = auth.user?.uid {
            taskViewModel.startListening(uid: uid)
        }
    }
}

/// One task: a done-state toggle on the left, tap anywhere else to edit.
private struct TaskRow: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            // Borderless keeps this tap separate from the row's edit tap.
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityAction(named: "Edit", onEdit)
    }
}

#Preview {
    TaskListView()
        .environment(AuthViewModel())
        .environment(TaskViewModel())
}
