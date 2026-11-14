import SwiftUI

/// The card showing the task drawn from the jar.
struct DrawnTaskCard: View {
    let task: TodoTask
    let onDone: () -> Void
    let onPutBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Label("You drew", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                Text(task.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if !task.description.isEmpty {
                    ScrollView {
                        Text(task.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 160)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                Button(action: onPutBack) {
                    Label("Put back", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .padding(.horizontal, 24)
    }
}

#Preview {
    DrawnTaskCard(
        task: TodoTask(id: "1", title: "Water the plants", description: "The ones on the balcony too."),
        onDone: {},
        onPutBack: {}
    )
}
