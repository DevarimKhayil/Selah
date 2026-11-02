# Selah — notes for Claude Code

Selah is a Scripture-memory and Bible-study app with two front ends that share the same data:

- **Desktop (Windows):** PowerShell 5.1 + WPF, files in the repository root. Entry point `Selah.ps1`.
- **Phone (Android):** an offline web app (`mobile/assets/www`) inside a small Java WebView shell (`mobile/src`).

## Layout

| Path | What it is |
| --- | --- |
| `Selah.ps1` | Desktop app: state, verses, practice, reminders, tray, themes, window wiring. |
| `StudyFeatures.ps1` | Hebrew date, Torah readings, Bible text/passages, reference detection (`Find-ScriptureReferences`), Romans study. |
| `BibleFeatures.ps1` | Verse highlighting (12 colours), Highlights page, book list with chapter grids. |
| `Theme.xaml` | Shared WPF styles. Colour brushes are written at runtime by `Set-Theme` (Light/Dark). |
| `MainWindow.xaml`, `*Window.xaml` | Desktop windows and dialogs. |
| `BibleData/*.json` | KJV (MIT, Arul John). `BibleData/BSB/*.json` is the Berean Standard Bible (CC0). |
| `daily-verses.json` | The 446-verse daily pool (references only; text comes from the chosen translation). |
| `StudyData/` | Personal study data. `SOURCES.md` is public; the lesson/Torah JSON files are **not** in git. |
| `BuildStudyData.py` | Rebuilds `StudyData/*.json` from the user's own PDFs. |
| `Test-Selah.ps1` | Desktop smoke test (Windows only). `RunCheck.cmd` runs it and saves preview PNGs. |
| `mobile/` | Android app: `AndroidManifest.xml`, `res/`, `src/app/selah/*.java`, `assets/www/{index.html,app.js,app.css}`. |
| `tools/build_android_data.py` | Generates the phone's `bible/`, `data/pool.js`, and (if present) `data/romans.js`, `data/torah.js`. |

## Running and testing

Desktop (Windows PowerShell 5.1, not pwsh 7):

```powershell
.\Start-Selah.cmd                 # normal start, no console window (conhost --headless)
.\Start-Selah-debug.cmd           # visible console; errors stay on screen
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Test-Selah.ps1
.\RunCheck.cmd                    # test + preview screenshots -> check-log.txt, preview-*.png
```

Startup errors are written to `startup-error.log`. User data lives in `%LOCALAPPDATA%\Selah\state.json` (override with `SELAH_DATA_DIR`).

Phone (Linux/WSL, no Gradle):

```bash
sudo apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-17-jdk python3
SELAH_KEYSTORE=/path/selah-release.jks SELAH_KEYSTORE_PASS=... ./mobile/build.sh   # -> mobile/build/Selah.apk
```

The web app can be tested in any browser by opening `mobile/assets/www/index.html` after running `tools/build_android_data.py` (Playwright at a 412×860 viewport works well). `window.Selah.debug` exposes helpers for tests.

## Rules and gotchas

- **Never commit** `StudyData/romans-lessons.json`, `StudyData/torah-*.json`, `mobile/assets/www/data/romans.js`, `mobile/assets/www/data/torah.js` (BSF material is licensed for personal class use only), or any `*.jks` keystore. They are in `.gitignore`.
- **Signing key:** phone updates install over the old app only when signed with the same `selah-release.jks`. Keep it out of git; bump `versionCode` in `mobile/AndroidManifest.xml` for every release.
- The Android build compiles against API 23 (`android.jar` from Ubuntu). Newer APIs (notification channels, `setChannelId`, `FLAG_IMMUTABLE`) are used through reflection or literal constants. No lambdas or `java.util.function`.
- PowerShell files must stay **UTF-8 with BOM** (Windows PowerShell reads BOM-less files as ANSI). Curly single quotes inside strings end the string in PowerShell; use `[char]0x2019` etc.
- Do not use `GetNewClosure()` for WPF event handlers: closures lose access to script-scope functions. Handlers rely on dynamic scope (dialogs run inside `ShowDialog()`).
- In `Theme.xaml`, style keys must not match palette brush keys set by `Set-Theme` (`Card`, `Field`, `ScrollThumb`, ...). Styles use the `...Style` suffix for that reason.
- UI colours in code use `SetResourceReference(..., 'Key')` so Light/Dark switching works; avoid hard-coded hex except highlight colours.
- Data formats are shared between desktop and phone: verses, reflections, `bibleNotes` (key `Book|chapter|verse`), `bsfAnswers`, `highlights` (`{key: {color, at}}`). The phone imports a desktop `state.json` through Settings › Backup.
- Romans lessons change on **Wednesday** (Lesson 5 began 2026-10-14). Reminder times are 10:00, 12:30, 14:00, 16:30.
- NIV text is copyrighted: never bundle it; link to BibleGateway instead.
