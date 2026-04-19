# Fitbit

Single repo for the Fitbit Flutter app and its Firebase backend.

## Project Layout

- `lib/` Flutter app
- `backend/functions/` Firebase Functions backend
- `firebase.json` Firebase + emulator config for this repo

## Quick Start

Use two terminals from inside this folder:

### Terminal 1: start backend

```bash
cd /Users/rudritrivedi/Desktop/mergecode/FITBIT_PROJECT/fitbit
npm run server
```

This starts:

- Functions emulator on `http://127.0.0.1:5002`
- Firestore emulator on `127.0.0.1:8080`

### Terminal 2: run Flutter app

If Flutter is already installed on your machine and available in PATH:

```bash
cd /Users/rudritrivedi/Desktop/mergecode/FITBIT_PROJECT/fitbit
flutter run
```

Then select the device when Flutter prompts you.

If `flutter` is not available in PATH, use the bundled SDK in this workspace:

```bash
cd /Users/rudritrivedi/Desktop/mergecode/FITBIT_PROJECT/fitbit
../flutter/bin/flutter run
```

## Why You Do Not Need Absolute Paths

You only need absolute paths when you are running commands from somewhere else.

If you first do:

```bash
cd /Users/rudritrivedi/Desktop/mergecode/FITBIT_PROJECT/fitbit
```

then you can use normal local commands like:

```bash
npm run server
flutter run
```

So yes, your normal flow can be:

1. `cd FITBIT_PROJECT/fitbit`
2. `npm run server`
3. `flutter run`
4. Select device

If `flutter` is not installed in your shell PATH yet, use:

```bash
npm run app
```

That starts the app with the bundled Flutter SDK already present in this workspace.

## Useful Commands

```bash
npm run server
```

Starts Functions + Firestore emulators from the main repo.

```bash
npm run app
```

Starts `flutter run` using the bundled Flutter SDK.

```bash
npm run server:preflight
```

Checks Java/Firebase emulator prerequisites without starting them.

```bash
cd backend/functions && npm test
```

Runs backend tests.

## Notes

- `npm run server` is a wrapper command from the repo root. It forwards to `backend/functions`.
- Fitbit health data depends on the Firebase emulators running.
- Heart rate may appear as resting heart rate when Fitbit provides it, otherwise the UI falls back to the latest intraday BPM value.
