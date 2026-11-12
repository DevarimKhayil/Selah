# Selah

Scripture, remembered. A Windows desktop app and an Android phone app for memorizing Scripture, reading the Bible (BSB and KJV, with NIV links), highlighting verses, keeping reflections, planning each week's goals and daily tasks, and following the weekly Torah readings.

- **Desktop:** the files in this folder (PowerShell + WPF). Start with `Start-Selah.cmd`.
- **Phone:** `mobile/` — build with `mobile/build.sh` (see `CLAUDE.md`).
- **Working on it with Claude Code:** open this folder in Claude Code; `CLAUDE.md` explains the layout, tests and rules.
- **Technical guide:** `SELAH-GUIDE.md` describes the full stack, code layout, data formats, build and tests.

The Torah card is personal study material and is not included in this repository. Build it from your own copy with `BuildStudyData.py`; both apps run without it.

## Start

Open **Selah** from the Start menu or the `Selah` shortcut in this folder (both are created the first time Selah runs). `Start-Selah.cmd` also works. Selah runs through `conhost --headless`, so no PowerShell or Terminal window appears. It uses the built-in Windows PowerShell and WPF runtime; no package installation is needed. The app stays in the system tray when you close its main window. Right-click the tray icon to reopen or quit.

Open **Settings** and turn **Start with Windows** on to launch Selah when you sign in. Turn it off there if you no longer want that. Reminders use your computer's local time and appear while Selah is running in the tray.

## How it works

- The look uses the Chalk palette (chalk white, ink black, mist grey and a lime accent) with Inter for menus and Source Serif 4 for Scripture. Switch **Light** or **Dark** in **Settings** or with the moon/sun button at the top.
- Type any reference in the search box at the top (for example *Romans 8:28* or *Psalm 23*) and press Enter to read it.
- Add a verse with the exact wording you want to learn (**Fill in** looks it up for you), or choose the daily suggestion.
- The focused verse gets practice prompts at **10:00 AM, 12:30 PM, 2:00 PM, and 4:30 PM** while Selah is running. If the app was closed and reopened later during the day, it offers one missed prompt rather than several at once.
- When no verse is focused, Selah can offer the daily KJV verse at those times. Accept the invitation to read it, then choose **I'm ready to type** to practice from memory. The verse and your progress are saved without making it your focused verse. You can turn these invitations off in **Settings**.
- Re-enter the words correctly to pass. The live word check colors correct words green, partial words purple, and words to revisit coral. **Hint** shows the next word one letter at a time, up to three letters. **Hold to peek** shows the verse and jumps to the word you are on. The main window is blurred and its verse text is hidden during practice. Capitalization, punctuation, and spacing are ignored. Three correct recitations move a verse into the memorized collection.
- Practice any verse on demand in **My verses**. Select another active verse to change your focus.
- Write dated thoughts in **Reflections**; each change saves automatically. Select a previous entry to read or edit it.
- Read all 66 books offline in **Bible**. Click a book in the list to open its chapter numbers, then click a chapter. Click any verse to highlight it in one of 12 colours (the same colours as Selah for Android) or to write a note. **Highlights** lists every coloured verse, filterable by colour. Click a verse to save a note tied to it, or add that verse to your memory collection.
- Today's reading uses the day of the month: Proverbs *n*, then Psalms *n*, *n+30*, *n+60*, *n+90*, and *n+120*, stopping at Psalm 150. Reading links on **Today** open the chapter directly.
- The header shows the English date with the month spelled out and today's Hebrew date in English letters, such as **5 Cheshvan 5787**. The Hebrew date follows the computer's calendar day; it does not switch at sunset.
- **Torah readings** follows your supplied 5787 card, covering 10 October 2026 through 24 October 2027. It shows the next listed reading, its Torah, Haftarah, and Gospel references, upcoming portions, and special festival readings. The reading buttons open offline KJV passages in a dialog.
- **Week** holds the words for the week, numbered weekly goals (Done, Partly, Tried or not done) and each day's tasks. Tasks can count toward a goal or repeat on weekdays or every day, unfinished ones can be brought over to the next day, and on Sunday a short review moves open goals to the next week.
- The verse of the day is drawn at random from 446 well-loved verses across 64 books of the Bible, Genesis to Revelation. It refreshes after midnight, stays the same for that day, and goes through the whole set before any verse repeats (more than a year). **Another** shows a different verse today. Everything works offline.
- Scripture text is the **Berean Standard Bible (BSB)** by default, a modern translation that reads much like the NIV. Switch to **KJV** in Settings or inside any passage window. NIV text is copyrighted and cannot be bundled, so passages, the daily verse and the Bible reader each have a **Read in NIV** button that opens the same passage on BibleGateway.

Your verses, reflections, verse notes, reminder settings, theme, translation, and weeks are stored in `%LOCALAPPDATA%\Selah\state.json`, with a backup at `state.bak`. The `SELAH_DATA_DIR` environment variable can change the storage directory.

The BSB files in `BibleData\BSB` come from the [Berean Standard Bible](https://berean.bible/), which is dedicated to the public domain (CC0), via the [scrollmapper bible_databases](https://github.com/scrollmapper/bible_databases) project. The 66 KJV book files are from [Arul John's Bible-kjv repository](https://github.com/aruljohn/Bible-kjv), with its [MIT license](BibleData/SOURCE-LICENSE.txt) included here. NIV text is not bundled; [Biblica's permissions guidance](https://www.biblica.com/permissions/) applies to app use.

The Torah schedule was extracted from the card supplied for this user's personal study. See [source details](StudyData/SOURCES.md). Inter and Source Serif 4 in `Fonts` are used under the SIL Open Font License.
