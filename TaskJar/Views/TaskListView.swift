import SwiftUI

struct TaskListView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = TaskListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Your jar is empty.")
                    )
                } else {
                    List(viewModel.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .strikethrough(task.isCompleted)
                            if !task.description.isEmpty {
                                Text(task.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                            auth.signOut()
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .authErrorAlert(auth)
        }
    }
}

#Preview {
    TaskListView()
        .environment(AuthViewModel())
}
