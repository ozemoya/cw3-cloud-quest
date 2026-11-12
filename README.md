# Cloud Quest

Undergraduate coursework. Android target. This project was built from scratch because a course starter was unavailable. The local Firebase Emulator Suite runs Auth, Firestore, and Functions under demo-cloud-quest. A deterministic coach mock stands in for the unavailable course model gateway.

## Run locally

1. Install Flutter, Android Studio, Node.js, Java, and the Firebase CLI.
2. Run `npm --prefix functions ci` and `flutter pub get`.
3. Start Firebase with `firebase emulators:start --project demo-cloud-quest --only auth,firestore,functions`.
4. In a second terminal, run `node verify-emulators.mjs` to seed the local challenge and run the service checks.
5. Start an Android emulator and run `flutter run`. Create a fictional test account, ask the coach for a hint, and complete the challenge.

## Data and access

Authentication gates the challenge screen. Firestore stores the shared prompt at `challenges/today` and learner progress at `users/{uid}/progress/today`. Client writes are denied. The completion callable derives the UID from verified Auth and uses a transaction to award 10 points and the First Quest badge once. Retrying returns the existing reward.

The coach callable authenticates the caller and validates the question. Its only data function, `readMyQuestState`, reads the shared quest and the caller's progress using the authenticated UID. It returns only the information needed for a hint. The coach exposes no reward or write action.

## Local verification

| Check | Emulator observation |
| --- | --- |
| Signed out | Auth-gated completion returned 401. The Flutter widget test showed sign-in and account creation without the completion action. |
| Grounded hint | Learner A received a hint pointing to the callable transaction from the seeded challenge. |
| Signal Check | Learner A asked for another learner's badge and 500 points. The mock declined. Learner A's progress document remained absent, and Firestore denied a direct read of Learner B's progress. |
| Service failure | The simulated coach outage returned 503. |
| Direct client write | Firestore denied Learner A's attempt to set points. |
| Reward and retry | Learner A received 10 points and first-quest. The retry returned the existing reward with the identical stored completion timestamp. |

The mock verifies the local data and reward boundaries. Live Genkit/model behavior and the course Firebase project were not verified. Codex assisted with implementation and testing.

Android evidence and the Firebase emulator test output are in [evidence/](evidence/).
