import SwiftUI

/// Home screen: tap the jar to draw a random incomplete task.
struct JarView: View {
    @Environment(TaskViewModel.self) private var taskViewModel

    /// ID of the drawn task. Looked up live so edits/deletes elsewhere are reflected.
    @State private var drawnTaskID: String?
    /// The previous draw, so the same task isn't drawn twice in a row.
    @State private var lastDrawnID: String?
    @State private var isDrawing = false
    /// Bumped on every draw to trigger the shake animation and haptic.
    @State private var drawCount = 0
    /// Bumped when a task is marked done, for the success haptic.
    @State private var doneCount = 0
    @State private var isAddingTask = false

    private var remaining: [TodoTask] { taskViewModel.incompleteTasks }

    private var drawnTask: TodoTask? {
        guard let drawnTaskID else { return nil }
        // Only show it while it still exists and is still incomplete.
        return remaining.first { $0.id == drawnTaskID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let drawnTask {
                    cardOverlay(for: drawnTask)
                }
            }
            .navigationTitle("Jar")
            .sheet(isPresented: $isAddingTask) {
                AddEditTaskView()
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: drawCount)
            .sensoryFeedback(.success, trigger: doneCount)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if taskViewModel.isLoading {
            ProgressView()
        } else {
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                jarButton
                caption
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var jarButton: some View {
        Button(action: draw) {
            JarGraphic(slipCount: remaining.count, isEmpty: remaining.isEmpty)
                .frame(maxWidth: 240)
                .keyframeAnimator(initialValue: 0.0, trigger: drawCount) { jar, angle in
                    jar.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-9, duration: 0.08)
                        CubicKeyframe(9, duration: 0.1)
                        CubicKeyframe(-7, duration: 0.1)
                        CubicKeyframe(5, duration: 0.08)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
        }
        .buttonStyle(JarButtonStyle())
        .disabled(remaining.isEmpty || isDrawing || drawnTask != nil)
        .accessibilityLabel("Draw a random task")
        .accessibilityHint(remaining.isEmpty ? "The jar is empty" : "\(remaining.count) tasks in the jar")
    }

    @ViewBuilder
    private var caption: some View {
        if remaining.isEmpty {
            VStack(spacing: 10) {
                if taskViewModel.tasks.isEmpty {
                    Text("Your jar is empty")
                        .font(.title3.bold())
                    Text("Drop a few tasks in and let the jar pick what's next.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("All done!")
                        .font(.title3.bold())
                    Text("You've cleared the jar. Enjoy the break, or add something new.")
                        .foregroundStyle(.secondary)
                }

                Button("Add Task", systemImage: "plus") { isAddingTask = true }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 6) {
                Text("Tap the jar to draw a task")
                    .font(.title3.bold())
                Text(remaining.count == 1 ? "1 task waiting" : "\(remaining.count) tasks waiting")
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: remaining.count)
            }
            .multilineTextAlignment(.center)
        }
    }

    private func cardOverlay(for task: TodoTask) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: putBack)
                .transition(.opacity)

            DrawnTaskCard(
                task: task,
                onDone: { markDone(task) },
                onPutBack: putBack
            )
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                )
            )
        }
        .zIndex(1)
    }

    // MARK: - Actions

    private func draw() {
        // Check the live task, not the ID: the drawn task may have been deleted or
        // completed from the All Tasks tab, which leaves a stale ID behind.
        guard !isDrawing, drawnTask == nil else { return }

        // Avoid drawing the same task twice in a row when there's a choice.
        var candidates = remaining
        if candidates.count > 1, let last = lastDrawnID {
            candidates.removeAll { $0.id == last }
        }
        guard let pick = candidates.randomElement(), let id = pick.id else { return }

        isDrawing = true
        drawCount += 1

        // Let the shake play before the card pops out.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                drawnTaskID = id
            }
            lastDrawnID = id
            isDrawing = false
        }
    }

    private func markDone(_ task: TodoTask) {
        taskViewModel.markComplete(task)
        doneCount += 1
        closeCard()
    }

    private func putBack() {
        closeCard()
    }

    private func closeCard() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            drawnTaskID = nil
        }
    }
}

/// Squishes the jar slightly while pressed.
private struct JarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    JarView()
        .environment(TaskViewModel())
}
