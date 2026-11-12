# Selah — Technical Guide

*Scripture, remembered.* This guide describes the whole Selah project as it stands in November 2026: what it does, the technology it uses, how the code is organised, how data is stored and shared, and how to build, test and change it.

| | |
|---|---|
| **Desktop app** | Windows, PowerShell 5.1 + WPF. Entry point `Selah.ps1`, started by `Start-Selah.cmd`. |
| **Phone app** | Android 7.0+ (API 24), an offline web app inside a small Java WebView shell. Current version **1.16** (versionCode 17). |
| **Project folder** | `D:\BV` (GitHub: `DevarimKhayil/Selah`, public, without personal study files). |
| **User data** | Desktop: `%LOCALAPPDATA%\Selah\state.json`. Phone: the app's own storage (localStorage). |

---

## 1. What Selah does

| Feature | Desktop | Phone |
|---|:-:|:-:|
| **Verse of the day**: a random pick from 446 well-loved verses, with no repeats until all have been shown; **Another** picks again. | ✓ | ✓ |
| **Memory verses**: add your own wording or use *Fill in* (BSB/KJV), focus one verse, three correct recitations mark it memorized. | ✓ | ✓ |
| **Practice: type it from memory**: a live word check (green correct, coral wrong, grey partial), capitals and punctuation ignored, dashes count as spaces. | ✓ | ✓ |
| **Hints**: desktop shows one more letter per press (up to 3); phone shows the first letter, then the whole word. | ✓ | ✓ |
| **Hold to peek**: shows the verse while held. On the desktop it marks and scrolls to the word you are on. | ✓ | ✓ |
| **Wording badge**: tells you whether the saved verse uses BSB, KJV or your own wording. | ✓ | ✓ |
| **Practice reminders** at 10:00, 12:30, 14:00 and 16:30 (desktop: while running; phone: notifications). | ✓ | ✓ |
| **Daily invitation** to read and practise today's verse when no verse is in focus. | ✓ | ✓ |
| **Morning verse notification** at a chosen time. | | ✓ |
| **Home-screen widget** in five sizes (2×1, 3×1, 3×2, 4×1, 4×2). | | ✓ |
| **Bible reader**: all 66 books, BSB and KJV offline; NIV via a BibleGateway link. | ✓ | ✓ |
| **Today's readings**: Proverbs *day*, then Psalms *day*, *+30*, *+60* … up to 150. | ✓ | ✓ |
| **Highlights** in 12 colours, plus a Highlights page with colour filters. | ✓ | ✓ |
| **Verse notes**: a note attached to any verse. | ✓ | ✓ |
| **Reflections**: a dated journal that saves as you type. | ✓ | ✓ |
| **Week page**: words for the week, numbered weekly goals, daily tasks, repeating habits, carry-over, Sunday review. | ✓ | ✓ |
| **Torah readings**: the weekly portion from the user's 5787 card, with Torah, Haftarah and Gospel passages. | ✓ | ✓ |
| **Hebrew date** in English letters (e.g. *2 Kislev 5787*). | ✓ | ✓ |
| **Chalk theme** (Light/Dark) with Inter and Source Serif 4. | ✓ | ✓ |
| **Reading font and text size** settings (Serif/Sans, S–XL). | | ✓ |
| **Backup and import** (the phone imports the desktop's `state.json` and its own backups). | | ✓ |
| **Tray icon**, start with Windows, desktop shortcut, single-instance lock. | ✓ | |

The Romans (BSF) study was **removed in November 2026**, because BSF has its own app. Old answers were set aside rather than deleted (see §6.4).

---

## 2. Technology stack

### 2.1 Desktop

| Layer | Technology | Notes |
|---|---|---|
| Language | **Windows PowerShell 5.1** | Not PowerShell 7. Scripts must be **UTF-8 with BOM**. |
| UI | **WPF** (Windows Presentation Foundation, .NET Framework 4.x) | Windows and controls are declared in `.xaml` files and loaded at runtime with `XamlReader`. |
| Styling | `Theme.xaml` ResourceDictionary plus runtime brushes | `Set-Theme` writes colour brushes into `Application.Resources`, and controls use `DynamicResource`. |
| Fonts | **Inter** (UI) and **Source Serif 4** (Scripture), TTF in `Fonts\` | SIL Open Font License. Loaded through the `ParserContext.BaseUri` given to `Theme.xaml`. |
| Native calls | C# via `Add-Type` + P/Invoke | `kernel32` hides the console window; `dwmapi` draws a dark title bar. |
| Tray | WinForms `NotifyIcon` | Balloon tips for reminders; Open/Quit menu. |
| Timer | WPF `DispatcherTimer` (30 s) | Day roll-over and reminders. |
| Shortcuts | `WScript.Shell` COM | Start menu, Startup folder and desktop `.lnk` files that launch `Start-Selah.cmd`. |
| Launcher | `Start-Selah.cmd` → `conhost --headless powershell -STA -File Selah.ps1` | No console window appears. `Start-Selah-debug.cmd` keeps one for troubleshooting. |
| Data | JSON (`ConvertTo-Json` / `ConvertFrom-Json`) | Atomic save: write a temp file, then `File.Replace`, which keeps `state.bak`. |
| Tests | `Test-Selah.ps1`, `RunCheck.cmd` | Smoke test plus preview screenshots. |

### 2.2 Phone

| Layer | Technology | Notes |
|---|---|---|
| UI | **HTML + CSS + JavaScript (ES5, no framework)** | `mobile/assets/www/index.html`, `app.js`, `app.css`. Works offline; the same files run in any browser for testing. |
| Storage | `localStorage` key `selah.state` (one JSON value) | Separate keys: `selah.torah` (an imported Torah card) and `selah.bsfArchive` (old Romans answers). |
| Shell | **Java**, Android `Activity` + `WebView` | `MainActivity` loads `file:///android_asset/www/index.html` and exposes `window.SelahAndroid`. |
| Notifications | `AlarmManager` + `BroadcastReceiver` + `NotificationManager` | Channels are created through reflection, because the app compiles against API 23. |
| Widget | `AppWidgetProvider` + `RemoteViews` | One layout, five provider classes for the five starting sizes. |
| Target | minSdk 24, targetSdk 34, compiled against `android.jar` API 23 | Newer APIs are used through reflection or literal constants (e.g. `FLAG_IMMUTABLE = 0x04000000`). No lambdas. |
| Build | **No Gradle**: `aapt` → `javac` (Java 8 target) → `dalvik-exchange` (dx) → `zipalign` → `apksigner` | `mobile/build.sh`; Ubuntu/WSL packages only. |
| Signing | `selah-release.jks` (alias `selah`) | Updates install over the old app only with the same key. Never commit the keystore. |

### 2.3 Tooling and data

| Tool | Purpose |
|---|---|
| **Python 3** `tools/build_android_data.py` | Converts `BibleData/*.json` into per-book JS files and builds `data/pool.js` (daily pool, books, chapter counts) and the optional `data/torah.js`. |
| **Python 3** `BuildStudyData.py` (`pdfplumber`) | Extracts the Torah card (`StudyData/torah-*.json`) from the user's own PDF. |
| **Playwright** (Chromium) | Used during development to test the phone web app at 412×860 and to take screenshots. |
| **Git / GitHub** | Repository `DevarimKhayil/Selah`; personal study data and keystores are in `.gitignore`. |

---

## 3. Project layout

```
D:\BV
├─ Selah.ps1               Desktop app: state, themes, verses, practice, reminders, pages, tray, start-up
├─ StudyFeatures.ps1       Hebrew date, Torah card, Bible text & passages, reference detection
├─ BibleFeatures.ps1       Highlights (12 colours), Highlights page, Bible book list with chapter grids
├─ WeekFeatures.ps1        Week page: words, goals, daily tasks, habits, carry-over, review
├─ Theme.xaml              Shared WPF styles and fonts (colour brushes come from Set-Theme)
├─ MainWindow.xaml         Main window: sidebar + one page per section
├─ PracticeWindow.xaml     "Type it from memory" dialog
├─ AddVerseWindow.xaml     Add / edit verse dialog
├─ DailyInviteWindow.xaml  Daily verse invitation
├─ ScriptureWindow.xaml    Passage reader dialog
├─ Fonts\                  Inter + Source Serif 4 (TTF) and their OFL licences
├─ BibleData\              KJV books (*.json), BSB books (BSB\*.json), Books.json, licence
├─ daily-verses.json       446 daily-verse references (text comes from the chosen translation)
├─ StudyData\              Torah card JSON (personal, not in git) + SOURCES.md
├─ BuildStudyData.py       Rebuilds the Torah JSON from the user's PDF
├─ Test-Selah.ps1          Desktop smoke test
├─ RunCheck.cmd / .ps1     Test + preview screenshots → check-log.txt, preview-*.png
├─ Start-Selah.cmd         Windowless launcher;  Start-Selah-debug.cmd keeps a console
├─ selah.ico               App icon (black, chalk book, lime ribbon)
├─ CLAUDE.md               Short rules for working on the code with Claude Code
├─ README.md               User-facing overview
├─ SELAH-GUIDE.md          This document
├─ tools\build_android_data.py
├─ Android\                Built APKs (Selah-1.x.apk), not in git
└─ mobile\                 Android app source
   ├─ AndroidManifest.xml  Package app.selah, version, permissions, receivers (reminders, 5 widgets)
   ├─ build.sh             Gradle-free build script
   ├─ res\                 Icons, widget layout/background/preview, widget size definitions, styles
   ├─ src\app\selah\       MainActivity, ReminderReceiver, DailyVerse, VerseWidget (+4 size classes)
   └─ assets\www\          index.html, app.js, app.css, fonts\ (WOFF2)
                           generated: bible\{BSB,KJV}\<Book>.js, data\pool.js, data\torah.js
```

---

## 4. Desktop app in depth

### 4.1 Start-up sequence (`Selah.ps1`)

1. **Error trap.** Any start-up error is written to `startup-error.log` and shown in a message box, because there is no console window to see it in.
2. **WPF assemblies** are loaded. The small C# helper `SelahNative` hides the console and colours the title bar.
3. **Single instance.** The named mutex `Local\SelahDesktopApp` makes a second launch explain itself and exit.
4. **State variables** are created (`$script:verses`, `$script:reflections`, `$script:weeks`, …), and the daily pool, Torah card and book list are read.
5. **Functions** are defined. `StudyFeatures.ps1`, `BibleFeatures.ps1` and `WeekFeatures.ps1` are **dot-sourced**, so they share the `$script:` scope.
6. **`Theme.xaml`** is loaded with a base URI, so `./Fonts/#Inter` resolves to the bundled fonts.
7. `Load-State` → `Set-Theme` → `Ensure-DailyVerse`.
8. **`MainWindow.xaml`** is loaded, and every named control is stored in `$script:ui`. A missing name stops start-up with a clear message.
9. The **tray icon**, the **button and event wiring** and the **30-second timer** are set up.
10. `Update-View`, open today's Proverbs chapter, show Home, run `Update-Layout`, then `app.Run()`.
11. A **`DispatcherUnhandledException`** handler logs any later error to `selah-errors.log` and keeps Selah running.

### 4.2 Pages

`Show-Page` toggles the page containers in `MainWindow.xaml` and highlights the matching sidebar button.

| Page | Built by | Notes |
|---|---|---|
| Today (Home) | `Update-View` | Verse of the day card, current focus, verses memorized, today's readings, and Explore tiles (Torah, Reflections). |
| Week | `Update-WeekPage` (WeekFeatures) | Rebuilt in code after each change. Goals on the left; day strip, tasks and review on the right. |
| Bible | `Set-BibleChapter`, `Initialize-BookList` | One clickable row per verse; the side panel holds the note, highlight swatches and Memorize. |
| Highlights | `Update-HighlightsPage` | Filter chips by colour. |
| My verses | `Update-Library`, `Update-SelectedVerse` | Focus, practice, edit. |
| Reflections | `Open-JournalDate`, `Save-Reflection` | Saves on every keystroke. |
| Torah | `Update-TorahView` | Current reading, its passages and upcoming portions. |
| Settings | `Update-SettingsView` | Theme, translation, start with Windows, daily invitation, desktop shortcut. |

### 4.3 Practice flow

`Show-Practice` runs these steps in order:

1. **Blur** the main window and hide the verse text everywhere (`Hide-PracticeSources`).
2. **Load** `PracticeWindow.xaml` and set the reference and wording badge (`Get-WordingSource`).
3. **On every keystroke**, `Update-WordFeedback` redraws the coloured chips (`Get-LiveWords`), and `Show-CaretWord` scrolls them to the word you are on.
4. **Hint** (`Get-NextHint`) reveals one more letter of the next word, up to three.
5. **Hold to peek** (`Show-PeekAt`) shows the verse, underlines the next word in lime and scrolls to it. While holding, the mouse wheel or the Up/Down keys scroll the verse.
6. **Check answer** compares the answer with the verse (`Test-VerseMatch`). If it matches, `Record-Pass` counts one recitation; three passes mark the verse memorized.

### 4.4 Reminders

`Check-Reminder` runs every 30 seconds. Between 10:00 and 17:00 it looks for a reminder time that has passed today, since the verse became the focus, and has not been delivered yet. Delivered keys (`yyyy-MM-dd|verseId|HH:mm`) are kept in `delivered`, so a reminder fires only once. After downtime it offers **one** prompt rather than a backlog. If the window is hidden, a tray balloon appears too.

### 4.5 Theme system

* `$script:palettes.Light` and `.Dark` hold every colour key: `Pane`, `Card`, `CardAlt`, `Field`, `Text`, `TextSecondary`, `Accent`, `AccentSoft`, `Pop`, `PopText`, `HeroText`, `HeroCaption`, `TileBg`, `TileFg`, `Success`, `Warning`, …
* `Set-Theme` turns each `#hex` into a frozen `SolidColorBrush` in `Application.Resources`. `Bg`/`Hero` become `WindowBg`/`HeroBrush`; with equal colours they are flat fills.
* XAML refers to these keys with `{DynamicResource Key}`, and code uses `SetResourceReference(...)`. Both repaint instantly when the theme changes.
* Rule: style keys in `Theme.xaml` must not reuse a brush key (hence `CardStyle`, `FieldStyle`, …).

### 4.6 Week page internals (`WeekFeatures.ps1`)

* JSON from `state.json` is converted to **hashtables and lists** (`ConvertTo-PlainData`) so goals and tasks can be edited in place and saved back.
* Event handlers carry their data in each control's `Tag`. `GetNewClosure()` is avoided, because closures lose access to script-scope functions in WPF handlers.
* Editing uses context menus (rename / tag / link to goal / repeat / delete) and a small `InputBox` for text.

---

## 5. Phone app in depth

### 5.1 Shell (`mobile/src/app/selah`)

| Class | Role |
|---|---|
| `MainActivity` | Hosts the WebView, colours the system bars, handles Back (asks the web app to close a sheet first), file save/open, and the JS bridge `window.SelahAndroid`. |
| `ReminderReceiver` | Alarm and boot/update receiver. Shows practice notifications and the morning verse notification, refreshes widgets, schedules the next alarms. |
| `DailyVerse` | Reads today's verse from the 60-day plan saved by the web app; shows the verse notification; updates all widgets. |
| `VerseWidget` (+ `2x1`, `3x2`, `4x1`, `4x2`) | Home-screen widget. The text size is calculated to fit the widget's size (`fitTextSize`). |

**JavaScript bridge (`window.SelahAndroid`)**

| Method | Called when |
|---|---|
| `openUrl(url)` | NIV and other web links. |
| `consumeReminder()` | At start-up: true once if the app was opened from a practice notification. |
| `setBarColors(bar, bg, dark)` | Theme changes. |
| `scheduleReminders(enabled, title, body)` | The focus verse or the reminder setting changes. |
| `setDailyPlan(json, translation)` | The 60-day verse plan changes (for notifications and widgets). |
| `setDailySchedule(enabled, "HH:mm")` | The morning verse time or toggle changes. |
| `testDailyNotification()` | The Settings test button. |
| `saveTextFile(name, mime, text)` / `openTextFile()` | Backup export and import. The opened file's text returns via `Selah.onFileOpened`. |

### 5.2 Web app (`mobile/assets/www`)

* `index.html` defines one `<section>` per page, the header, the tab bar (**Today · Week · Bible · My verses · More**), `#sheets` and `#toast`. It loads `data/pool.js`, the optional `data/torah.js`, then `app.js`. The saved theme is applied before the first paint.
* `app.js` is one IIFE, organised by section banners: **helpers → state → Bible data → daily verse → verses & practice → sheets → navigation → pages → Week → theme → reminders → start**.
* **Navigation:** `go(page)` shows a page and `render(page)` draws it. Pages are fully re-rendered from `st`, which keeps the code simple.
* **Sheets:** `openSheet()` builds the dialogs. They stack, close with Back, and can be dragged down.
* **Bible books** load on demand (`loadBook`) from `bible/<TR>/<Book>.js`. Each file calls `Selah.bookLoaded(...)`.
* **Daily plan:** `planAhead()` plans 60 days ahead, so notifications and the widget work while the app is closed.

### 5.3 Theme and type

The CSS variables live on `:root` (Chalk Light) and `[data-theme="dark"]` (Chalk Dark). `[data-mode="dark"]` switches the highlight tints. `--read-font` and `--read-size` are set from Settings (Serif = Source Serif 4, Sans = Inter; S/M/L/XL = 15/17/19/21 px).

---

## 6. Data model

The desktop and the phone use the **same shapes**, so a desktop `state.json` can be imported on the phone.

### 6.1 `state.json` / `selah.state`

| Field | Type | Meaning |
|---|---|---|
| `version` | number | Format version (1). |
| `verses` | array | `{ id, reference, text, addedAt, passes, memorizedAt, lastReviewedAt, source }`. `source` is `personal`, `daily` or `bible`. |
| `focusId`, `focusSince` | string | The verse being memorized and when it became the focus. |
| `reflections` | array | `{ date: 'yyyy-mm-dd', text, savedAt }`, one per day. Shared by the Reflections page. |
| `bibleNotes` | array | `{ key: 'Book|chapter|verse', text, savedAt }`. |
| `highlights` | object | `{ 'Book|chapter|verse': { color, at } }`. Colours: honey, apricot, coral, blush, orchid, lilac, periwinkle, sky, aqua, mint, sage, sand. |
| `daily` | object | `{ date, index }`: today's pick from the daily pool. |
| `dailyUsed` | array of numbers | Pool indexes already shown, so nothing repeats until all have been used. |
| `dailyPoolVersion` | number | Bumped when the pool changes; resets `dailyUsed`. |
| `delivered` | array of strings | Reminder keys already shown (desktop). |
| `offerDailyWhenNoFocus` | boolean | Daily invitation on/off. |
| `theme` | `'Light'` / `'Dark'` | Older names are mapped: Dusk/Midnight/Harbor Night → Dark; anything else → Light. |
| `translation` | `'BSB'` / `'KJV'` | Scripture translation. |
| `weeks` | object | See §6.2. |
| `habits` | array | `{ id, text, repeat: 'daily' / 'weekdays', goal }`. |
| *Phone only* | | `dailyPlan` (`{ 'yyyy-mm-dd': poolIndex }`), `dailyNotifyOn`, `dailyNotifyTime`, `remindersOn`, `readFont`, `readSize`, `lastLight`, `lastDark`. |

### 6.2 Weeks

```json
"weeks": {
  "2026-11-09": {
    "words":  ["Do hard things"],
    "goals":  [ { "id": "…", "text": "Study ISP8s", "tag": "Work", "status": "partly", "moved": false } ],
    "days": {
      "2026-11-12": {
        "tasks": [ { "id": "…", "text": "Reply Terry", "status": "", "goal": 4,
                     "habit": null, "from": "2026-11-11", "carried": false } ],
        "habitsAdded": true,
        "carryDismissed": ""
      }
    },
    "review": "One line for next Monday",
    "updatedAt": "2026-11-12T09:40:00Z"
  }
}
```

* The week key is the **Monday** date. Status values: `''` open, `done`, `partly`, `tried`, `no` (did not happen).
* `goal` is the goal's **number** (1-based). Deleting a goal renumbers the task links.
* `from` marks a task brought over from an earlier day; the original gets `carried: true`.
* When a phone import merges weeks, the copy with the newer `updatedAt` wins, week by week.

### 6.3 Sync between devices

* **Desktop → phone:** on the phone, Settings › Backup › import `%LOCALAPPDATA%\Selah\state.json`. Verses, reflections, notes, highlights and weeks are merged, and nothing is deleted.
* **Phone → desktop:** not available yet; the desktop has no import. This is a planned improvement.

### 6.4 Removed Romans data

* **Desktop:** old answers are written once to `%LOCALAPPDATA%\Selah\bsf-answers-archive.json`, then dropped from `state.json`.
* **Phone:** they are moved to localStorage `selah.bsfArchive`.
* The lesson file was moved to `D:\BV\_to_delete\romans`.

---

## 7. Design system: Chalk

| Token | Hex | Role (Light) | Role (Dark) |
|---|---|---|---|
| Chalk | `#F7F7F1` | Page background (60%) | Text |
| Ink | `#0A0A0A` | Text, primary buttons, hero card, icon tiles (30%) | Page background |
| Lime | `#C7FF2E` | Accent (10%): selected tab, *Memorize this*, tile icons, captions | Same |
| Mist | `#C9D0D6` | Field borders, soft surfaces | Selected chips/segments, secondary text |
| Slate | `#6F7780` | Tertiary text | Same |

* **No purple-to-blue gradients, no generic SaaS blues, no glows.** Lime is used sparingly and never as text on chalk.
* **Fonts:** Inter (interface) and Source Serif 4 (Scripture), the same pairing as the YouVersion Bible reader.
* **App icon:** a chalk open book with a lime ribbon on ink. **Widget:** ink background, lime label, chalk verse text.

---

## 8. Building and running

### 8.1 Desktop

```powershell
.\Start-Selah.cmd                 # normal start (no console)
.\Start-Selah-debug.cmd           # visible console; errors stay on screen
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Test-Selah.ps1
.\RunCheck.cmd                    # test + preview-*.png screenshots -> check-log.txt
```

Nothing needs installing; it uses the Windows PowerShell and WPF built into Windows. Start-up errors go to `startup-error.log`, and later errors go to `selah-errors.log`.

### 8.2 Phone

```bash
sudo apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-17-jdk python3
SELAH_KEYSTORE=/path/selah-release.jks SELAH_KEYSTORE_PASS=... ./mobile/build.sh   # -> mobile/build/Selah.apk
```

`build.sh` runs `tools/build_android_data.py` first, which generates the Bible JS files and `data/*.js` from the desktop data. For each release, bump `versionCode` and `versionName` in `mobile/AndroidManifest.xml`, and sign with the **same** keystore so the update installs over the old app.

To test the web app in a browser, open `mobile/assets/www/index.html` after generating the data. `window.Selah.debug` exposes helpers (`go`, `setTheme`, `getWeek`, `renderWeek`, `st()`, …) for automated tests.

---

## 9. Testing

* **`Test-Selah.ps1`** starts Selah in `-TestMode` with a throwaway data folder. It checks file encodings, data loading, Hebrew dates, the Torah card, reference detection, passages, daily verse rotation, practice (answer matching, hints, peek, live check), dialogs, theme and fonts, the Week page, Bible browsing, highlights, notes, reflections and saving. Any failure throws with a plain message.
* **`RunCheck.cmd`** runs the test, then renders preview screenshots of Home and Week (Light and Dark), Bible, Settings, Torah and My verses.
* **Phone:** Playwright scripts drive the web app at 412×860. They add goals and tasks, carry tasks over, test habits, the review and theme switching, and check that there are no console errors.

---

## 10. Conventions and gotchas

* **PowerShell files must stay UTF-8 *with BOM*.** Curly quotes inside strings end the string in PowerShell, so use `[char]0x2019` and similar.
* **Don't use `GetNewClosure()` for WPF event handlers.** Put the data in `Tag` and read it from the `$sender`.
* **Style keys in `Theme.xaml` must not equal palette brush keys.**
* **UI colours use `DynamicResource` / `SetResourceReference`.** Hard-coded hex is only for highlight colours.
* **Android:** no lambdas or `java.util.function`. APIs above 23 go through reflection or literal constants.
* **Never commit** `StudyData/torah-*.json`, `mobile/assets/www/data/torah.js` or any `*.jks`.
* **NIV text is copyrighted:** link to BibleGateway, never bundle it.
* **Romans/BSF study was removed on purpose:** don't bring it back.

---

## 11. Licences and sources

* **BSB:** Berean Standard Bible, dedicated to the public domain (CC0), via scrollmapper `bible_databases`.
* **KJV:** book files from Arul John's `Bible-kjv` (MIT; licence in `BibleData`).
* **NIV:** not bundled; *Read in NIV* opens BibleGateway.
* **Fonts:** Inter and Source Serif 4, SIL Open Font License (licence texts in `Fonts\` and `mobile/assets/www/fonts`).
* **Torah card:** the user's personal 5787 card (`StudyData/SOURCES.md`); not in the public repository.

---

## 12. Recent history

| Version | Change |
|---|---|
| 1.6–1.7 | Widget made smaller and more compact. |
| 1.8 | Reading themes, YouVersion-style fonts, text-size setting. |
| 1.9–1.11 | New palettes tried (Harbor, then Chalk); new app icon and widget colours. |
| 1.10 | Widget available in five sizes; doubled quote marks fixed. |
| 1.12 | Only Chalk Light and Dark kept. |
| 1.13–1.14 | **Week** page (goals, tasks, habits, carry-over, review); reflection box removed from Week. |
| 1.15 | Romans (BSF) study removed. |
| 1.16 | Code clean-up and comments; no visible changes. |
| Desktop | Chalk theme and fonts, 3-letter hints, live check follows the cursor, peek jumps to your word, Week page, Romans removed. |

**Next ideas:** a desktop import of phone backups (two-way sync), the phone peek jumping to the current word, and pushing the latest changes to GitHub.
