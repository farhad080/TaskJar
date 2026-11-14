import SwiftUI

struct TaskListView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(TaskViewModel.self) private var taskViewModel

    var body: some View {
        NavigationStack {
            Group {
                if taskViewModel.isLoading {
                    ProgressView()
                } else if taskViewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Your jar is empty.")
                    )
                } else {
                    List(taskViewModel.tasks) { task in
                        HStack(spacing: 12) {
                            Button {
                                taskViewModel.toggleComplete(task)
                            } label: {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                if !task.description.isEmpty {
                                    Text(task.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                taskViewModel.deleteTask(task)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TaskJar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let email = auth.user?.email {
                            Text(email)
                        }
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            // Detach the Firestore listener before the auth session ends.
                            taskViewModel.stopListening()
                            auth.signOut()
                            // If sign-out failed, the user is still signed in: resume listening.
                            if let uid = auth.user?.uid {
                                taskViewModel.startListening(uid: uid)
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .authErrorAlert(auth)
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { taskViewModel.errorMessage != nil },
                    set: { if !$0 { taskViewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(taskViewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    TaskListView()
        .environment(AuthViewModel())
        .environment(TaskViewModel())
}
