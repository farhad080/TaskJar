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
  - Tap the circle to mark a task complete; swipe left to delete
  - The listener is removed on sign out, and the local task list is cleared

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
    ├── RootView.swift          # Login when signed out, TaskListView when signed in
    ├── TaskListView.swift      # Main screen: live task list, toggle, swipe-to-delete, sign out
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
