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
4. Open `TaskJar.xcodeproj` and run.

## Features

- **Email/password authentication**
  - Sign up, sign in and sign out with FirebaseAuth
  - Signed-in state is tracked by an auth state listener, so the session persists across launches
  - Form validation (email format, minimum 6-character password, matching confirmation)
  - Loading indicator while requests run, and alerts with readable error messages
- **Task list**, shown once signed in (Firestore model in place)

## Project structure

```
TaskJar/
├── TaskJarApp.swift            # App entry; configures Firebase, shows RootView
├── Models/
│   └── TodoTask.swift          # Firestore-codable task model
├── ViewModels/
│   ├── AuthViewModel.swift     # signUp / signIn / signOut + auth state listener
│   └── TaskListViewModel.swift
└── Views/
    ├── RootView.swift          # Login when signed out, TaskListView when signed in
    ├── TaskListView.swift      # Main screen (sign-out in the toolbar menu)
    └── Auth/
        ├── LoginView.swift
        ├── SignUpView.swift
        └── AuthErrorAlert.swift  # Shared error alert modifier
```

## Architecture

MVVM using the Observation framework (`@Observable`). `RootView` owns a single
`AuthViewModel` and injects it into the environment; views read it with
`@Environment(AuthViewModel.self)`.
