import SwiftUI

/// Sheet for creating a new task (`task == nil`) or editing an existing one.
struct AddEditTaskView: View {
    @Environment(TaskViewModel.self) private var taskViewModel
    @Environment(\.dismiss) private var dismiss

    private let task: TodoTask?

    @State private var title: String
    @State private var description: String
    @State private var isCompleted: Bool
    @State private var hasEditedTitle = false
    @FocusState private var titleFocused: Bool

    init(task: TodoTask? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _isCompleted = State(initialValue: task?.isCompleted ?? false)
    }

    private var isEditing: Bool { task != nil }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleTooLong: Bool { trimmedTitle.count > TodoTask.maxTitleLength }

    private var descriptionTooLong: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines).count > TodoTask.maxDescriptionLength
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty && !titleTooLong && !descriptionTooLong
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onChange(of: title) { hasEditedTitle = true }
                } header: {
                    Text("Title")
                } footer: {
                    if hasEditedTitle && trimmedTitle.isEmpty {
                        Text("Title is required.").foregroundStyle(.red)
                    } else if titleTooLong {
                        Text("Title can be at most \(TodoTask.maxTitleLength) characters.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Optional details", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Description")
                } footer: {
                    if descriptionTooLong {
                        Text("Description can be at most \(TodoTask.maxDescriptionLength) characters.")
                            .foregroundStyle(.red)
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Completed", isOn: $isCompleted)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: save)
                        .bold()
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if !isEditing { titleFocused = true }
            }
        }
        // Avoid losing typed text to an accidental swipe-down.
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        title != (task?.title ?? "")
            || description != (task?.description ?? "")
            || isCompleted != (task?.isCompleted ?? false)
    }

    private func save() {
        guard isValid else { return }

        if var task {
            task.title = trimmedTitle
            task.description = description
            task.isCompleted = isCompleted
            taskViewModel.updateTask(task)
        } else {
            taskViewModel.addTask(title: trimmedTitle, description: description)
        }
        dismiss()
    }
}

#Preview("Add") {
    AddEditTaskView()
        .environment(TaskViewModel())
}

#Preview("Edit") {
    AddEditTaskView(task: TodoTask(id: "preview", title: "Buy milk", description: "2 litres"))
        .environment(TaskViewModel())
}
