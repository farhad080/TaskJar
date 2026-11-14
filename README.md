# TaskJar

A SwiftUI to-do app backed by Firebase (Auth + Firestore).

## Requirements

- Xcode 16+
- iOS 17.0+
- Firebase iOS SDK 12.x (added via Swift Package Manager: `FirebaseAuth`, `FirebaseFirestore`)

## Setup

1. Create a Firebase project and add an iOS app with this target's bundle identifier.
2. Download `GoogleService-Info.plist` and add it to the `TaskJar/` folder.
   It is git-ignored, so each developer needs their own copy.
3. In the Firebase console, go to **Authentication → Sign-in method** and enable **Email/Password**.
4. Create a **Cloud Firestore** database and publish security rules that limit each user to their own tasks:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid}/tasks/{taskId} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```
5. Open `TaskJar.xcodeproj` and run.

## Features

- **Email/password authentication**
  - Sign up, sign in and sign out with FirebaseAuth
  - Signed-in state is tracked by an auth state listener, so the session persists across launches
  - Form validation (email format, minimum 6-character password, matching confirmation)
  - Loading indicator while requests run, and alerts with readable error messages
- **Tasks in Cloud Firestore**, private to each user
  - Live updates through a snapshot listener, newest first (sorted by `createdAt`)
  - Add, update, toggle complete and delete
  - The listener is removed on sign out, and the local task list is cleared
- **Two tabs** once signed in: **Jar** (the home screen) and **All Tasks**
- **Jar (home screen)**
  - A large animated jar holds one paper slip per incomplete task
  - Tap the jar: it shakes, then shows one random incomplete task on a card
    (it avoids drawing the same task twice in a row)
  - **Done** marks the task complete; **Put back** closes the card and leaves the task in the jar
  - Friendly messages when the jar is empty (no tasks yet, or everything is done), with an **Add Task** button
  - Haptics when drawing and when completing a task
- **All Tasks screen**
  - Each row shows the task's title, description and done state
  - Tap the circle to mark a task done; tap the rest of the row to edit it; swipe left to delete
  - **+** opens the add/edit sheet; the title is required, the description is optional,
    and editing also offers a Completed toggle
  - An empty state with an **Add Task** button when there are no tasks
  - A **Sign Out** button in the navigation bar

## Data model

Tasks are stored at `users/{uid}/tasks/{taskId}`:

| Field         | Type      | Notes                          |
|---------------|-----------|--------------------------------|
| `title`       | string    | Required, trimmed              |
| `description` | string    | Optional, defaults to `""`     |
| `isCompleted` | bool      | Defaults to `false`            |
| `createdAt`   | timestamp | Set when the task is created; used for sorting |

The document ID becomes `TodoTask.id` (`@DocumentID`).

## Project structure

```
TaskJar/
├── TaskJarApp.swift            # App entry; configures Firebase, shows RootView
├── Models/
│   └── TodoTask.swift          # Firestore-codable task model
├── ViewModels/
│   ├── AuthViewModel.swift     # signUp / signIn / signOut + auth state listener
│   └── TaskViewModel.swift     # Firestore CRUD + real-time listener for users/{uid}/tasks
└── Views/
    ├── RootView.swift          # Login when signed out, MainTabView when signed in
    ├── MainTabView.swift       # Jar + All Tasks tabs; shows Firestore error alerts
    ├── TaskListView.swift      # All Tasks: task rows, tap to edit, swipe to delete, +, sign out
    ├── AddEditTaskView.swift   # Sheet for creating or editing a task (title required)
    ├── Jar/
    │   ├── JarView.swift       # Home screen: draw a random incomplete task
    │   ├── JarGraphic.swift    # Jar drawn as a SwiftUI shape, filled with task slips
    │   └── DrawnTaskCard.swift # Card with Done / Put back
    └── Auth/
        ├── LoginView.swift
        ├── SignUpView.swift
        └── AuthErrorAlert.swift  # Shared error alert modifier
```

## Architecture

MVVM using the Observation framework (`@Observable`). `RootView` owns one
`AuthViewModel` and one `TaskViewModel` and puts both in the environment; views read them with
`@Environment(AuthViewModel.self)` / `@Environment(TaskViewModel.self)`.

`RootView` watches the signed-in user's `uid`. It calls `TaskViewModel.startListening(uid:)` when a
user signs in and `stopListening()` when the session ends. The Sign Out button also stops the
listener before signing out, so the listener never runs without an authenticated user.

Writes are fire-and-forget. Firestore's latency compensation shows changes right away (including
offline), and write completions only report server-side errors.
