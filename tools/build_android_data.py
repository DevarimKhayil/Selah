#!/usr/bin/env python3
"""Generate the phone app's data files from the desktop app's data.

Reads (relative to the repository root):
  BibleData/*.json, BibleData/BSB/*.json   -> mobile/assets/www/bible/{KJV,BSB}/<Book>.js
  daily-verses.json + BSB chapter counts   -> mobile/assets/www/data/pool.js
  StudyData/romans-lessons.json (optional) -> mobile/assets/www/data/romans.js
  StudyData/torah-*.json (optional)        -> mobile/assets/www/data/torah.js

The Romans lessons and Torah card are personal study material and are NOT in the
public repository. When they are missing the phone app still builds and shows a
friendly "not included" message on those pages.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WWW = os.path.join(ROOT, 'mobile', 'assets', 'www')


def load(path):
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def main():
    books = load(os.path.join(ROOT, 'BibleData', 'Books.json'))
    counts = []
    for tr, folder in (('BSB', os.path.join(ROOT, 'BibleData', 'BSB')), ('KJV', os.path.join(ROOT, 'BibleData'))):
        for name in books:
            fn = name.replace(' ', '') + '.json'
            data = load(os.path.join(folder, fn))
            chapters = [[v['text'].strip() for v in c['verses']] for c in data['chapters']]
            if tr == 'BSB':
                counts.append(len(chapters))
            js = 'Selah.bookLoaded(%s,%s,%s);' % (json.dumps(tr), json.dumps(name),
                                                  json.dumps(chapters, ensure_ascii=False, separators=(',', ':')))
            write(os.path.join(WWW, 'bible', tr, fn.replace('.json', '.js')), js)
    pool = load(os.path.join(ROOT, 'daily-verses.json'))
    write(os.path.join(WWW, 'data', 'pool.js'),
          'Selah.data.pool=' + json.dumps(pool, ensure_ascii=False) + ';Selah.data.books=' + json.dumps(books) +
          ';Selah.data.chapters=' + json.dumps(counts) + ';')

    romans = os.path.join(ROOT, 'StudyData', 'romans-lessons.json')
    out = os.path.join(WWW, 'data', 'romans.js')
    if os.path.exists(romans):
        lessons = load(romans)
        for lesson in lessons:
            lesson.pop('questionsPdfPage', None)
            lesson.pop('notesPdfPage', None)
            for page in lesson.get('notesPages', []):
                page.pop('pdfPage', None)
        write(out, 'Selah.data.romans=' + json.dumps(lessons, ensure_ascii=False, separators=(',', ':')) + ';')
        print('romans.js: %d lessons' % len(lessons))
    elif os.path.exists(out):
        os.remove(out)

    portions = os.path.join(ROOT, 'StudyData', 'torah-portions.json')
    special = os.path.join(ROOT, 'StudyData', 'torah-special-readings.json')
    out = os.path.join(WWW, 'data', 'torah.js')
    if os.path.exists(portions):
        torah = {'portions': load(portions), 'special': load(special) if os.path.exists(special) else []}
        write(out, 'Selah.data.torah=' + json.dumps(torah, ensure_ascii=False) + ';')
        print('torah.js: %d portions' % len(torah['portions']))
    elif os.path.exists(out):
        os.remove(out)
    print('Bible data: %d books x 2 translations, %d daily verses' % (len(books), len(pool)))


if __name__ == '__main__':
    sys.exit(main())
