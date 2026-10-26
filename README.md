# LabKeeper

Offline laboratory equipment management app built with Flutter and SQLite.

## Android build requirements

- Flutter 3.32 or newer
- Android Studio and Android SDK
- JDK 17 or 21 (JDK 21 recommended)
- Android NDK `27.0.12077973` and a complete Android CMake installation

Gradle 8.12 and this Flutter toolchain are not compatible with the JDK 25
bundled by some newer Android Studio releases. Select JDK 21 in Android
Studio under **Settings > Build, Execution, Deployment > Build Tools > Gradle >
Gradle JDK**, or point Flutter to an installed JDK from a terminal:

```powershell
flutter config --jdk-dir="C:\path\to\jdk-21"
```

Install the NDK and CMake from Android Studio's **SDK Manager > SDK Tools**.
If CMake 3.22.1 is already installed but the build reports missing CMake
compiler files, uninstall and reinstall that CMake package there.

Restart VS Code after changing the JDK selection, then run:

```powershell
flutter pub get
flutter run
```
