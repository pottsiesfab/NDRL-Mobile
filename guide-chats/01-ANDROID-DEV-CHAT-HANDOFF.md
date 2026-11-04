# COPY THIS INTO A NEW CHAT — NDRL Android Development Environment

You are assisting with the **Nostalgia Drag Racing League (NDRL)** native Flutter Android notification application. Help me recreate the *working* Android development environment on an additional Windows laptop, using the existing source in GitHub. Do not create a fresh Flutter project or replace application source. Work in small stages with commands I can copy into **Windows PowerShell**. Check results between stages. Explain where commands run. Prefer exact diagnosis to resetting an already working setup.

## Goal

At the end, I can clone the NDRL-Mobile repository onto my laptop, restore dependencies, boot a Google Play-enabled Android emulator, build and run the existing NDRL DEV app, obtain an FCM registration token, and register the emulator against NDRL **development** server. I will not send to production or modify the NDRL production portal.

## Known working baseline (November 4, 2026)

- Local desktop source: `C:\Projects\NDRL-Mobile`.
- Intended private GitHub repository: `pottsiesfab/NDRL-Mobile` (verify actual URL after it has been created; do not assume it exists yet).
- Flutter **3.47.9**, Dart **3.13.7**. Prefer matching the `pubspec.lock` and compatible SDK in the cloned repo rather than blindly upgrading.
- Android SDK Platform **API 36** installed; emulator named **`Medium_Phone_API_37.0`** (Android 17/API 37), device ID typically `emulator-5554`. Android NDK **28.2.13676358** was required and installed in the working environment.
- Windows virtualization BIOS SVM/AMD virtualization and **Windows Hypervisor Platform (WHPX)** were enabled on the original computer. Confirm equivalent prerequisites for the new laptop's CPU/BIOS; do not assume AMD.
- Flutter packages include `firebase_core`, `firebase_messaging`, `http`, `flutter_secure_storage`.
- Firebase DEV project ID: **`ndrl-notifications-dev`**, project number `1045907764607`.
- Current **DEV Android application ID**: `com.nostalgiadragleague.ndrl` — despite lacking a `.dev` suffix. Do not change it casually; changing it requires Firebase app registration and fresh token provisioning.
- Firebase app ID: `1:1045907764607:android:b56cd2aaddab31dede164a`.
- FlutterFire generated `lib/firebase_options.dart`; Android Firebase config at `android/app/google-services.json`. These are project configuration identifiers, **not a Firebase service-account private key**. Preserve or regenerate for DEV as required.
- Firebase tooling used: `firebase-tools` command (`firebase.cmd` may be needed in PowerShell), `flutterfire_cli` 1.4.1. The **new laptop does not need Google Cloud service-account JSON** to develop and run the mobile app.
- Existing `lib/main.dart` displays **NDRL Notifications · DEV**, Firebase status/notification permission, preview of FCM token, DEV server registration (`device_id`), and the last foreground notification. It has a refresh/sync token button.
- We verified Firebase Cloud Messaging end-to-end from a dedicated VPS Docker sender to the Android emulator on Nov. 4, 2026. The test message appeared in Android's notification shade. A Firebase accept response alone is *not* confirmation of device display.
- Current DEV API on the NDRL site: `api/notify_device_api.php`, supporting registration, authenticated `me`, and development-only `token.set`. Actual mobile API base URL should be read from the cloned code/config; do not guess or replace it.

## New laptop setup plan — follow in order

1. **Check tools**: Windows version; `git --version`, `flutter --version`, `dart --version`, `flutter doctor -v`, `java -version`, Android Studio/SDK installed; `adb version`, `flutter devices`. If `flutter` missing, install official Flutter SDK (not just Android Studio plugin) and add `flutter\bin` to PATH. Install Git for Windows and Android Studio with SDK Platform, Platform-Tools, Command-line Tools, Build-Tools, Emulator, CMake, and NDK side-by-side.
2. **Android licenses**: `flutter doctor --android-licenses`; resolve only outstanding Android setup issues. Android SDK path may differ from desktop.
3. **Clone**, do not overwrite existing files:
   ```powershell
   New-Item -ItemType Directory -Force C:\Projects | Out-Null
   cd C:\Projects
   git clone https://github.com/pottsiesfab/NDRL-Mobile.git NDRL-Mobile
   cd .\NDRL-Mobile
   git status
   git remote -v
   ```
   If cloning a private repo prompts for authentication, guide Git Credential Manager/browser sign-in or SSH, without requesting passwords/tokens in the chat.
4. **Install deps**: `flutter pub get`, `flutter doctor -v`. Keep `pubspec.lock` checked in and avoid `flutter pub upgrade` unless needed.
5. **Emulator**: Android Studio → Device Manager → create a suitable **Google Play** system-image emulator (existing baseline `Medium_Phone_API_37.0`, if available); verify hardware acceleration. `flutter emulators`, `flutter emulators --launch Medium_Phone_API_37.0`, `flutter devices`. Emulator name may differ on the new laptop; adapt rather than assuming.
6. **Run**: `flutter run -d emulator-5554` (use actual device ID). If prompted for NDK, install required version **28.2.13676358**, or inspect `android/app/build.gradle.kts`/Gradle configuration first. Do not bypass Gradle signing/configuration problems with insecure changes.
7. **Check Firebase**: Ensure `lib/firebase_options.dart` and Android Google Services configuration refer to `ndrl-notifications-dev`, not PROD. If regeneration is necessary, authenticate with authorized Google account and run `flutterfire configure --project=ndrl-notifications-dev --platforms=android`. Preserve package/application ID and review resulting diffs.
8. **Verify**: app shows Firebase Messaging connected; permission authorized; `FCM token stored: YES` after registration. The **new emulator is a distinct installation** and will normally obtain a **new device ID**; do not assume it will be `2`. Device ID 2 belongs to the original test emulator and should not be hardcoded into the mobile app. Confirm actual DEV API response and device record before testing pushes. The original VPS manual sender deliberately only allows device 2, so it will NOT automatically send to a new laptop's emulator.
9. **Troubleshoot**: Emulator Play Services/network, Android notification permission, Gradle/NDK, ADB visibility, API reachability, Firebase project mismatch. For background notification display press Home first, send a message, then swipe down notification shade; foreground notification messages use `FirebaseMessaging.onMessage` and do not automatically show an Android system notification.

## Safety and workflow

- Treat `ndrl-notifications-dev` and the DEV database as the only targets. The production portal must remain unchanged.
- Never ask me to paste Firebase service-account JSON, private key, database passwords, installation secrets, full FCM token, or signing keys.
- The sender's server private key belongs only on `ndrlsite` in `/srv/ndrl-data/private/firebase/dev/service-account.json`, not on the laptop or GitHub.
- Use `main` for normal Git work (the NDRL website project uses `main`; verify the mobile repo's branch). Don't overwrite my source or force-push.
- Do not automatically enable bulk sends or a production queue. Begin with environment diagnostics and report precisely what needs installing.

Official documentation: https://docs.flutter.dev/platform-integration/android/setup and https://firebase.google.com/docs/flutter/setup
