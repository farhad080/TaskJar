import Foundation
import Observation

@MainActor
@Observable
final class TaskListViewModel {
    var tasks: [TodoTask] = []
    var errorMessage: String?
}
