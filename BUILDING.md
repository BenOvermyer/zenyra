# Build Instructions for Developers

## Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (ensure it is added to your PATH)
- [Dart SDK](https://dart.dev/get-dart) (usually included with Flutter)
- Git

---

## Building on macOS

1. **Install dependencies:**
   ```sh
   flutter pub get
   ```
2. **Run the app:**
   ```sh
   flutter run
   ```
3. **Build for macOS:**
   ```sh
   flutter build macos
   ```
   The built app will be in `build/macos/Build/Products/Release/`.

---

## Building on Windows

1. **Install dependencies:**
   ```sh
   flutter pub get
   ```
2. **Run the app:**
   ```sh
   flutter run -d windows
   ```
3. **Build for Windows:**
   ```sh
   flutter build windows
   ```
   The built app will be in `build/windows/runner/Release/`.

---

## Notes
- For iOS/Android, use `flutter build ios` or `flutter build apk` respectively.
- For more details, see the [Flutter documentation](https://docs.flutter.dev/).
