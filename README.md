# TaskJar

A SwiftUI to-do app backed by Firebase. You drop tasks into a jar, tap the jar, and it picks
a random one for you to do next.

## Requirements

- Xcode 16 or later
- iOS 17.0 or later
- A Firebase project (the free Spark plan is enough)
- Firebase iOS SDK 12.x. It is already added to the project via Swift Package Manager
  (`FirebaseAuth`, `FirebaseFirestore`), and Xcode downloads it on first open.
- Optional: [Firebase CLI](https://firebase.google.com/docs/cli) to deploy the security rules from the terminal

## Firebase setup

### 1. Create the Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com) and click **Add project**.
2. Pick a name. Google Analytics is optional; the app doesn't use it.

### 2. Register the iOS app

1. In the project overview, click **Add app → iOS**.
2. Enter the bundle ID **`com.taskjar.TaskJar`**.
   If you use your own bundle ID, change it in Xcode as well
   (**TaskJar target → Signing & Capabilities → Bundle Identifier**). The two must match.
3. Download **`GoogleService-Info.plist`**.
4. Put it in the `TaskJar/` source folder, next to `TaskJarApp.swift`. The project uses a
   synchronized folder, so Xcode picks it up automatically. Check that the file is ticked for
   the **TaskJar** target in the File inspector.
5. Skip the console steps "Add Firebase SDK" and "Add initialization code". The package is
   already added, and `TaskJarApp` already calls `FirebaseApp.configure()`.

> `GoogleService-Info.plist` is git-ignored. Each developer or environment needs its own copy.

### 3. Enable Email/Password sign-in

**Build → Authentication → Get started → Sign-in method → Email/Password → Enable → Save.**
(Leave "Email link (passwordless sign-in)" off.)

### 4. Create the Firestore database

**Build → Firestore Database → Create database.**
- Choose a location close to your users. It can't be changed later.
- Start in **production mode**. You'll replace the rules in the next step.

### 5. Deploy the security rules

The rules are in [`firestore.rules`](firestore.rules). A signed-in user can read and write only
documents under `users/{their uid}/tasks`, and every write must have the expected task shape.

**Option A: Firebase console**
Open **Firestore Database → Rules**, replace the contents with `firestore.rules`, and click **Publish**.

**Option B: Firebase CLI** (from the repo root; [`firebase.json`](firebase.json) points at the rules file)

```sh
npm install -g firebase-tools
firebase login
firebase use --add            # select your project
firebase deploy --only firestore:rules
```

No custom indexes are needed. The task list is ordered by the single field `createdAt`.

### 6. Run the app

1. Open `TaskJar.xcodeproj` and wait for the Swift packages to resolve.
2. Select your team under **Signing & Capabilities** (required for a physical device).
3. Run on a simulator or device. Create an account on the Sign Up screen.

## Security rules

What [`firestore.rules`](firestore.rules) allows on `users/{uid}/tasks/{taskId}`:

| Operation | Allowed when |
|-----------|--------------|
| read      | signed in and `request.auth.uid == uid` |
| create    | owner, and the document is a valid task |
| update    | owner, the document is still a valid task, and `createdAt` is unchanged |
| delete    | owner |

A valid task has only the fields below: a non-empty `title` (at most 200 characters), an
optional `description` (at most 2000), a boolean `isCompleted` and a timestamp `createdAt`.
Everything outside `users/{uid}/tasks` is denied.

To check the rules, use **Firestore → Rules → Rules Playground** in the console. For example,
simulate a `get` of `users/abc/tasks/x` while authenticated as `abc` (allowed) and as `xyz` (denied).

## Features

- **Email/password authentication**
  - Sign up, sign in and sign out with FirebaseAuth
  - An auth state listener tracks the signed-in user, so the session persists across launches
  - Form validation (email format, minimum 6-character password, matching confirmation)
  - Loading indicator while requests run, and readable error alerts
- **Tasks in Cloud Firestore**, private to each user
  - Live updates through a snapshot listener, newest first
  - Add, edit, toggle complete and delete
  - Works offline: changes show immediately and sync when the device is back online
  - The listener is removed on sign out, and local tasks are cleared
  - If an error ends the listener, it reconnects when the app returns to the foreground
    or when you pull to refresh on All Tasks
- **Two tabs** once signed in: **Jar** (the home screen) and **All Tasks**
- **Jar**
  - An animated jar holds one paper slip per incomplete task
  - Tap the jar: it shakes, then shows one random incomplete task on a card
    (never the same task twice in a row when there's a choice)
  - **Done** marks the task complete; **Put back** closes the card
  - Friendly messages when the jar is empty or everything is done, with an **Add Task** button
  - Haptics when drawing and when completing a task
- **All Tasks**
  - Each row shows the title, description and done state
  - Tap the circle to mark a task done, tap the row to edit it, swipe left to delete
  - **+** opens the add/edit sheet (title required, length limits match the security rules)
  - Empty state with an **Add Task** button, and a **Sign Out** button

## Data model

Tasks are stored at `users/{uid}/tasks/{taskId}`:

| Field         | Type      | Notes |
|---------------|-----------|-------|
| `title`       | string    | Required, trimmed, 1–200 characters |
| `description` | string    | Optional, at most 2000 characters, defaults to `""` |
| `isCompleted` | bool      | Defaults to `false` |
| `createdAt`   | timestamp | Set on creation and never changed; used for sorting |

The document ID becomes `TodoTask.id` (`@DocumentID`). Decoding is lenient: a document missing
`description` or `isCompleted`, such as one added by hand in the console, still loads with defaults.
A document that has no `createdAt` field is left out of the list, because Firestore skips
documents without the field used in `order(by:)`.

## Project structure

```
TaskJar/
├── TaskJarApp.swift            # App entry; configures Firebase, shows RootView
├── Assets.xcassets/            # App icon (placeholder) and accent color
├── Models/
│   └── TodoTask.swift          # Firestore-codable task model + field limits
├── ViewModels/
│   ├── AuthViewModel.swift     # signUp / signIn / signOut + auth state listener
│   └── TaskViewModel.swift     # Firestore CRUD + real-time listener for users/{uid}/tasks
└── Views/
    ├── RootView.swift          # Login when signed out, MainTabView when signed in; auth alerts
    ├── MainTabView.swift       # Jar + All Tasks tabs; Firestore error alerts
    ├── TaskListView.swift      # All Tasks: rows, tap to edit, swipe to delete, +, sign out
    ├── AddEditTaskView.swift   # Sheet for creating or editing a task
    ├── Jar/
    │   ├── JarView.swift       # Home screen: draw a random incomplete task
    │   ├── JarGraphic.swift    # Jar drawn as a SwiftUI shape, filled with task slips
    │   └── DrawnTaskCard.swift # Card with Done / Put back
    └── Auth/
        ├── LoginView.swift
        ├── SignUpView.swift
        └── AuthErrorAlert.swift
firestore.rules                 # Firestore security rules
firebase.json                   # Firebase CLI config (rules deploy)
```

## Architecture

MVVM using the Observation framework (`@Observable`). `RootView` owns one `AuthViewModel` and
one `TaskViewModel` and puts both in the environment. Views read them with
`@Environment(AuthViewModel.self)` and `@Environment(TaskViewModel.self)`.

**Listener lifecycle.** `RootView` watches the signed-in user's `uid`:
- When a user signs in, it calls `TaskViewModel.startListening(uid:)`.
- When the session ends for any reason (Sign Out, revoked token, deleted account), it calls `stopListening()`.
- The Sign Out button also stops the listener *before* signing out, so the listener never
  runs without an authenticated user.
- Both view models also remove their listeners in `deinit`.

**Writes** are fire-and-forget. Firestore's latency compensation shows changes right away,
offline too, and write completions only report server-side failures. Edits use `updateData`,
so editing a task that was deleted on another device fails with "That task no longer exists"
instead of silently re-creating it.

**Errors.** Auth and Firestore error codes are mapped to readable messages and shown in alerts.
Auth alerts come from `RootView`, task alerts from `MainTabView`. Firestore errors are also logged
with `OSLog` (subsystem `com.taskjar.TaskJar`).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Crash at launch: `FirebaseApp.configure()` / "could not locate configuration file" | `GoogleService-Info.plist` is missing or not in the TaskJar target (step 2). |
| Sign-in error mentioning `CONFIGURATION_NOT_FOUND` or "operation not allowed" | Email/Password sign-in isn't enabled (step 3). |
| "You don't have access to these tasks" | Rules aren't published, or they don't match `firestore.rules` (step 5). |
| Tasks never load and no error appears | Firestore database not created (step 4), or the bundle ID doesn't match the plist. |

## App icon

`AppIcon.png` is a 1024×1024 placeholder (a jar of colored slips on the accent orange).
Replace it in `TaskJar/Assets.xcassets/AppIcon.appiconset/` before shipping.
