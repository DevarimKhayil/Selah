"""Extract personal Selah study data from the two user-supplied PDFs.

Usage: python BuildStudyData.py TORAH_PDF ROMANS_PDF
The PDFs remain with their owner; derived JSON is for their local BSF study.
"""

import json
import re
import sys
from datetime import date
from pathlib import Path

import pdfplumber
from pypdf import PdfReader


ROOT = Path(__file__).parent
DATA = ROOT / "StudyData"
DATA.mkdir(exist_ok=True)

NAMES = [
    "B'reisheet", "Noach", "Lech Lecha", "Vayera", "Chayei Sarah", "Toldot",
    "Vayetze", "Vayishlach", "Vayeshev", "Miketz", "Vayigash", "Vayechi",
    "Shemot", "Va'era", "Bo", "Beshalach", "Yitro", "Mishpatim", "Terumah",
    "Tetzaveh", "Ki Tisa", "Vayak'hel", "Pekudei", "Vayikra", "Tzav",
    "Sh'mini", "Tazria", "Metzora", "Acharei Mot", "Kedoshim", "Emor",
    "Behar", "Bechukotai", "Bamidbar", "Nasso", "Beha'alotcha", "Shelach",
    "Korach", "Chukat-Balak", "Pinchas", "Mattot-Massei", "Devarim",
    "Va'etchanan", "Ekev", "Re'eh", "Shoftim", "Ki Tetze", "Ki Tavo",
    "Nitzavim-Vayelech", "Ha'azinu", "Vezot Ha'Bracha",
]

MONTHS = {
    "oct": 10, "nov": 11, "dec": 12, "jan": 1, "feb": 2, "mar": 3,
    "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9,
}

TITLES = [
    "Humanity's Need for the Gospel", "God's Wrath Against Sinful Humanity",
    "No Excuse for Anyone", "No One Righteous", "How God Saves Sinners",
    "Justification by Faith, Part 1", "Justification by Faith, Part 2",
    "Peace with God", "God's Gift of Righteousness", "Death to Sin",
    "Alive to God", "The Law and the Believer", "Life Through the Spirit",
    "Suffering and Glory", "Secure in God's Love",
    "God's Sovereignty in Salvation", "Our Responsibility in Salvation",
    "Our Privilege in Salvation", "Salvation for the Gentiles and for Israel",
    "All Glory to God Forever", "Christian Worship and Service",
    "Christian Love", "Christian Submission to Authority", "Christian Living",
    "Christian Liberty", "Christian Unity", "Paul's Ministry and Plans",
    "The Gospel's Impact in Rome and Corinth",
    "Responding to the World's Most Influential Letter",
    "Reflections on This Year's Study",
]

BOOKS = json.loads((ROOT / "BibleData" / "Books.json").read_text(encoding="utf-8"))
book_names = sorted(set(BOOKS + ["Psalm"]), key=len, reverse=True)
BOOK_PATTERN = "|".join(re.escape(book) for book in book_names)
REF_PATTERN = re.compile(
    rf"\b(?:{BOOK_PATTERN})\s+\d+(?::\d+(?:\s*[-–]\s*(?:\d+:)?\d+)?)?(?:\s*[-–]\s*\d+)?",
    re.IGNORECASE,
)


def references(text):
    found = []
    for match in REF_PATTERN.finditer(text):
        value = re.sub(r"\s+", " ", match.group()).strip().rstrip(".,;)")
        if value not in found:
            found.append(value)
    return found


def torah_book(index):
    if index <= 12:
        return "Genesis"
    if index <= 23:
        return "Exodus"
    if index <= 33:
        return "Leviticus"
    if index <= 43:
        return "Numbers"
    return "Deuteronomy"


def christian_numbering(ref):
    # The card puts Christian-published numbering in parentheses where it differs.
    ref = re.sub(r"(\d+):\d+\((\d+)\)", r"\1:\2", ref)
    ref = re.sub(r"\d+:\d+\((\d+:\d+)\)", r"\1", ref)
    return ref


def normalize_book_reference(value):
    value = value.replace("�", "–").replace("*", "").strip()
    value = re.sub(r"\s+", " ", value)
    aliases = [
        (r"^1\s+sam\.?", "1 Samuel"), (r"^2\s+sam\.?", "2 Samuel"),
        (r"^1\s+k(?:g|ing)s?\.?", "1 Kings"),
        (r"^2\s+k(?:g|ing)s?\.?", "2 Kings"),
        (r"^isa\.?", "Isaiah"), (r"^jer\.?", "Jeremiah"),
        (r"^eze\.?", "Ezekiel"), (r"^mal\.?", "Malachi"),
        (r"^hos\.?", "Hosea"), (r"^oba\.?", "Obadiah"),
        (r"^zec\.?", "Zechariah"), (r"^jdg\.?", "Judges"),
        (r"^amos?\.?", "Amos"), (r"^mic\.?", "Micah"),
        (r"^josh\.?", "Joshua"), (r"^hab\.?", "Habakkuk"),
        (r"^mt\.?", "Matthew"), (r"^mk\.?", "Mark"),
        (r"^lk\.?", "Luke"), (r"^jn\.?", "John"),
        (r"^acts\.?", "Acts"),
    ]
    for pattern, book in aliases:
        updated, count = re.subn(pattern, book, value, count=1, flags=re.I)
        if count:
            return christian_numbering(updated)
    return christian_numbering(value)


def build_torah(path):
    rows = []
    with pdfplumber.open(path) as pdf:
        for page_number, page in enumerate(pdf.pages):
            words = page.extract_words(x_tolerance=1, y_tolerance=1)
            bounds = ([48, 104, 160, 218, 295, 394] if page_number == 0
                      else [49, 115, 167, 214, 296, 379])
            markers = [w for w in words if 20 < w["x0"] < 49
                       and re.fullmatch(r"\d+(?:.\d+)?", w["text"])
                       and (w["top"] > 330 if page_number == 0 else w["top"] < 745)]
            for marker in markers:
                cells = [[] for _ in range(7)]
                for word in words:
                    if abs(word["top"] - marker["top"]) > 1.4:
                        continue
                    x = word["x0"]
                    col = next((i for i, limit in enumerate(bounds) if x < limit), 6)
                    cells[col].append(word["text"])
                row_number = len(rows) + 1
                date_words = " ".join(cells[2])
                date_match = re.search(r"(\d{1,2})\s+([A-Za-z]+)\.?.*?(\d{2})$", date_words)
                if not date_match:
                    raise ValueError(f"Cannot read Torah date {row_number}: {date_words!r}")
                day, month, year = date_match.groups()
                on_date = date(2000 + int(year), MONTHS[month[:3].lower()], int(day))
                raw_torah = " ".join(cells[4]).replace("�", "–").replace("*", "")
                passage = re.sub(r"^[A-Za-z.]+\s*", "", raw_torah).strip()
                passage = christian_numbering(passage)
                rows.append({
                    "number": marker["text"].replace("�", "–"),
                    "name": NAMES[row_number - 1],
                    "date": on_date.isoformat(),
                    "hebrewDateOnCard": " ".join(cells[3]),
                    "torah": f"{torah_book(int(re.match(r'\d+', marker['text']).group()))} {passage}",
                    "haftarah": normalize_book_reference(" ".join(cells[5])),
                    "gospel": normalize_book_reference(" ".join(cells[6])),
                    "sourcePage": page_number + 1,
                })
    if len(rows) != 51 or rows[0]["date"] != "2026-10-10" or rows[-1]["date"] != "2027-10-24":
        raise ValueError("Torah schedule did not match the supplied card")
    for i in range(1, len(rows)):
        if rows[i]["date"] <= rows[i - 1]["date"]:
            raise ValueError(f"Torah dates are out of order at {rows[i]['name']}")
    # This Haftarah wraps onto a second line in the card and evades row extraction.
    next(row for row in rows if row["number"] == "53")["haftarah"] = "Hosea 14:1–9; Joel 2:15–27"
    (DATA / "torah-portions.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")

    specials = [
        ("Pesach I", "2027-04-22", "Exodus 12:21–51", "Joshua 3:5–7, 5:2–6:1, 6:27", "John 19:31–20:1", 2),
        ("Pesach II", "2027-04-23", "Leviticus 22:26–23:44", "2 Kings 23:1–9, 21–25", "Mark 16:1–8", 2),
        ("Pesach VII", "2027-04-28", "Exodus 13:17–15:26", "2 Samuel 22:1–51", "John 20:1–14", 2),
        ("Pesach VIII", "2027-04-29", "Deuteronomy 15:19–16:17", "Isaiah 10:32–12:6", "John 20:15–20", 2),
        ("Shavuot I", "2027-06-11", "Exodus 19:1–20:23", "Ezekiel 1:1–28, 3:12", "Acts 2:1–21", 2),
        ("Shavuot II", "2027-06-12", "Deuteronomy 14:22–16:17", "Habakkuk 3:1–19", "Acts 2:21–42", 2),
        ("Rosh Hashanah I", "2027-10-02", "Genesis 21:1–34", "1 Samuel 1:1–2:10", "Luke 1:39–55", 2),
        ("Rosh Hashanah II", "2027-10-03", "Genesis 22:1–24", "Jeremiah 31:2–20", "Matthew 24:29–36", 2),
        ("Yom Kippur", "2027-10-11", "Leviticus 16:1–34", "Isaiah 57:14–58:14", "Matthew 25:31–46", 2),
        ("Sukkot I", "2027-10-16", "Leviticus 22:26–23:44", "Zechariah 14:1–21", "Luke 2:1–20", 2),
        ("Sukkot II", "2027-10-17", "Leviticus 22:26–23:44", "1 Kings 8:2–21", "John 7:1–10", 2),
        ("Sh'mini Atzeret", "2027-10-23", "Deuteronomy 14:22–16:17", "1 Kings 8:54–66", "Luke 2:21–32", 2),
    ]
    special_data = [dict(zip(("name", "date", "torah", "haftarah", "gospel", "sourcePage"), item)) for item in specials]
    (DATA / "torah-special-readings.json").write_text(json.dumps(special_data, ensure_ascii=False, indent=2), encoding="utf-8")
    return rows


def load_pages(path):
    reader = PdfReader(path)
    return {i: page.extract_text(extraction_mode="layout") or ""
            for i, page in enumerate(reader.pages, 1)}


def tidy(line):
    line = re.sub(r"(?<=\d)�(?=\d)", "–", line)
    return re.sub(r"\s+", " ", line.strip()).replace("�", "’")


def parse_questions(pages, start, number):
    questions = []
    day = ""
    instruction = ""
    current = None
    active = False
    for page_number in range(start, start + 3):
        for raw in pages[page_number].splitlines():
            line = tidy(raw)
            if not line:
                continue
            day_match = re.match(r"^(First|Second|Third|Four\s*th|Fifth|Sixth) Day:\s*(.*)$", line, re.I)
            if day_match:
                if current:
                    questions.append(current)
                    current = None
                day = re.sub(r"\s+", "", day_match.group(1)).title() + " Day"
                instruction = day_match.group(2)
                active = True
                continue
            if not active:
                continue
            if (re.match(r"^(?:\d+\s*\|\s*Lesson|Lesson\s+\d+\s*\|\s*\d+|Bible Study Fellowship\s*\|)", line)
                    or line.startswith(("Homiletics", "Next step:", "© BSF"))):
                continue
            question_match = re.match(r"^(\d{1,2})\.\s+(.*)", line)
            if question_match:
                if current:
                    questions.append(current)
                current = {"number": int(question_match.group(1)), "day": day,
                           "instruction": instruction, "lines": [question_match.group(2)]}
                continue
            if current:
                current["lines"].append(line)
    if current:
        questions.append(current)
    for q in questions:
        q["text"] = "\n".join(q.pop("lines"))
        q["references"] = references(q["instruction"] + " " + q["text"])
    expected = list(range(1, len(questions) + 1))
    got = [q["number"] for q in questions]
    if got != expected or len(questions) < 10:
        raise ValueError(f"Lesson {number} question numbering: {got}")
    return questions


def parse_note_page(text, lesson, page_number):
    lines = []
    last_blank = True
    for raw in text.splitlines():
        line = tidy(raw)
        if re.match(rf"^(?:Lesson {lesson} Notes|\d+\s*\|\s*Lesson {lesson}|Bible Study Fellowship\s*\|\s*\d+)$", line):
            continue
        if not line:
            if not last_blank and lines:
                lines.append("")
            last_blank = True
        else:
            lines.append(line)
            last_blank = False
    return {"pdfPage": page_number, "printedPage": page_number - 16,
            "text": "\n".join(lines).strip()}


def build_romans(path):
    pages = load_pages(path)
    question_starts = {}
    note_starts = {}
    for page_number, body in pages.items():
        for m in re.finditer(r"(?m)^\s*Lesson\s+(\d+)\s+Questions\s*$", body):
            question_starts[int(m.group(1))] = page_number
        for m in re.finditer(r"(?m)^\s*Lesson\s+(\d+)\s+Notes\s*$", body):
            note_starts[int(m.group(1))] = page_number
    question_starts[30] = 383  # The last chapter is titled "Study Review Questions."
    if set(question_starts) != set(range(1, 31)) or set(note_starts) != set(range(1, 30)):
        raise ValueError("Romans lesson sections could not be located")
    lessons = []
    for number in range(1, 31):
        start = question_starts[number]
        questions = parse_questions(pages, start, number)
        notes = ([parse_note_page(pages[p], number, p) for p in range(note_starts[number], note_starts[number] + 8)]
                 if number < 30 else [])
        note_heading = pages[note_starts[number]] if number < 30 else ""
        scripture_match = re.search(r"(?m)^\s*(Romans\s+[\d:–-]+)\s*$", note_heading)
        scripture = scripture_match.group(1).strip() if scripture_match else "Various"
        lessons.append({"number": number, "title": TITLES[number - 1],
                        "scripture": scripture, "questionsPdfPage": start,
                        "questions": questions, "notesPdfPage": note_starts.get(number),
                        "notesPages": notes})
    (DATA / "romans-lessons.json").write_text(json.dumps(lessons, ensure_ascii=False, indent=2), encoding="utf-8")
    return lessons


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python BuildStudyData.py TORAH_PDF ROMANS_PDF")
    torah = build_torah(sys.argv[1])
    romans = build_romans(sys.argv[2])
    print(f"Torah rows: {len(torah)}; current week: {torah[1]['name']} on {torah[1]['date']}")
    print("Romans lessons:", len(romans), "question counts:", [len(x["questions"]) for x in romans])
