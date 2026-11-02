# Local study data sources

This directory contains data extracted from PDFs supplied by the Selah user for personal study.

| Data file | Source | Coverage |
| --- | --- | --- |
| `torah-portions.json` | `Torah Portions 5787_DIGITAL.pdf` (2 pages, SHA-256 `DF021C325EE553C540A2B8454092CD493CA95519443AA1DDF16AAB8A7FAEAFBA`) | 51 dated rows representing the 54 numbered portions, including combined portions. |
| `torah-special-readings.json` | Same card | 12 festival readings listed on the card. |
| `romans-lessons.json` | `ROM_AdLessonsBook_00-30_062026_BLEEDv1 (1).pdf` (388 pages, SHA-256 `15234DA87C921D69C09FB77B50A4802D0A105308EAD9882819E5CAD706E7BF5D`) | Numbered questions for Lessons 1–30 and eight pages of notes each for Lessons 1–29. Lesson 30 has review questions and no following notes section. |

`BuildStudyData.py` regenerates these files from the PDFs. The Romans book states that BSF class members may use the material for their personal class studies and that other reproduction requires BSF's permission. Keep this extracted material local to that study use.

Romans lessons now change each **Wednesday** (Lesson 5 began Wednesday 14 October 2026); see `Get-BsfLessonForDate` in `StudyFeatures.ps1`.
