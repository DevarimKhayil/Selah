"""Extract the personal Torah reading card for Selah from the user's own PDF.

Usage: python BuildStudyData.py TORAH_PDF
The PDF remains with its owner; the derived JSON is for local use only.
"""

import json
import re
import sys
from datetime import date
from pathlib import Path

import pdfplumber


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


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python BuildStudyData.py TORAH_PDF")
    torah = build_torah(sys.argv[1])
    print(f"Torah rows: {len(torah)}; current week: {torah[1]['name']} on {torah[1]['date']}")
