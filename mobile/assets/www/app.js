/* Selah for Android — Scripture, remembered.
   A phone port of the Selah desktop app. Everything runs offline; state lives in localStorage. */
(function () {
'use strict';
var S = window.Selah;
var Android = window.SelahAndroid || null;

// ------------------------------------------------------------------ helpers
function $(id) { return document.getElementById(id); }
function el(tag, attrs, kids) {
  var n = document.createElement(tag);
  if (attrs) for (var k in attrs) {
    var v = attrs[k];
    if (v === null || v === undefined || v === false) continue;
    if (k === 'class') n.className = v;
    else if (k === 'text') n.textContent = v;
    else if (k === 'html') n.innerHTML = v;
    else if (k.slice(0, 2) === 'on') n.addEventListener(k.slice(2), v);
    else n.setAttribute(k, v === true ? '' : v);
  }
  (kids || []).forEach(function (c) { if (c !== null && c !== undefined && c !== false) n.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
  return n;
}
var ICONS = {
  home: '<path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z"/>',
  book: '<path d="M12 6.5C10 5 7 4.5 4 5v13c3-.5 6 0 8 1.5 2-1.5 5-2 8-1.5V5c-3-.5-6 0-8 1.5z"/><path d="M12 6.5V19"/>',
  library: '<path d="M5 4h3v16H5zM10 4h3v16h-3z"/><path d="m15.5 4.8 2.9-.8 3.6 15.4-2.9.8z"/>',
  school: '<path d="m2 9 10-5 10 5-10 5z"/><path d="M6 11v5c2 2 10 2 12 0v-5"/><path d="M22 9v6"/>',
  more: '<circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  star: '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
  refresh: '<path d="M20 11a8 8 0 0 0-14.5-4.5L4 8"/><path d="M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.5 4.5L20 16"/><path d="M20 20v-4h-4"/>',
  external: '<path d="M14 4h6v6"/><path d="M20 4 11 13"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  pen: '<path d="m4 20 1-4L16.5 4.5a2.1 2.1 0 0 1 3 3L8 19z"/><path d="m14.5 6.5 3 3"/>',
  note: '<path d="M6 3h9l4 4v14H6z"/><path d="M15 3v4h4M9 12h7M9 16h5"/>',
  calendar: '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  chevL: '<path d="m15 5-7 7 7 7"/>',
  chevR: '<path d="m9 5 7 7-7 7"/>',
  chevD: '<path d="m6 9 6 6 6-6"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  bulb: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  clock: '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>',
  share: '<path d="M12 3v12"/><path d="m7 8 5-5 5 5"/><path d="M5 14v5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-5"/>',
  download: '<path d="M12 4v11"/><path d="m7 10 5 5 5-5"/><path d="M5 20h14"/>',
  upload: '<path d="M12 15V4"/><path d="m7 9 5-5 5 5"/><path d="M5 20h14"/>',
  bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  palette: '<path d="M12 3a9 9 0 1 0 0 18c1 0 1.5-.8 1.5-1.5 0-1.2-1-1.5-1-2.5s.8-1.5 1.8-1.5H17a4 4 0 0 0 4-4c0-4.7-4-8.5-9-8.5z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7.5" r="1"/>'
};
function icon(name) {
  var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('class', 'i');
  s.innerHTML = ICONS[name] || '';
  return s;
}
function iconTile(name, color) { return el('div', { class: 'tile-icon ' + color }, [icon(name)]); }
var toastTimer = null;
function toast(msg) {
  var t = $('toast'); t.textContent = msg; t.classList.add('on');
  clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.classList.remove('on'); }, 2600);
}
function pad(n) { return n < 10 ? '0' + n : '' + n; }
function isoDate(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
var MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
var DAYS = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
function longDate(d) { return DAYS[d.getDay()] + ', ' + d.getDate() + ' ' + MONTHS[d.getMonth()] + ' ' + d.getFullYear(); }
function shortDate(d) { return d.getDate() + ' ' + MONTHS[d.getMonth()].slice(0, 3); }
function parseIso(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
function uid() { return Date.now().toString(16) + Math.random().toString(16).slice(2, 10); }
function debounce(fn, ms) { var t; return function () { var a = arguments, me = this; clearTimeout(t); t = setTimeout(function () { fn.apply(me, a); }, ms); }; }

// ------------------------------------------------------------------ state
var POOL_VERSION = 2;
var st = {
  version: 1, verses: [], reflections: [], bibleNotes: [], delivered: [], dailyUsed: [], bsfAnswers: [],
  focusId: '', focusSince: '', offerDailyWhenNoFocus: true, daily: null, dailyPoolVersion: POOL_VERSION,
  theme: 'Light', translation: 'BSB', remindersOn: true, dailyPlan: {}, dailyNotifyOn: true, dailyNotifyTime: '06:30'
};
function loadState() {
  try {
    var raw = JSON.parse(localStorage.getItem('selah.state') || 'null');
    if (raw) for (var k in raw) st[k] = raw[k];
  } catch (e) { toast('Saved data could not be read.'); }
  ['verses','reflections','bibleNotes','delivered','dailyUsed','bsfAnswers'].forEach(function (k) { if (!Array.isArray(st[k])) st[k] = []; });
  if (st.dailyPoolVersion !== POOL_VERSION) { st.dailyUsed = []; st.daily = null; st.dailyPoolVersion = POOL_VERSION; }
  if (!st.dailyPlan || typeof st.dailyPlan !== 'object') st.dailyPlan = {};
  if (!st.highlights || typeof st.highlights !== 'object') st.highlights = {};
  var OLD_HL = { yellow: 'honey', orange: 'apricot', pink: 'blush', red: 'coral', purple: 'lilac', blue: 'sky', teal: 'aqua', green: 'mint', olive: 'sage', gray: 'sand' };
  for (var hk in st.highlights) if (OLD_HL[st.highlights[hk].color]) st.highlights[hk].color = OLD_HL[st.highlights[hk].color];
  if (st.delivered.length > 400) st.delivered = st.delivered.slice(-200);
}
function save() {
  try { localStorage.setItem('selah.state', JSON.stringify(st)); }
  catch (e) { toast('Could not save — storage is full.'); }
}

// ------------------------------------------------------------------ Bible data
var BOOKS = S.data.books;
var ALIASES = { 'psalm': 'Psalms', 'song of songs': 'Song of Solomon', 'revelations': 'Revelation' };
function resolveBook(name) {
  if (!name) return null;
  var n = name.replace(/\s+/g, ' ').trim().toLowerCase();
  if (ALIASES[n]) return ALIASES[n];
  for (var i = 0; i < BOOKS.length; i++) if (BOOKS[i].toLowerCase() === n) return BOOKS[i];
  return null;
}
function displayBook(b) { return b === 'Psalms' ? 'Psalm' : b; }
function trName(code) { return code === 'KJV' ? 'King James Version' : 'Berean Standard Bible'; }
function loadBook(book, tr) {
  tr = tr === 'KJV' ? 'KJV' : 'BSB';
  var key = tr + '|' + book;
  return new Promise(function (resolve, reject) {
    if (S.bible[key]) return resolve(S.bible[key]);
    if (S.waiting[key]) { S.waiting[key].push(resolve); return; }
    S.waiting[key] = [resolve];
    var sc = document.createElement('script');
    sc.src = 'bible/' + tr + '/' + book.replace(/\s/g, '') + '.js';
    sc.onerror = function () { delete S.waiting[key]; reject(new Error('Missing ' + book)); };
    document.head.appendChild(sc);
  });
}

// Parse "John 1:12; 3:14-18, 20" etc. into passages {title, book, verses:[{c,v,t}], error}
function parsePassages(reference, tr) {
  var clean = reference.replace(/\s*[–—-]\s*/g, '-');
  var segments = clean.split(/[;,]\s*/);
  var bookCtx = '', chapCtx = 0, specs = [];
  segments.forEach(function (seg) {
    seg = seg.trim().replace(/[.)]+$/, '').replace(/^\(/, '').replace(/(\d)[a-c]\b/g, '$1');
    if (!seg) return;
    if (/^\d+(?:-\d+)?$/.test(seg) && bookCtx && chapCtx > 0) seg = bookCtx + ' ' + chapCtx + ':' + seg;
    else if (/^\d+(?::\d+)?(?:-.*)?$/.test(seg) && bookCtx) seg = bookCtx + ' ' + seg;
    var m = seg.match(/^(.+?)\s+(\d+)(?::(\d+))?(?:-(?:(\d+):)?(\d+))?$/);
    if (!m) { specs.push({ title: seg, error: 'Could not read reference: ' + seg }); return; }
    bookCtx = m[1].trim();
    var sc = +m[2], sv = m[3] ? +m[3] : 1, ec = sc, ev = Infinity;
    if (m[4]) { ec = +m[4]; ev = +m[5]; }
    else if (m[5]) { if (m[3]) ev = +m[5]; else ec = +m[5]; }
    else if (m[3]) ev = sv;
    chapCtx = m[3] ? ec : 0;
    var book = resolveBook(bookCtx);
    if (!book || ec < sc || ec - sc > 15) { specs.push({ title: seg, error: 'Could not load passage: ' + seg }); return; }
    specs.push({ title: seg.replace(/^Psalms\b/, 'Psalm'), book: book, sc: sc, sv: sv, ec: ec, ev: ev });
  });
  return Promise.all(specs.map(function (sp) {
    if (sp.error) return Promise.resolve({ title: sp.title, verses: [], error: sp.error });
    return loadBook(sp.book, tr).then(function (chs) {
      var verses = [];
      for (var c = sp.sc; c <= sp.ec && c <= chs.length; c++) {
        var arr = chs[c - 1];
        for (var v = 1; v <= arr.length; v++) {
          if (c === sp.sc && v < sp.sv) continue;
          if (c === sp.ec && v > sp.ev) continue;
          verses.push({ c: c, v: v, t: arr[v - 1] });
        }
      }
      return { title: sp.title, book: sp.book, verses: verses, error: verses.length ? '' : 'No verses found for this reference.' };
    }, function () { return { title: sp.title, verses: [], error: 'Could not load passage: ' + sp.title }; });
  }));
}
function verseText(reference, tr) {
  return parsePassages(reference, tr || st.translation).then(function (ps) {
    return ps.map(function (p) { return p.verses.map(function (v) { return v.t; }).join(' '); }).join(' ').trim();
  });
}
function nivUrl(ref) { return 'https://www.biblegateway.com/passage/?search=' + encodeURIComponent(ref.trim()) + '&version=NIV'; }
function openUrl(url) { if (Android && Android.openUrl) Android.openUrl(url); else window.open(url, '_blank'); }

// Reference detection in free text (port of Find-ScriptureReferences)
var refRe, itemRe, ctxRe;
(function buildRegexes() {
  var names = BOOKS.concat(['Psalm', 'Song of Songs']).sort(function (a, b) { return b.length - a.length; });
  var bookPat = names.map(function (n) { return n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/ /g, '\\s+'); }).join('|');
  var dash = '\\s*[-–—]\\s*';
  var range = '\\d+(?::\\d+[a-c]?)?(?:' + dash + '\\d+(?::\\d+)?[a-c]?)?';
  var notBook = '(?!\\s+(?:Samuel|Kings|Chronicles|Corinthians|Thessalonians|Timothy|Peter|John)\\b)';
  var item = '(?:\\d+:\\d+[a-c]?|\\d+)(?:' + dash + '\\d+(?::\\d+)?[a-c]?)?' + notBook;
  refRe = new RegExp('(^|[^\\w])(' + bookPat + ')\\s+(' + range + ')((?:\\s*[,;]\\s*' + item + ')*)', 'g');
  itemRe = new RegExp('(\\s*[,;]\\s*)((?:\\d+:\\d+[a-c]?|\\d+)(?:' + dash + '\\d+(?::\\d+)?[a-c]?)?)', 'g');
  ctxRe = new RegExp('(^|[^\\w])((?:[Vv]erses?|vv?\\.)\\s+(\\d+)[a-c]?(?:' + dash + '(\\d+)[a-c]?)?)(?![\\d:])', 'g');
})();
function findRefs(text, ctxBook, ctxChap) {
  var explicit = [];
  if (!text) return { links: [], book: ctxBook || '', chapter: ctxChap || 0 };
  refRe.lastIndex = 0;
  var m;
  while ((m = refRe.exec(text))) {
    var book = resolveBook(m[2]); if (!book) continue;
    var disp = displayBook(book);
    var start = m.index + m[1].length;
    var first = m[3].replace(/\s*[–—-]\s*/g, '-');
    var chap = +first.split(/[:-]/)[0];
    explicit.push({ index: start, length: m[2].length + (m[0].length - m[1].length - m[2].length - m[4].length), reference: disp + ' ' + first, book: book, chapter: chap });
    var verseMode = first.indexOf(':') >= 0;
    var cross = first.match(/-(\d+):/); if (cross) chap = +cross[1];
    var restStart = m.index + m[0].length - m[4].length;
    itemRe.lastIndex = 0;
    var im;
    while ((im = itemRe.exec(m[4]))) {
      var val = im[2].replace(/\s*[–—-]\s*/g, '-'), ref;
      var cm = val.match(/^(\d+):/);
      if (cm) { chap = +cm[1]; verseMode = true; ref = disp + ' ' + val; var cr = val.match(/-(\d+):/); if (cr) chap = +cr[1]; }
      else if (verseMode) ref = disp + ' ' + chap + ':' + val;
      else { chap = +val.split('-')[0]; ref = disp + ' ' + val; }
      explicit.push({ index: restStart + im.index + im[1].length, length: im[2].length, reference: ref, book: book, chapter: chap });
    }
  }
  explicit.sort(function (a, b) { return a.index - b.index; });
  var contextual = [];
  ctxRe.lastIndex = 0;
  while ((m = ctxRe.exec(text))) {
    var s = m.index + m[1].length, len = m[2].length;
    if (explicit.some(function (e) { return s < e.index + e.length && e.index < s + len; })) continue;
    var prior = null;
    explicit.forEach(function (e) { if (e.index < s) prior = e; });
    var b = prior ? prior.book : ctxBook, c = prior ? prior.chapter : ctxChap;
    if (!b || !(c > 0)) continue;
    var vs = m[4] ? m[3] + '-' + m[4] : m[3];
    contextual.push({ index: s, length: len, reference: displayBook(b) + ' ' + c + ':' + vs, book: b, chapter: c });
  }
  var all = explicit.concat(contextual).sort(function (a, b) { return a.index - b.index; });
  var last = explicit.length ? explicit[explicit.length - 1] : null;
  return { links: all, book: last ? last.book : (ctxBook || ''), chapter: last ? last.chapter : (ctxChap || 0) };
}
function refContext(reference) {
  var f = findRefs(reference || '');
  return f.links.length ? { book: f.links[0].book, chapter: f.links[0].chapter } : { book: '', chapter: 0 };
}
// Append text with clickable references into a parent node; returns the running context.
function linkify(parent, text, ctxBook, ctxChap) {
  var f = findRefs(text, ctxBook, ctxChap), pos = 0;
  f.links.forEach(function (l) {
    if (l.index < pos) return;
    if (l.index > pos) parent.appendChild(document.createTextNode(text.slice(pos, l.index)));
    var a = el('a', { href: '#', text: text.substr(l.index, l.length), onclick: function (e) { e.preventDefault(); showScripture(l.reference); } });
    parent.appendChild(a);
    pos = l.index + l.length;
  });
  if (pos < text.length) parent.appendChild(document.createTextNode(text.slice(pos)));
  return f;
}
function refChip(reference) {
  return el('button', { class: 'chip', onclick: function () { showScripture(reference); } }, [icon('book'), reference]);
}

// ------------------------------------------------------------------ Hebrew date
var HEB_FIX = { 'Tishri': 'Tishrei', 'Heshvan': 'Cheshvan', 'Tamuz': 'Tammuz' };
function hebrewDate(d) {
  try {
    var parts = new Intl.DateTimeFormat('en-u-ca-hebrew', { day: 'numeric', month: 'long', year: 'numeric' }).formatToParts(d);
    var day = '', month = '', year = '';
    parts.forEach(function (p) { if (p.type === 'day') day = p.value; else if (p.type === 'month') month = p.value; else if (p.type === 'year' || p.type === 'relatedYear') year = year || p.value; });
    month = HEB_FIX[month] || month;
    return day + ' ' + month + ' ' + year;
  } catch (e) { return ''; }
}

// ------------------------------------------------------------------ daily verse
var dailyCache = {};
function ensureDaily() {
  var today = isoDate(new Date()), pool = S.data.pool;
  if (!(st.daily && st.daily.date === today) && st.dailyPlan[today] !== undefined && st.dailyPlan[today] < pool.length) {
    st.daily = { date: today, index: st.dailyPlan[today] };
  }
  if (st.daily && st.daily.date === today && st.daily.index >= 0 && st.daily.index < pool.length) {
    if (st.dailyUsed.indexOf(st.daily.index) < 0) { st.dailyUsed.push(st.daily.index); save(); }
    st.dailyPlan[today] = st.daily.index;
    return;
  }
  pickDaily(st.daily ? st.daily.index : -1);
}
// Plan the next 60 days of verses so the phone can show them in notifications and the widget
// even when Selah is closed. Future picks avoid verses already seen or already planned.
var PLAN_DAYS = 60;
function planAhead() {
  var pool = S.data.pool, today = new Date(), planned = {}, k;
  for (k in st.dailyPlan) if (k < isoDate(today)) delete st.dailyPlan[k];
  for (k in st.dailyPlan) planned[st.dailyPlan[k]] = true;
  for (var d = 1; d < PLAN_DAYS; d++) {
    var key = isoDate(addDays(today, d));
    if (st.dailyPlan[key] !== undefined) continue;
    var choices = [];
    for (var i = 0; i < pool.length; i++) if (!planned[i] && st.dailyUsed.indexOf(i) < 0) choices.push(i);
    if (!choices.length) for (var j = 0; j < pool.length; j++) if (!planned[j]) choices.push(j);
    if (!choices.length) for (var x = 0; x < pool.length; x++) choices.push(x);
    var pick = choices[Math.floor(Math.random() * choices.length)];
    st.dailyPlan[key] = pick; planned[pick] = true;
  }
  save();
}
var lastPlanKey = '';
function pushDailyToPhone(force) {
  if (!Android || !Android.setDailyPlan) return;
  planAhead();
  var dates = Object.keys(st.dailyPlan).sort();
  var key = st.translation + '|' + dates.map(function (dt) { return dt + '=' + st.dailyPlan[dt]; }).join(',');
  if (!force && key === lastPlanKey) { Android.setDailySchedule(!!st.dailyNotifyOn, st.dailyNotifyTime || '06:30'); return; }
  lastPlanKey = key;
  Promise.all(dates.map(function (dt) { return getDaily(st.dailyPlan[dt]).then(function (v) { return { date: dt, reference: v.reference, text: v.text }; }); }))
    .then(function (list) {
      Android.setDailyPlan(JSON.stringify(list), trName(st.translation));
      Android.setDailySchedule(!!st.dailyNotifyOn, st.dailyNotifyTime || '06:30');
    });
}
function pickDaily(current) {
  var pool = S.data.pool;
  if (st.dailyUsed.length >= pool.length) st.dailyUsed = [];
  var choices = [];
  var future = {}; for (var dk in st.dailyPlan) if (dk > isoDate(new Date())) future[st.dailyPlan[dk]] = true;
  for (var i = 0; i < pool.length; i++) if (st.dailyUsed.indexOf(i) < 0 && i !== current && !future[i]) choices.push(i);
  if (!choices.length) for (var j = 0; j < pool.length; j++) if (j !== current) choices.push(j);
  var idx = choices[Math.floor(Math.random() * choices.length)];
  st.dailyUsed.push(idx);
  st.daily = { date: isoDate(new Date()), index: idx };
  st.dailyPlan[st.daily.date] = idx;
  save();
  pushDailyToPhone(false);
}
function getDaily(index) {
  if (index === undefined) index = st.daily.index;
  var entry = S.data.pool[index], key = st.translation + '|' + index;
  if (dailyCache[key]) return Promise.resolve(dailyCache[key]);
  return verseText(entry.reference).then(function (t) {
    if (entry.startsWith) { var at = t.indexOf(entry.startsWith); if (at > 0) t = t.slice(at); }
    dailyCache[key] = { reference: entry.reference, text: t.trim() };
    return dailyCache[key];
  });
}

// ------------------------------------------------------------------ verses & practice
function getVerse(id) { for (var i = 0; i < st.verses.length; i++) if (st.verses[i].id === id) return st.verses[i]; return null; }
function getFocus() { var v = getVerse(st.focusId); return v && !v.memorizedAt ? v : null; }
function setFocus(id) { var v = getVerse(id); if (!v || v.memorizedAt) return; st.focusId = id; st.focusSince = new Date().toISOString(); save(); refresh(); }
function addVerse(reference, text, makeFocus, source) {
  reference = (reference || '').trim(); text = (text || '').trim();
  if (!reference || !text) return null;
  if (makeFocus === undefined) makeFocus = true;
  for (var i = 0; i < st.verses.length; i++) {
    var ex = st.verses[i];
    if (ex.reference === reference && ex.text === text) { if (makeFocus && !ex.memorizedAt) setFocus(ex.id); return ex; }
  }
  var v = { id: uid(), reference: reference, text: text, addedAt: new Date().toISOString(), passes: 0, memorizedAt: null, lastReviewedAt: null, source: source || 'personal' };
  st.verses.push(v);
  if (makeFocus) setFocus(v.id); else { save(); refresh(); }
  return v;
}
function normalize(t) { return (t || '').toLowerCase().replace(/[\p{P}\p{S}]/gu, '').replace(/\s+/g, ' ').trim(); }
function liveWords(answer, verse) {
  var expected = verse.trim().split(/\s+/).filter(function (w) { return normalize(w); });
  var typed = answer.trim().split(/\s+/).filter(Boolean);
  if (!answer.trim()) return [];
  return typed.map(function (w, i) {
    var a = normalize(w), t = i < expected.length ? normalize(expected[i]) : '';
    var status = a && a === t ? 'correct' : (i === typed.length - 1 && !/\s$/.test(answer) && a && t.indexOf(a) === 0 ? 'partial' : 'wrong');
    return { word: w, status: status };
  });
}
function hintIndex(answer, verse) {
  var expected = verse.trim().split(/\s+/).filter(function (w) { return normalize(w); });
  var typed = answer.trim().split(/\s+/).filter(Boolean), i = 0;
  while (i < typed.length && i < expected.length && normalize(typed[i]) === normalize(expected[i])) i++;
  return i;
}
function nextHint(answer, verse, level) {
  var expected = verse.trim().split(/\s+/).filter(function (w) { return normalize(w); });
  var i = hintIndex(answer, verse);
  if (i >= expected.length) return 'You have reached the end. Check your answer.';
  if (level >= 2) return 'Hint: word ' + (i + 1) + ' is "' + expected[i].replace(/^[^\w]+|[^\w]+$/g, '') + '".';
  return 'Hint: word ' + (i + 1) + ' begins with "' + normalize(expected[i]).charAt(0).toUpperCase() + '". Tap Hint again to see the whole word.';
}
// Is this verse saved in the BSB or KJV wording, or in the user's own words?
function wordingSource(v) {
  var saved = normalize(v.text);
  return Promise.all(['BSB', 'KJV'].map(function (c) { return verseText(v.reference.replace(/^Psalms\b/, 'Psalm'), c).catch(function () { return ''; }); })).then(function (t) {
    var codes = ['BSB', 'KJV'];
    for (var i = 0; i < 2; i++) { var b = normalize(t[i]); if (b && b === saved) return { label: codes[i] + ' wording', own: false }; }
    for (var j = 0; j < 2; j++) { var b2 = normalize(t[j]); if (b2 && saved.length > 12 && b2.indexOf(saved) >= 0) return { label: 'Part of the ' + codes[j], own: false }; }
    return { label: 'Your own wording', own: true };
  });
}
function recordPass(v) {
  if (v.memorizedAt) { v.lastReviewedAt = new Date().toISOString(); save(); refresh(); return 'Passed! You still remember this verse.'; }
  v.passes = (v.passes || 0) + 1;
  var mastered = v.passes >= 3;
  if (mastered) {
    v.memorizedAt = new Date().toISOString();
    if (st.focusId === v.id) {
      st.focusId = ''; st.focusSince = '';
      for (var i = 0; i < st.verses.length; i++) { var c = st.verses[i]; if (!c.memorizedAt && c.source !== 'daily') { st.focusId = c.id; st.focusSince = new Date().toISOString(); break; } }
    }
  }
  save(); refresh();
  return mastered ? 'Beautifully done. This verse is now in your memorized collection.' : 'Passed! ' + v.passes + ' of 3 correct recitations completed.';
}
function todaysPracticeVerse(d) {
  if (!d) return null;
  for (var i = 0; i < st.verses.length; i++) if (st.verses[i].reference === d.reference && st.verses[i].text === d.text) return st.verses[i];
  return null;
}
function doneToday(v, now) {
  if (!v) return false;
  return [v.memorizedAt, v.lastReviewedAt].some(function (s) { return s && isoDate(new Date(s)) === isoDate(now); });
}

// ------------------------------------------------------------------ sheets
var sheetStack = [];
function openSheet(opts) {
  var sheet = el('div', { class: 'sheet' + (opts.full ? ' full' : '') });
  var grabZone = el('div', { class: 'grab-zone' }, [el('div', { class: 'grab' })]);
  sheet.appendChild(grabZone);
  var head = el('div', { class: 'sheet-head' });
  if (opts.tile) head.appendChild(opts.tile);
  var titles = el('div', { class: 'grow' }, [
    opts.caption ? el('div', { class: 'caption accent', text: opts.caption }) : null,
    el('div', { style: 'font-size:20px;font-weight:700;line-height:1.25', text: opts.title || '' })
  ]);
  head.appendChild(titles);
  if (opts.headExtra) head.appendChild(opts.headExtra);
  head.appendChild(el('button', { class: 'icon-btn', 'aria-label': 'Close', onclick: function () { closeSheet(); } }, [icon('close')]));
  sheet.appendChild(head);
  var body = el('div', { class: 'sheet-body' });
  sheet.appendChild(body);
  var foot = null;
  if (opts.foot !== false) { foot = el('div', { class: 'sheet-foot' }); sheet.appendChild(foot); }
  $('sheets').appendChild(sheet);
  $('scrim').classList.add('on');
  var rec = { sheet: sheet, body: body, foot: foot, head: head, titles: titles, onClose: opts.onClose };
  sheetStack.push(rec);
  enableDrag(rec, grabZone);
  enableDrag(rec, head);
  requestAnimationFrame(function () { requestAnimationFrame(function () { sheet.classList.add('on'); }); });
  return rec;
}
// Drag the handle (or the title area) down to close a sheet, like other Android apps.
function enableDrag(rec, handle) {
  var startY = 0, lastY = 0, lastT = 0, speed = 0, active = false, moved = false;
  function down(y) { startY = lastY = y; lastT = Date.now(); speed = 0; active = true; moved = false; rec.sheet.classList.add('dragging'); }
  function move(y, e) {
    if (!active) return;
    var dy = Math.max(0, y - startY), now = Date.now();
    if (dy > 4) moved = true;
    speed = (y - lastY) / Math.max(1, now - lastT); lastY = y; lastT = now;
    rec.sheet.style.transform = 'translateY(' + dy + 'px)';
    $('scrim').style.opacity = String(Math.max(0, 1 - dy / 500));
    if (moved && e && e.cancelable) e.preventDefault();
  }
  function up() {
    if (!active) return; active = false;
    var dy = Math.max(0, lastY - startY);
    rec.sheet.classList.remove('dragging');
    $('scrim').style.opacity = '';
    if (dy > 110 || (dy > 30 && speed > 0.6)) {
      rec.sheet.style.transform = '';
      if (sheetStack[sheetStack.length - 1] === rec) closeSheet();
    } else rec.sheet.style.transform = '';
  }
  handle.addEventListener('touchstart', function (e) { if (e.target.closest('button,input,textarea,.seg')) return; down(e.touches[0].clientY); }, { passive: true });
  handle.addEventListener('touchmove', function (e) { move(e.touches[0].clientY, e); }, { passive: false });
  handle.addEventListener('touchend', up);
  handle.addEventListener('touchcancel', up);
  handle.addEventListener('mousedown', function (e) { if (e.target.closest('button,input,textarea,.seg')) return; down(e.clientY);
    function mm(ev) { move(ev.clientY, ev); } function mu() { up(); window.removeEventListener('mousemove', mm); window.removeEventListener('mouseup', mu); }
    window.addEventListener('mousemove', mm); window.addEventListener('mouseup', mu); });
  // Also allow pulling down from the body when it is already scrolled to the top.
  var bodyStart = null;
  rec.body.addEventListener('touchstart', function (e) { bodyStart = rec.body.scrollTop <= 0 && !e.target.closest('input,textarea') ? e.touches[0].clientY : null; }, { passive: true });
  rec.body.addEventListener('touchmove', function (e) {
    if (bodyStart === null) return;
    var y = e.touches[0].clientY;
    if (!active && y - bodyStart > 12 && rec.body.scrollTop <= 0) down(bodyStart);
    if (active) move(y, e);
  }, { passive: false });
  rec.body.addEventListener('touchend', function () { bodyStart = null; up(); });
}
function closeSheet() {
  var rec = sheetStack.pop(); if (!rec) return false;
  rec.sheet.classList.remove('on');
  if (!sheetStack.length) $('scrim').classList.remove('on');
  setTimeout(function () { rec.sheet.remove(); }, 260);
  if (rec.onClose) rec.onClose();
  return true;
}
$('scrim').addEventListener('click', function () { closeSheet(); });

// Scripture reader
function showScripture(reference) {
  var tr = st.translation;
  var seg = el('div', { class: 'seg' });
  var rec = openSheet({ full: true, caption: trName(tr), title: reference.replace(/\bPsalms(?=\s+\d)/, 'Psalm'), tile: iconTile('book', 'c-purple'), headExtra: seg });
  function render(code) {
    tr = code;
    rec.titles.firstChild.textContent = trName(code);
    seg.innerHTML = '';
    ['BSB', 'KJV'].forEach(function (c) { seg.appendChild(el('button', { class: c === code ? 'on' : '', text: c, onclick: function () { render(c); } })); });
    rec.body.innerHTML = '<div class="muted">Loading…</div>';
    parsePassages(reference, code).then(function (ps) {
      var box = el('div', { class: 'scripture' });
      ps.forEach(function (p) {
        box.appendChild(el('div', { class: 'ptitle', text: p.title }));
        if (p.error) { box.appendChild(el('div', { class: 'muted', text: p.error })); return; }
        var para = el('div'), last = 0;
        p.verses.forEach(function (v) {
          if (last && v.c !== last) { box.appendChild(para); box.appendChild(el('div', { class: 'chap', text: 'Chapter ' + v.c })); para = el('div'); }
          para.appendChild(el('span', { class: 'sup', text: v.v }));
          para.appendChild(document.createTextNode(v.t + ' '));
          last = v.c;
        });
        box.appendChild(para);
      });
      rec.body.innerHTML = ''; rec.body.appendChild(box);
    });
  }
  render(tr);
  rec.foot.appendChild(el('button', { class: 'btn ghost', onclick: function () { openUrl(nivUrl(reference)); } }, ['Read in NIV', icon('external')]));
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Done', onclick: function () { closeSheet(); } }));
}

// Practice
var practiceOpen = false;
function showPractice(v, after) {
  if (!v || practiceOpen) return;
  practiceOpen = true;
  var rec = openSheet({ full: true, caption: 'Moment to remember', title: 'Type it from memory.', tile: iconTile('pen', 'c-blue'), onClose: function () { practiceOpen = false; if (after) after(); } });
  rec.body.appendChild(el('div', { class: 'muted small', text: 'Capital letters and punctuation do not matter. The words do.' }));
  var badge = el('span', { class: 'src-badge', text: '…' });
  rec.body.appendChild(el('div', { class: 'card soft', style: 'margin:12px 0;padding:12px 14px' }, [el('div', { class: 'spread' }, [el('div', { class: 'row', style: 'gap:8px' }, [el('span', { class: 'caption', text: 'Your verse' }), badge]), el('b', { style: 'color:var(--accent)', text: v.reference })])]));
  wordingSource(v).then(function (w) { badge.textContent = w.label; badge.className = 'src-badge' + (w.own ? ' own' : ''); peekCap.textContent = 'Peek · ' + w.label + ' · let go to hide'; });
  var ta = el('textarea', { class: 'field', style: 'min-height:140px;font-size:17px', autocapitalize: 'off', autocomplete: 'off', spellcheck: 'false', placeholder: 'Start typing the verse…' });
  var peekCap = el('div', { class: 'caption', style: 'color:rgba(255,255,255,.85);margin-bottom:6px', text: 'Peek · let go to hide' });
  var peek = el('div', { class: 'peek' }, [peekCap, el('div', { class: 'peek-text', text: v.text })]);
  rec.body.appendChild(el('div', { style: 'position:relative' }, [ta, peek]));
  rec.body.appendChild(el('div', { class: 'caption', style: 'margin:12px 0 6px', text: 'Live word check · green matches · coral needs work' }));
  var words = el('div', { class: 'words' });
  rec.body.appendChild(words);
  var hint = el('div', { style: 'color:var(--accent);margin-top:10px;font-size:14px' });
  var fb = el('div', { style: 'color:var(--warning);margin-top:4px;font-size:14px' });
  rec.body.appendChild(hint); rec.body.appendChild(fb);
  ta.addEventListener('input', function () {
    words.innerHTML = '';
    liveWords(ta.value, v.text).forEach(function (w) { words.appendChild(el('span', { class: 'word ' + w.status, text: w.word })); });
    fb.textContent = '';
  });
  var peekBtn = el('button', { class: 'btn ghost', 'aria-label': 'Hold to peek' }, [icon('eye'), 'Peek']);
  function showPeek(e) { if (e) e.preventDefault(); peek.classList.add('on'); }
  function hidePeek() { peek.classList.remove('on'); }
  peekBtn.addEventListener('touchstart', showPeek, { passive: false });
  peekBtn.addEventListener('touchend', hidePeek); peekBtn.addEventListener('touchcancel', hidePeek);
  peekBtn.addEventListener('mousedown', showPeek); peekBtn.addEventListener('mouseup', hidePeek); peekBtn.addEventListener('mouseleave', hidePeek);
  rec.foot.appendChild(peekBtn);
  var hintWord = -1, hintLevel = 0;
  rec.foot.appendChild(el('button', { class: 'btn ghost', onclick: function () {
    var idx = hintIndex(ta.value, v.text);
    if (idx === hintWord) hintLevel++; else { hintWord = idx; hintLevel = 1; }
    hint.textContent = nextHint(ta.value, v.text, hintLevel);
  } }, [icon('bulb'), 'Hint']));
  rec.foot.appendChild(el('button', { class: 'btn ghost', text: 'Later', onclick: function () { closeSheet(); } }));
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Check answer', onclick: function () {
    if (!ta.value.trim()) { fb.textContent = 'Type the verse before checking.'; return; }
    if (normalize(ta.value) === normalize(v.text)) { closeSheet(); toast(recordPass(v)); }
    else fb.textContent = 'Not quite. Review the coral words, then try again. Hint gives the next starting letter.';
  } }));
  setTimeout(function () { ta.focus(); }, 300);
}

function showDailyInvitation() {
  getDaily().then(function (d) {
    var prev = todaysPracticeVerse(d);
    var rec = openSheet({ caption: 'A moment with Scripture', title: "Today's verse is here.", tile: iconTile('star', 'c-blue') });
    rec.body.appendChild(el('div', { class: 'muted small', style: 'margin-bottom:10px', text: !prev ? 'A fresh verse for today' : prev.memorizedAt ? 'A verse you know — take a fresh look today' : prev.passes + ' of 3 correct recitations' }));
    var hero = el('div', { class: 'hero' }, [
      el('div', { class: 'caption', text: 'Read it slowly' }),
      el('div', { class: 'verse', text: '“' + d.text + '”' }),
      el('div', { class: 'ref', text: d.reference })
    ]);
    rec.body.appendChild(hero);
    rec.foot.appendChild(el('button', { class: 'btn ghost', text: 'Not now', onclick: function () { closeSheet(); } }));
    rec.foot.appendChild(el('button', { class: 'btn primary', text: "I'm ready to type", onclick: function () {
      closeSheet();
      var v = todaysPracticeVerse(d) || addVerse(d.reference, d.text, false, 'daily');
      setTimeout(function () { showPractice(v); }, 280);
    } }));
  });
}

function showAddVerse(prefRef, prefText) {
  var rec = openSheet({ full: true, caption: 'New memory', title: 'Add a verse', tile: iconTile('plus', 'c-green') });
  var refIn = el('input', { class: 'field', placeholder: 'e.g. Romans 8:28', value: prefRef || '' });
  var textIn = el('textarea', { class: 'field', style: 'min-height:150px', placeholder: 'The exact wording you want to learn' });
  textIn.value = prefText || '';
  var msg = el('div', { class: 'small', style: 'color:var(--warning);margin-top:8px' });
  rec.body.appendChild(el('div', { class: 'muted small', text: 'Type a reference and tap Fill in, or paste the exact wording you want.' }));
  rec.body.appendChild(el('div', { class: 'caption label', text: 'Reference' }));
  rec.body.appendChild(el('div', { class: 'row' }, [el('div', { class: 'grow' }, [refIn]), el('button', { class: 'btn ghost', text: 'Fill in', onclick: function () {
    var f = findRefs(refIn.value);
    if (!f.links.length) { msg.textContent = 'Type a reference such as John 3:16 first.'; return; }
    var r = f.links[0].reference;
    verseText(r).then(function (t) {
      if (!t) { msg.textContent = 'That passage could not be found.'; return; }
      refIn.value = r; textIn.value = t; msg.style.color = 'var(--text2)'; msg.textContent = 'Filled in from the ' + trName(st.translation) + '. Edit the wording if you like.';
    });
  } })]));
  rec.body.appendChild(el('div', { class: 'caption label', text: 'Verse text' }));
  rec.body.appendChild(textIn);
  rec.body.appendChild(msg);
  rec.foot.appendChild(el('button', { class: 'btn ghost', text: 'Cancel', onclick: function () { closeSheet(); } }));
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Add verse', onclick: function () {
    if (!refIn.value.trim() || !textIn.value.trim()) { msg.style.color = 'var(--warning)'; msg.textContent = 'Please enter a reference and the verse text.'; return; }
    addVerse(refIn.value, textIn.value); closeSheet(); go('verses'); toast('Added to your verses');
  } }));
}

// ------------------------------------------------------------------ navigation
var current = 'today';
var TITLES = { highlights: 'Highlights', today: 'Today', bible: 'Bible', verses: 'My verses', romans: 'Romans study', more: 'More', journal: 'Reflections', torah: 'Torah readings', settings: 'Settings' };
var TAB_OF = { highlights: 'more', journal: 'more', torah: 'more', settings: 'more' };
var history = [];
function go(page, noHistory) {
  if (!noHistory && page !== current) history.push(current);
  current = page;
  document.querySelectorAll('.page').forEach(function (p) { p.classList.toggle('active', p.id === 'page-' + page); });
  var tab = TAB_OF[page] || page;
  document.querySelectorAll('#tabbar button').forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-tab') === tab); });
  $('pageTitle').textContent = TITLES[page];
  $('fab').classList.toggle('on', page === 'verses');
  $('content').scrollTop = 0;
  render(page);
}
function render(page) {
  ({ today: renderToday, bible: renderBible, verses: renderVerses, romans: renderRomans, more: renderMore, journal: renderJournal, torah: renderTorah, settings: renderSettings, highlights: renderHighlights })[page]();
}
function refresh() { if (!practiceOpen) render(current); updateSub(); scheduleReminders(); }
function updateSub() {
  var now = new Date();
  $('pageSub').textContent = shortDate(now) + ' ' + now.getFullYear() + '  ·  ' + hebrewDate(now);
}
S.back = function () {
  if (closeSheet()) return true;
  if (history.length) { go(history.pop(), true); return true; }
  if (current !== 'today') { go('today', true); return true; }
  return false;
};

// ------------------------------------------------------------------ Today
function todayReadings(d) {
  var day = d.getDate(), out = [{ book: 'Proverbs', chapter: day, label: 'Proverbs ' + day }];
  for (var c = day; c <= 150; c += 30) out.push({ book: 'Psalms', chapter: c, label: 'Psalm ' + c });
  return out;
}
function renderToday() {
  ensureDaily();
  var pg = $('page-today'); pg.innerHTML = '';
  var now = new Date(), h = now.getHours();
  pg.appendChild(el('div', { class: 'muted', style: 'font-weight:600', text: h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening' }));
  pg.appendChild(el('h1', { class: 'big', html: 'Let the words <span style="color:var(--accent)">stay.</span>' }));
  pg.appendChild(el('div', { class: 'muted small', style: 'margin-bottom:14px', text: longDate(now) + ' · ' + hebrewDate(now) }));

  var verseEl = el('div', { class: 'verse', text: '…' }), refEl = el('div', { class: 'ref' });
  var hero = el('div', { class: 'hero' }, [
    el('div', { class: 'spread' }, [el('div', { class: 'row caption', style: 'gap:6px' }, [icon('star'), 'Verse of the day']), el('div', { class: 'caption', text: st.translation + ' · new each day' })]),
    verseEl, refEl,
    el('div', { class: 'actions' }, [
      el('button', { class: 'hbtn', onclick: function () { pickDaily(st.daily.index); renderToday(); } }, [icon('refresh'), 'Another']),
      el('button', { class: 'hbtn', onclick: function () { openUrl(nivUrl(S.data.pool[st.daily.index].reference)); } }, ['NIV', icon('external')]),
      el('button', { class: 'hbtn solid', onclick: function () { getDaily().then(function (d) { addVerse(d.reference, d.text); go('verses'); toast('Now your focus verse'); }); } }, [icon('plus'), 'Memorize this'])
    ])
  ]);
  pg.appendChild(hero);

  var focusCard = el('div', { class: 'card' });
  var journey = el('div', { class: 'card' }, [
    el('div', { class: 'row' }, [iconTile('star', 'c-green'), el('span', { class: 'caption', text: 'Your journey' })]),
    el('div', { class: 'big-number', text: String(st.verses.filter(function (v) { return v.memorizedAt; }).length) }),
    el('div', { class: 'muted small', text: 'verses tucked into memory' }),
    el('button', { class: 'btn subtle', style: 'padding-left:0;margin-top:6px', onclick: function () { go('verses'); } }, ['View verses', icon('chevR')])
  ]);
  pg.appendChild(focusCard);
  pg.appendChild(journey);

  getDaily().then(function (d) {
    verseEl.textContent = '“' + d.text + '”'; refEl.textContent = d.reference;
    var focus = getFocus(), dailyPractice = focus ? null : todaysPracticeVerse(d), done = doneToday(dailyPractice, now);
    var title, ref, hint, prog, label, enabled = true;
    if (focus) { title = 'Current focus'; ref = focus.reference; hint = 'Write it from memory when you are ready. Three correct recitations complete a verse.'; prog = 'PASS ' + (focus.passes || 0) + ' / 3'; label = 'Practice now'; }
    else if (st.offerDailyWhenNoFocus && dailyPractice && !done) { title = "Today's verse"; ref = dailyPractice.reference; hint = 'Read it once more, then write it from memory.'; prog = dailyPractice.memorizedAt ? 'READY TO REVIEW' : 'PASS ' + (dailyPractice.passes || 0) + ' / 3'; label = 'Read & practice'; }
    else { title = 'Current focus'; ref = 'Choose a verse'; hint = "Add your own verse or begin with today's suggestion."; prog = 'READY WHEN YOU ARE'; label = st.offerDailyWhenNoFocus && !dailyPractice ? "Read today's verse" : 'Practice now'; enabled = !!focus || (st.offerDailyWhenNoFocus && !done); }
    focusCard.innerHTML = '';
    focusCard.appendChild(el('div', { class: 'row' }, [iconTile('pen', 'c-blue'), el('span', { class: 'caption', text: title })]));
    focusCard.appendChild(el('h2', { text: ref }));
    focusCard.appendChild(el('div', { class: 'muted small', text: hint }));
    focusCard.appendChild(el('div', { class: 'caption accent', style: 'margin:8px 0 12px', text: prog }));
    focusCard.appendChild(el('div', { class: 'row' }, [
      el('button', { class: 'btn primary', text: label, disabled: !enabled, onclick: function () { var f = getFocus(); if (f) showPractice(f); else if (st.offerDailyWhenNoFocus) showDailyInvitation(); } }),
      el('button', { class: 'btn ghost', onclick: function () { showAddVerse(); } }, [icon('plus'), 'Add verse'])
    ]));
  });

  var readings = el('div', { class: 'card' }, [
    el('div', { class: 'row', style: 'margin-bottom:10px' }, [iconTile('book', 'c-purple'), el('div', {}, [el('div', { class: 'caption', text: "Today's Psalms & Proverb" }), el('div', { class: 'faint small', text: "Today's date, then add 30 for each Psalm." })])])
  ]);
  var chips = el('div');
  todayReadings(now).forEach(function (r) { chips.appendChild(el('button', { class: 'chip', text: r.label, onclick: function () { bibleState.book = r.book; bibleState.chapter = r.chapter; go('bible'); } })); });
  readings.appendChild(chips);
  pg.appendChild(readings);

  pg.appendChild(el('h3', { text: 'Explore' }));
  var lessonNo = lessonForDate(now), lesson = S.data.romans ? S.data.romans[lessonNo - 1] : null, ws = weekStart(lessonNo);
  pg.appendChild(el('button', { class: 'card tile', onclick: function () { romansState.lesson = lessonNo; romansState.follow = true; go('romans'); } }, [
    iconTile('school', 'c-teal'),
    el('div', { class: 'grow' }, lesson ? [el('div', { class: 'caption', text: 'Romans study' }), el('div', { class: 't1', text: 'Lesson ' + lesson.number + ' · ' + lesson.title }), el('div', { class: 't2', text: lesson.scripture + ' · Wed ' + shortDate(ws) + ' – Tue ' + shortDate(addDays(ws, 6)) })]
      : [el('div', { class: 'caption', text: 'Romans study' }), el('div', { class: 't1', text: 'Lessons not included' }), el('div', { class: 't2', text: 'Add your own lesson file and rebuild.' })])
  ]));
  var torah = torahReading(now);
  pg.appendChild(el('button', { class: 'card tile', onclick: function () { go('torah'); } }, [
    iconTile('calendar', 'c-orange'),
    el('div', { class: 'grow' }, torah ? [el('div', { class: 'caption', text: "This week's Torah" }), el('div', { class: 't1', text: torah.name }), el('div', { class: 't2', text: torah.torah + ' · ' + longDate(parseIso(torah.date)) })]
      : [el('div', { class: 'caption', text: "This week's Torah" }), el('div', { class: 't1', text: S.data.torahMissing ? 'Torah card not loaded' : '5787 schedule complete' }), el('div', { class: 't2', text: S.data.torahMissing ? 'Import it from Settings › Backup' : 'Add the next Torah card when it is available.' })])
  ]));
  pg.appendChild(el('button', { class: 'card tile', onclick: function () { go('journal'); } }, [
    iconTile('note', 'c-magenta'),
    el('div', { class: 'grow' }, [el('div', { class: 'caption', text: 'Reflections' }), el('div', { class: 't1', text: 'A quiet place for today' }), el('div', { class: 't2', text: 'Capture a thought, prayer, or something you noticed.' })])
  ]));
}

// ------------------------------------------------------------------ Bible
var bibleState = { book: 'Proverbs', chapter: new Date().getDate(), selected: 0 };
function noteFor(key) { for (var i = 0; i < st.bibleNotes.length; i++) if (st.bibleNotes[i].key === key) return st.bibleNotes[i]; return null; }
function renderBible() {
  var pg = $('page-bible'); pg.innerHTML = '';
  var b = bibleState.book, c = bibleState.chapter;
  var head = el('div', { class: 'card', style: 'padding:12px' }, [
    el('div', { class: 'spread' }, [
      el('button', { class: 'btn ghost', onclick: chooseBook }, [displayBook(b) + ' ' + c, icon('chevD')]),
      el('div', { class: 'row', style: 'gap:4px' }, [
        el('button', { class: 'icon-btn', 'aria-label': 'Previous chapter', onclick: function () { stepChapter(-1); } }, [icon('chevL')]),
        el('button', { class: 'icon-btn', 'aria-label': 'Next chapter', onclick: function () { stepChapter(1); } }, [icon('chevR')])
      ])
    ]),
    el('div', { class: 'spread', style: 'margin-top:10px' }, [
      transSeg(function () { renderBible(); }),
      el('button', { class: 'chip', style: 'margin:0', onclick: function () { openUrl(nivUrl(displayBook(b) + ' ' + c)); } }, ['Read in NIV', icon('external')])
    ])
  ]);
  pg.appendChild(head);
  var chips = el('div', { style: 'margin:2px 0 10px' }, [el('div', { class: 'caption accent', style: 'margin:0 2px 6px', text: "Today's reading" })]);
  todayReadings(new Date()).forEach(function (r) { chips.appendChild(el('button', { class: 'chip', text: r.label, onclick: function () { bibleState.book = r.book; bibleState.chapter = r.chapter; renderBible(); $('content').scrollTop = 0; } })); });
  pg.appendChild(chips);
  var card = el('div', { class: 'card', style: 'padding:10px 8px' }, [el('div', { class: 'muted', style: 'padding:8px', text: 'Loading…' })]);
  pg.appendChild(card);
  loadBook(b, st.translation).then(function (chs) {
    if (c > chs.length) { bibleState.chapter = c = chs.length; }
    card.innerHTML = '';
    card.appendChild(el('div', { class: 'spread', style: 'padding:4px 8px 8px' }, [el('h2', { style: 'margin:0', text: displayBook(b) + ' ' + c }), el('span', { class: 'caption', text: st.translation })]));
    chs[c - 1].forEach(function (t, i) {
      var key = b + '|' + c + '|' + (i + 1);
      var vn = el('span', { class: 'vn' }, [String(i + 1)]);
      if (noteFor(key)) vn.appendChild(el('span', { class: 'note-dot' }));
      card.appendChild(el('button', { class: 'verse-row' + (highlightOf(key) ? ' hl hl-' + highlightOf(key) : ''), onclick: function () { verseSheet(b, c, i + 1, t); } }, [vn, el('span', { text: t })]));
    });
    card.appendChild(el('div', { class: 'faint small', style: 'padding:10px 8px 2px', text: 'Tap a verse to write a note or add it to your memory collection.' }));
  });
}
function transSeg(after) {
  var seg = el('div', { class: 'seg' });
  ['BSB', 'KJV'].forEach(function (c) { seg.appendChild(el('button', { class: st.translation === c ? 'on' : '', text: c, onclick: function () { setTranslation(c); if (after) after(); } })); });
  return seg;
}
function setTranslation(c) { if (st.translation === c) return; st.translation = c; save(); updateSub(); pushDailyToPhone(true); }
function stepChapter(d) {
  loadBook(bibleState.book, st.translation).then(function (chs) {
    var n = bibleState.chapter + d, idx = BOOKS.indexOf(bibleState.book);
    if (n < 1) { if (idx > 0) { bibleState.book = BOOKS[idx - 1]; loadBook(bibleState.book, st.translation).then(function (p) { bibleState.chapter = p.length; renderBible(); }); } return; }
    if (n > chs.length) { if (idx < BOOKS.length - 1) { bibleState.book = BOOKS[idx + 1]; bibleState.chapter = 1; renderBible(); } return; }
    bibleState.chapter = n; renderBible(); $('content').scrollTop = 0;
  });
}
function chooseBook() {
  var rec = openSheet({ full: true, caption: 'Browse', title: 'Books', tile: iconTile('book', 'c-purple'), foot: false });
  var open = null, currentRow = null;
  [['Old Testament', 0, 39], ['New Testament', 39, 66]].forEach(function (g) {
    rec.body.appendChild(el('div', { class: 'caption', style: 'margin:14px 4px 4px', text: g[0] }));
    BOOKS.slice(g[1], g[2]).forEach(function (bk, k) {
      var count = S.data.chapters[g[1] + k];
      var grid = el('div', { class: 'chapter-grid acc' });
      for (var c = 1; c <= count; c++) (function (c) {
        grid.appendChild(el('button', { class: bk === bibleState.book && c === bibleState.chapter ? 'on' : '', text: String(c), onclick: function () {
          bibleState.book = bk; bibleState.chapter = c; closeSheet(); renderBible(); $('content').scrollTop = 0;
        } }));
      })(c);
      var chev = icon('chevD');
      var row = el('button', { class: 'book-row' + (bk === bibleState.book ? ' current' : ''), onclick: function () {
        if (open && open !== wrap) open.classList.remove('open');
        wrap.classList.toggle('open');
        open = wrap.classList.contains('open') ? wrap : null;
        if (open) setTimeout(function () { wrap.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); }, 60);
      } }, [el('span', { class: 'grow', text: bk }), el('span', { class: 'faint small', text: count + (count === 1 ? ' chapter' : ' chapters') }), chev]);
      var wrap = el('div', { class: 'book-acc' }, [row, grid]);
      if (bk === bibleState.book) { wrap.classList.add('open'); open = wrap; currentRow = wrap; }
      rec.body.appendChild(wrap);
    });
  });
  if (currentRow) setTimeout(function () { currentRow.scrollIntoView({ block: 'start' }); rec.body.scrollTop -= 40; }, 320);
}
var HIGHLIGHTS = [["honey", "Honey"], ["apricot", "Apricot"], ["coral", "Coral"], ["blush", "Blush"], ["orchid", "Orchid"], ["lilac", "Lilac"], ["periwinkle", "Periwinkle"], ["sky", "Sky"], ["aqua", "Aqua"], ["mint", "Mint"], ["sage", "Sage"], ["sand", "Sand"]];
function setHighlight(key, color) {
  if (color) st.highlights[key] = { color: color, at: new Date().toISOString() };
  else delete st.highlights[key];
  save();
}
function highlightOf(key) { var h = st.highlights[key]; return h ? h.color : ''; }
function swatches(key, onPick) {
  var row = el('div', { class: 'swatches' });
  function paint() {
    row.innerHTML = '';
    var cur = highlightOf(key);
    HIGHLIGHTS.forEach(function (h) {
      row.appendChild(el('button', { class: 'swatch hl-' + h[0] + (cur === h[0] ? ' on' : ''), 'aria-label': h[1], onclick: function () { setHighlight(key, cur === h[0] ? '' : h[0]); paint(); if (onPick) onPick(); } },
        [el('span', { class: 'dot' }, cur === h[0] ? [icon('check')] : []), h[1]]));
    });
  }
  paint();
  return row;
}
function verseSheet(b, c, v, text) {
  var key = b + '|' + c + '|' + v, ref = displayBook(b) + ' ' + c + ':' + v;
  var rec = openSheet({ caption: 'Highlight & note', title: ref, tile: iconTile('palette', 'c-purple') });
  var verseBox = el('div', { class: 'scripture sheet-verse hl-' + (highlightOf(key) || 'none'), text: text });
  rec.body.appendChild(verseBox);
  rec.body.appendChild(el('div', { class: 'spread', style: 'margin:4px 2px 10px' }, [el('span', { class: 'caption', text: 'Highlight' }), el('button', { class: 'btn subtle', style: 'min-height:0;padding:2px 4px;font-size:13px', text: 'Clear', onclick: function () { setHighlight(key, ''); closeSheet(); renderBible(); } })]));
  rec.body.appendChild(swatches(key, function () { verseBox.className = 'scripture sheet-verse hl-' + (highlightOf(key) || 'none'); renderBible(); }));
  rec.body.appendChild(el('div', { class: 'caption', style: 'margin:16px 2px 8px', text: 'Note' }));
  var n = noteFor(key);
  var ta = el('textarea', { class: 'field', placeholder: 'Write a note on this verse…' }); ta.value = n ? n.text : '';
  rec.body.appendChild(ta);
  rec.foot.appendChild(el('button', { class: 'btn ghost', onclick: function () { addVerse(ref, text); closeSheet(); go('verses'); toast('Now your focus verse'); } }, [icon('plus'), 'Memorize']));
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Save note', onclick: function () {
    var t = ta.value.trim(), ex = noteFor(key);
    if (ex) { if (t) { ex.text = t; ex.savedAt = new Date().toISOString(); } else st.bibleNotes.splice(st.bibleNotes.indexOf(ex), 1); }
    else if (t) st.bibleNotes.push({ key: key, text: t, savedAt: new Date().toISOString() });
    var had = !!ex; save(); closeSheet(); if (t) toast('Note saved'); else if (had) toast('Note removed'); renderBible();
  } }));
}

var hlFilter = '';
function renderHighlights() {
  var pg = $('page-highlights'); pg.innerHTML = '';
  var keys = Object.keys(st.highlights).sort(function (a, b) { return (st.highlights[b].at || '') < (st.highlights[a].at || '') ? -1 : 1; });
  var used = {}; keys.forEach(function (k) { used[st.highlights[k].color] = (used[st.highlights[k].color] || 0) + 1; });
  var filters = el('div', { class: 'row wrap', style: 'gap:6px;margin-bottom:12px' });
  filters.appendChild(el('button', { class: 'chip' + (hlFilter ? '' : ' chip-on'), text: 'All · ' + keys.length, onclick: function () { hlFilter = ''; renderHighlights(); } }));
  HIGHLIGHTS.forEach(function (h) { if (used[h[0]]) filters.appendChild(el('button', { class: 'chip hl-chip hl-' + h[0] + (hlFilter === h[0] ? ' chip-on' : ''), text: h[1] + ' · ' + used[h[0]], onclick: function () { hlFilter = h[0]; renderHighlights(); } })); });
  pg.appendChild(filters);
  if (!keys.length) {
    pg.appendChild(el('div', { class: 'card empty' }, [el('div', { style: 'font-weight:700;color:var(--text)', text: 'No highlights yet.' }), el('div', { text: 'In the Bible tab, tap any verse and pick a colour.' })]));
    return;
  }
  var list = el('div');
  pg.appendChild(list);
  keys.filter(function (k) { return !hlFilter || st.highlights[k].color === hlFilter; }).forEach(function (k) {
    var p = k.split('|'), ref = displayBook(p[0]) + ' ' + p[1] + ':' + p[2];
    var textEl = el('div', { class: 'small', style: 'margin-top:4px', text: '…' });
    var card = el('button', { class: 'card hl-card hl-' + st.highlights[k].color, style: 'display:block;width:100%;text-align:left', onclick: function () {
      bibleState.book = p[0]; bibleState.chapter = +p[1]; go('bible');
    } }, [el('div', { style: 'font-weight:700', text: ref }), textEl]);
    list.appendChild(card);
    loadBook(p[0], st.translation).then(function (chs) { var t = (chs[+p[1] - 1] || [])[+p[2] - 1]; textEl.textContent = t || ''; });
  });
}

// ------------------------------------------------------------------ My verses
function renderVerses() {
  var pg = $('page-verses'); pg.innerHTML = '';
  pg.appendChild(el('div', { class: 'muted small', style: 'margin:0 2px 12px', text: 'The words you are learning and the words you have learned.' }));
  if (!st.verses.length) {
    pg.appendChild(el('div', { class: 'card empty' }, [el('div', { style: 'font-weight:700;font-size:17px;color:var(--text)', text: 'Your collection begins here.' }), el('div', { text: 'Tap + to add a verse, or memorize the verse of the day.' })]));
    return;
  }
  var active = st.verses.filter(function (v) { return !v.memorizedAt; }), done = st.verses.filter(function (v) { return v.memorizedAt; });
  [['Learning', active], ['Memorized', done]].forEach(function (g) {
    if (!g[1].length) return;
    pg.appendChild(el('h3', { text: g[0] + ' · ' + g[1].length }));
    var card = el('div', { class: 'card', style: 'padding:4px 14px' });
    g[1].forEach(function (v) {
      var pill = v.memorizedAt ? el('span', { class: 'status-pill done' }, [icon('check'), 'Memorized']) : v.id === st.focusId ? el('span', { class: 'status-pill', text: 'Focus · ' + (v.passes || 0) + '/3' }) : el('span', { class: 'faint small', text: (v.passes || 0) + '/3' });
      card.appendChild(el('button', { class: 'list-item', onclick: function () { verseDetail(v); } }, [
        el('div', { class: 'grow' }, [el('div', { style: 'font-weight:700', text: v.reference }), el('div', { class: 'muted small', style: 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis', text: v.text })]),
        pill
      ]));
    });
    pg.appendChild(card);
  });
}
function verseDetail(v) {
  var rec = openSheet({ caption: v.memorizedAt ? '✓ Memorized' : v.id === st.focusId ? '● Current focus' : '○ In progress', title: v.reference, tile: iconTile('library', 'c-green') });
  rec.body.appendChild(el('div', { class: 'scripture', text: v.text }));
  var srcLine = el('div', { style: 'margin-top:10px' }, [el('span', { class: 'src-badge', text: '…' })]);
  rec.body.appendChild(srcLine);
  wordingSource(v).then(function (w) { srcLine.firstChild.textContent = w.label; if (w.own) srcLine.firstChild.classList.add('own'); });
  rec.body.appendChild(el('div', { class: 'muted small', style: 'margin-top:12px', text: v.memorizedAt ? 'Memorized ' + shortDate(new Date(v.memorizedAt)) + ' ' + new Date(v.memorizedAt).getFullYear() : (v.passes || 0) + ' / 3 correct recitations' }));
  rec.foot.appendChild(el('button', { class: 'btn ghost', text: 'Remove', onclick: function () {
    if (!confirm('Remove ' + v.reference + ' from your verses?')) return;
    st.verses.splice(st.verses.indexOf(v), 1); if (st.focusId === v.id) st.focusId = ''; save(); closeSheet(); refresh();
  } }));
  if (!v.memorizedAt && v.id !== st.focusId) rec.foot.appendChild(el('button', { class: 'btn ghost', text: 'Make my focus', onclick: function () { setFocus(v.id); closeSheet(); } }));
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Practice', onclick: function () { closeSheet(); setTimeout(function () { showPractice(v); }, 280); } }));
}

// ------------------------------------------------------------------ Romans study
var ANCHOR = new Date(2026, 9, 14); // Lesson 5 began Wednesday 14 October 2026; lessons change each Wednesday.
function addDays(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
function lessonForDate(d) {
  var day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  var diff = Math.round((day - ANCHOR) / 86400000);
  return Math.max(1, Math.min(30, 5 + Math.floor(diff / 7)));
}
function weekStart(n) { return addDays(ANCHOR, (n - 5) * 7); }
var romansState = { lesson: lessonForDate(new Date()), follow: true, tab: 'Questions' };
function questionParts(text) {
  var re = /^[ \t]*([a-z])\.[ \t]+/gm, markers = [], m;
  while ((m = re.exec(text))) markers.push({ index: m.index, length: m[0].length, label: m[1] });
  if (markers.length < 2 || markers[0].label !== 'a') return [{ label: '', text: text, introduction: '' }];
  var intro = text.slice(0, markers[0].index).trim();
  return markers.map(function (mk, i) {
    var start = mk.index + mk.length, end = i + 1 < markers.length ? markers[i + 1].index : text.length;
    return { label: mk.label, text: text.slice(start, end).trim(), introduction: i === 0 ? intro : '' };
  });
}
function getAnswer(lesson, number, part) {
  part = part || '';
  for (var i = 0; i < st.bsfAnswers.length; i++) { var a = st.bsfAnswers[i]; if (+a.lesson === lesson && +a.number === number && (a.part || '') === part) return a; }
  return null;
}
function setAnswer(lesson, number, part, text) {
  var a = getAnswer(lesson, number, part);
  if (a && a.text === text) return;
  if (!a) { a = { lesson: lesson, number: number, part: part, text: text, updatedAt: new Date().toISOString() }; st.bsfAnswers.push(a); }
  else { a.text = text; a.updatedAt = new Date().toISOString(); }
  save();
}
function renderRomans() {
  if (!S.data.romans || !S.data.romans.length) {
    var pg0 = $('page-romans'); pg0.innerHTML = '';
    pg0.appendChild(el('div', { class: 'card empty' }, [el('div', { style: 'font-weight:700;color:var(--text)', text: 'Romans lessons are not included in this build.' }), el('div', { text: 'Run tools/build_android_data.py with your own StudyData/romans-lessons.json, then rebuild.' })]));
    return;
  }
  if (romansState.follow) romansState.lesson = lessonForDate(new Date());
  var pg = $('page-romans'); pg.innerHTML = '';
  var n = romansState.lesson, lesson = S.data.romans[n - 1], ws = weekStart(n), ctx = refContext(lesson.scripture);
  $('pageTitle').textContent = 'Romans · Lesson ' + n;
  var head = el('div', { class: 'card' }, [
    el('div', { class: 'spread' }, [
      el('div', { class: 'row' }, [iconTile('school', 'c-teal'), el('div', {}, [el('div', { class: 'caption', text: 'Lesson ' + n + (n === lessonForDate(new Date()) ? ' · this week' : '') }), el('div', { style: 'font-weight:700;font-size:18px;line-height:1.25', text: lesson.title })])])
    ]),
    el('div', { style: 'margin-top:10px' }, [refChip(lesson.scripture)]),
    el('div', { class: 'muted small', text: 'Wednesday ' + shortDate(ws) + ' – Tuesday ' + shortDate(addDays(ws, 6)) + ' ' + addDays(ws, 6).getFullYear() }),
    el('div', { class: 'spread', style: 'margin-top:12px' }, [
      el('div', { class: 'row', style: 'gap:6px' }, [
        el('button', { class: 'btn ghost', style: 'padding:8px 12px', disabled: n <= 1, onclick: function () { romansState.lesson--; romansState.follow = false; renderRomans(); } }, [icon('chevL')]),
        el('button', { class: 'btn ghost', text: 'This week', onclick: function () { romansState.follow = true; renderRomans(); } }),
        el('button', { class: 'btn ghost', style: 'padding:8px 12px', disabled: n >= 30, onclick: function () { romansState.lesson++; romansState.follow = false; renderRomans(); } }, [icon('chevR')])
      ]),
      el('button', { class: 'icon-btn', 'aria-label': 'Export answers', onclick: function () { exportAnswers(n); } }, [icon('share')])
    ])
  ]);
  pg.appendChild(head);
  var seg = el('div', { class: 'seg', style: 'margin:4px 0 6px' });
  [['Questions', 'Questions & answers'], ['Notes', 'Lesson ' + (n - 1) + ' notes']].forEach(function (t) {
    if (t[0] === 'Notes' && n === 1) t[1] = 'Previous notes';
    seg.appendChild(el('button', { class: romansState.tab === t[0] ? 'on' : '', text: t[1], onclick: function () { romansState.tab = t[0]; renderRomans(); } }));
  });
  pg.appendChild(seg);
  var savedLabel = el('div', { class: 'faint small', style: 'margin:0 4px 4px', text: romansState.tab === 'Questions' ? 'Answers save as you type' : '' });
  pg.appendChild(savedLabel);
  if (romansState.tab === 'Notes') { renderNotes(pg, n); return; }
  var lastDay = '';
  lesson.questions.forEach(function (q) {
    var qctx = refContext(q.instruction);
    if (!qctx.book && q.references && q.references.length) qctx = refContext(q.references[0]);
    if (!qctx.book) qctx = ctx;
    if (q.day !== lastDay) {
      var dh = el('div', { class: 'day-head' });
      linkify(dh, q.day + '  ·  ' + q.instruction, ctx.book, ctx.chapter);
      pg.appendChild(dh); lastDay = q.day;
    }
    questionParts(q.text).forEach(function (part) {
      var card = el('div', { class: 'card q-card' }), chipRefs = [];
      function addChips(f) { f.links.forEach(function (l) { if (chipRefs.indexOf(l.reference) < 0) chipRefs.push(l.reference); }); }
      if (part.introduction) { var intro = el('div', { class: 'intro' }); addChips(linkify(intro, part.introduction, qctx.book, qctx.chapter)); card.appendChild(intro); }
      var prompt = el('div', { class: 'prompt' }, [el('span', { class: 'num', text: q.number + part.label + '.  ' })]);
      addChips(linkify(prompt, part.text, qctx.book, qctx.chapter));
      card.appendChild(prompt);
      if (!part.label || part.label === 'a') (q.references || []).slice().reverse().forEach(function (r) { if (chipRefs.indexOf(r) < 0) chipRefs.unshift(r); });
      if (chipRefs.length) { var chips = el('div', { class: 'chips' }); chipRefs.forEach(function (r) { chips.appendChild(refChip(r)); }); card.appendChild(chips); }
      var a = getAnswer(n, q.number, part.label);
      var ta = el('textarea', { class: 'field', placeholder: 'Your answer' }); ta.value = a ? a.text : '';
      ta.addEventListener('input', debounce(function () { setAnswer(n, q.number, part.label, ta.value); savedLabel.textContent = 'Saved ✓'; }, 400));
      ta.addEventListener('blur', function () { setAnswer(n, q.number, part.label, ta.value); });
      card.appendChild(ta);
      if (part.label === 'a') {
        var prev = getAnswer(n, q.number, '');
        if (prev && prev.text.trim()) {
          card.appendChild(el('div', { class: 'caption', style: 'color:var(--partial);margin-top:12px', text: 'Earlier combined answer · copy into the parts when ready' }));
          card.appendChild(el('div', { class: 'legacy', text: prev.text }));
        }
      }
      pg.appendChild(card);
    });
  });
}
function renderNotes(pg, n) {
  var card = el('div', { class: 'card notes' });
  if (n <= 1) { card.appendChild(el('p', { text: 'This is the first lesson. There are no earlier lesson notes in the book.' })); pg.appendChild(card); return; }
  var prev = S.data.romans[n - 2], ctx = refContext(prev.scripture), book = ctx.book, chap = ctx.chapter;
  card.appendChild(el('div', { class: 'caption accent', text: 'Lesson ' + (n - 1) + ' notes · ' + prev.scripture }));
  prev.notesPages.forEach(function (page) {
    card.appendChild(el('div', { class: 'page-label', text: 'PAGE ' + page.printedPage }));
    page.text.split(/\r?\n\s*\r?\n/).forEach(function (para) {
      var clean = para.replace(/\s*\r?\n\s*/g, ' ').trim(); if (!clean) return;
      var p = el('p', { class: clean.length < 60 && !/[.?!:\u201D]$/.test(clean) && !/^●/.test(clean) ? 'h' : '' });
      var f = linkify(p, clean, book, chap); book = f.book; chap = f.chapter;
      card.appendChild(p);
    });
  });
  pg.appendChild(card);
}
function escHtml(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
function exportHtml(n) {
  var lesson = S.data.romans[n - 1], out = [];
  out.push('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Romans Lesson ' + n + ' answers</title>');
  out.push('<style>body{font:15px/1.55 "Segoe UI",Roboto,Arial,sans-serif;color:#1b1b1f;max-width:800px;margin:30px auto;padding:0 20px}h1{font-size:28px;margin-bottom:3px}header p{color:#5b6370;margin-top:0}.day{font:700 13px Arial,sans-serif;color:#0f6cbd;border-bottom:1px solid #c7d6ea;padding-bottom:7px;margin-top:26px}.question{break-inside:avoid;margin:18px 0 24px}.question h3{font-size:16px;white-space:pre-wrap}.introduction{color:#5b6370;white-space:pre-wrap}.answer{white-space:pre-wrap;border-left:3px solid #0f6cbd;padding:4px 0 4px 13px;min-height:32px}.empty{color:#9da5aa}.legacy{white-space:pre-wrap;color:#586375;background:#f1f4f9;padding:10px;margin-top:12px}footer{margin-top:36px;color:#77818a;font-size:11px}</style></head><body>');
  out.push('<header><h1>Romans · Lesson ' + n + '</h1><p>' + escHtml(lesson.title) + ' · ' + escHtml(lesson.scripture) + '</p></header>');
  var lastDay = '';
  lesson.questions.forEach(function (q) {
    if (q.day !== lastDay) { out.push('<div class="day">' + escHtml(q.day) + ' · ' + escHtml(q.instruction) + '</div>'); lastDay = q.day; }
    questionParts(q.text).forEach(function (p) {
      var a = getAnswer(n, q.number, p.label), t = a ? a.text : '';
      var legacy = '';
      if (p.label === 'a') { var e = getAnswer(n, q.number, ''); if (e && e.text.trim()) legacy = '<div class="legacy"><strong>Earlier combined answer:</strong> ' + escHtml(e.text) + '</div>'; }
      out.push('<section class="question">' + (p.introduction ? '<p class="introduction">' + escHtml(p.introduction) + '</p>' : '') + '<h3>' + q.number + p.label + '. ' + escHtml(p.text) + '</h3><div class="answer' + (t.trim() ? '' : ' empty') + '">' + (t.trim() ? escHtml(t) : 'Answer space') + '</div>' + legacy + '</section>');
    });
  });
  out.push('<footer>Prepared in Selah for personal BSF class study. Questions © Bible Study Fellowship.</footer></body></html>');
  return out.join('\n');
}
function exportAnswers(n) {
  var html = exportHtml(n), name = 'Selah-Romans-Lesson-' + pad(n);
  if (Android && Android.printHtml) { Android.printHtml(html, name); return; }
  var w = window.open('', '_blank'); if (w) { w.document.write(html); w.document.close(); w.print(); }
}

// ------------------------------------------------------------------ More, Reflections, Torah, Settings
function renderMore() {
  var pg = $('page-more'); pg.innerHTML = '';
  var card = el('div', { class: 'card', style: 'padding:4px 14px' });
  [['highlights', 'palette', 'c-orange', 'Highlights', 'Every verse you have coloured'], ['journal', 'note', 'c-magenta', 'Reflections', 'Dated thoughts and prayers'], ['torah', 'calendar', 'c-orange', 'Torah readings', 'The weekly 5787 schedule'], ['settings', 'settings', 'c-gray', 'Settings', 'Appearance, translation, reminders, backup']].forEach(function (r) {
    card.appendChild(el('button', { class: 'list-item', onclick: function () { go(r[0]); } }, [iconTile(r[1], r[2]), el('div', { class: 'grow' }, [el('div', { style: 'font-weight:700', text: r[3] }), el('div', { class: 'muted small', text: r[4] })]), el('span', { class: 'chev' }, [icon('chevR')])]));
  });
  pg.appendChild(card);
  pg.appendChild(el('div', { class: 'card soft' }, [
    el('div', { class: 'row' }, [icon('clock'), el('span', { class: 'caption accent', text: 'Practice moments' })]),
    el('div', { style: 'font-weight:700;font-size:16px;margin-top:6px', text: '10:00 AM · 12:30 PM · 2:00 PM · 4:30 PM' }),
    el('div', { class: 'muted small', text: st.remindersOn ? 'Selah sends a gentle notification at these times.' : 'Reminders are off. Turn them on in Settings.' })
  ]));
}
var journalDate = isoDate(new Date());
function renderJournal() {
  var pg = $('page-journal'); pg.innerHTML = '';
  var entry = st.reflections.filter(function (r) { return r.date === journalDate; })[0];
  var label = el('div', { class: 'faint small', text: 'Autosaves as you type' });
  var ta = el('textarea', { class: 'field', style: 'min-height:200px;font-size:16px', placeholder: 'What is on your heart?' }); ta.value = entry ? entry.text : '';
  function saveReflection() {
    var t = ta.value, has = !!t.trim(), e = st.reflections.filter(function (r) { return r.date === journalDate; })[0];
    if (e) { if (has) { if (e.text === t) return; e.text = t; e.savedAt = new Date().toISOString(); } else st.reflections.splice(st.reflections.indexOf(e), 1); }
    else if (has) st.reflections.push({ date: journalDate, text: t, savedAt: new Date().toISOString() });
    else return;
    save(); label.textContent = has ? 'Saved automatically ✓' : 'Empty entry removed';
  }
  ta.addEventListener('input', debounce(saveReflection, 400));
  ta.addEventListener('blur', saveReflection);
  pg.appendChild(el('div', { class: 'card' }, [
    el('div', { class: 'caption accent', text: longDate(parseIso(journalDate)) }),
    el('h2', { text: 'What is on your heart?' }), ta,
    el('div', { class: 'spread', style: 'margin-top:8px' }, [label, journalDate !== isoDate(new Date()) ? el('button', { class: 'btn subtle', text: 'Back to today', onclick: function () { journalDate = isoDate(new Date()); renderJournal(); } }) : null])
  ]));
  var past = st.reflections.slice().sort(function (a, b) { return a.date < b.date ? 1 : -1; });
  if (past.length) {
    pg.appendChild(el('h3', { text: 'Past entries' }));
    var card = el('div', { class: 'card', style: 'padding:4px 14px' });
    past.forEach(function (r) {
      card.appendChild(el('button', { class: 'list-item', onclick: function () { journalDate = r.date; renderJournal(); $('content').scrollTop = 0; } }, [
        el('div', { class: 'grow' }, [el('div', { style: 'font-weight:700' + (r.date === journalDate ? ';color:var(--accent)' : ''), text: longDate(parseIso(r.date)) }), el('div', { class: 'muted small', style: 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis', text: r.text.replace(/\s+/g, ' ') })])
      ]));
    });
    pg.appendChild(card);
  }
}
function torahAll() { var t = S.data.torah; return t ? (t.portions || []).concat(t.special || []) : []; }
function torahReading(d) {
  var today = isoDate(d);
  var list = torahAll().filter(function (r) { return r.date >= today; }).sort(function (a, b) { return a.date < b.date ? -1 : 1; });
  return list[0] || null;
}
function renderTorah() {
  var pg = $('page-torah'); pg.innerHTML = '';
  if (!S.data.torah) {
    pg.appendChild(el('div', { class: 'card empty' }, [el('div', { style: 'font-weight:700;color:var(--text)', text: 'Your Torah card is not loaded yet.' }), el('div', { text: 'Open Settings › Backup and import torah-portions.json and torah-special-readings.json from your Selah folder on the computer.' })]));
    return;
  }
  var now = new Date(), cur = torahReading(now);
  if (!cur) { pg.appendChild(el('div', { class: 'card empty', text: 'The supplied card ends 24 October 2027. Add the next Torah card when it is available.' })); return; }
  pg.appendChild(el('div', { class: 'card' }, [
    el('div', { class: 'row' }, [iconTile('calendar', 'c-orange'), el('span', { class: 'caption', text: cur.number !== undefined && cur.number !== null ? 'Upcoming Shabbat portion' : 'Upcoming special reading' })]),
    el('h2', { style: 'font-size:24px', text: cur.name }),
    el('div', { style: 'color:var(--accent);margin-bottom:10px', text: longDate(parseIso(cur.date)) }),
    el('div', { class: 'caption', text: 'Torah' }), el('div', { style: 'font-weight:700;margin:2px 0 8px', text: cur.torah }),
    el('div', { class: 'caption', text: 'Haftarah' }), el('div', { style: 'margin:2px 0 8px', text: cur.haftarah || '' }),
    el('div', { class: 'caption', text: 'Gospel' }), el('div', { style: 'margin:2px 0 12px', text: cur.gospel || '' }),
    el('div', { class: 'row wrap' }, [
      el('button', { class: 'btn primary', text: 'Read Torah', onclick: function () { showScripture(cur.torah); } }),
      cur.haftarah ? el('button', { class: 'btn ghost', text: 'Haftarah', onclick: function () { showScripture(cur.haftarah); } }) : null,
      cur.gospel ? el('button', { class: 'btn ghost', text: 'Gospel', onclick: function () { showScripture(cur.gospel); } }) : null
    ])
  ]));
  var card = el('div', { class: 'card', style: 'padding:4px 14px' });
  torahAll().filter(function (r) { return r.date > isoDate(now) && r !== cur; }).sort(function (a, b) { return a.date < b.date ? -1 : 1; }).slice(0, 7).forEach(function (r) {
    card.appendChild(el('div', { class: 'list-item' }, [
      el('div', { class: 'grow' }, [el('div', { style: 'font-weight:700', text: r.name }), el('div', { class: 'muted small', text: (r.number !== undefined && r.number !== null ? 'Portion' : 'Special reading') + ' · ' + shortDate(parseIso(r.date)) + ' · ' + r.torah })]),
      el('button', { class: 'chip', style: 'margin:0', text: 'Read', onclick: function () { showScripture(r.torah); } })
    ]));
  });
  if (card.childNodes.length) { pg.appendChild(el('h3', { text: 'Coming up' })); pg.appendChild(card); }
  pg.appendChild(el('div', { class: 'faint small', style: 'margin:10px 4px', text: "Hebrew date follows the phone's calendar day; the Jewish day changes at sunset." }));
}
function settingRow(iconName, color, title, sub, control) {
  return el('div', { class: 'card setting' }, [iconTile(iconName, color), el('div', { class: 'grow' }, [el('div', { class: 't1', text: title }), el('div', { class: 't2', text: sub })]), control]);
}
function toggle(checked, onchange) {
  var input = el('input', { type: 'checkbox' }); input.checked = !!checked;
  input.addEventListener('change', function () { onchange(input.checked); });
  return el('label', { class: 'switch' }, [input, el('span')]);
}
function renderSettings() {
  var pg = $('page-settings'); pg.innerHTML = '';
  var themeSeg = el('div', { class: 'seg' });
  ['Light', 'Dark'].forEach(function (t) { themeSeg.appendChild(el('button', { class: st.theme === t ? 'on' : '', text: t, onclick: function () { setTheme(t); renderSettings(); } })); });
  pg.appendChild(el('h3', { style: 'margin-top:4px', text: 'Personalize' }));
  pg.appendChild(settingRow('palette', 'c-blue', 'Appearance', 'Light is bright and airy; Dark is easier on the eyes at night.', themeSeg));
  pg.appendChild(settingRow('book', 'c-purple', 'Bible translation', 'BSB reads much like the NIV. NIV text is copyrighted, so passages have a Read in NIV button that opens BibleGateway.', transSeg(function () { renderSettings(); })));
  pg.appendChild(el('h3', { text: 'Rhythm' }));
  var timeIn = el('input', { type: 'time', class: 'field', style: 'width:auto;padding:6px 10px', value: st.dailyNotifyTime || '06:30' });
  timeIn.addEventListener('change', function () { if (timeIn.value) { st.dailyNotifyTime = timeIn.value; save(); pushDailyToPhone(false); toast('Daily verse at ' + timeIn.value); } });
  pg.appendChild(el('div', { class: 'card' }, [
    el('div', { class: 'setting' }, [iconTile('star', 'c-blue'), el('div', { class: 'grow' }, [el('div', { class: 't1', text: 'Daily verse notification' }), el('div', { class: 't2', text: "Today's verse pops up on your phone each morning, like a message." })]),
      toggle(st.dailyNotifyOn, function (on) { st.dailyNotifyOn = on; save(); pushDailyToPhone(false); })]),
    el('div', { class: 'spread', style: 'margin-top:12px;padding-left:48px' }, [el('span', { class: 'muted small', text: 'Time' }), timeIn]),
    el('div', { class: 'row', style: 'margin-top:10px;padding-left:48px' }, [el('button', { class: 'btn ghost', onclick: function () { if (Android && Android.testDailyNotification) Android.testDailyNotification(); else toast('Notifications work in the phone app.'); } }, [icon('bell'), 'Show it now'])]),
    el('div', { class: 'faint small', style: 'margin-top:10px;padding-left:48px', text: 'Home screen widget: long-press your home screen › Widgets › Selah › Verse of the day.' })
  ]));
  pg.appendChild(settingRow('bell', 'c-green', 'Practice reminders', 'A notification at 10:00, 12:30, 2:00 and 4:30.', toggle(st.remindersOn, function (on) { st.remindersOn = on; save(); scheduleReminders(true); })));
  pg.appendChild(settingRow('star', 'c-orange', "Offer today's verse", "When no verse is focused, invite me to read today's verse and then type it from memory.", toggle(st.offerDailyWhenNoFocus, function (on) { st.offerDailyWhenNoFocus = on; save(); })));
  pg.appendChild(el('h3', { text: 'Backup' }));
  pg.appendChild(el('div', { class: 'card' }, [
    el('div', { class: 'muted small', style: 'margin-bottom:10px', text: 'Save everything to a file, or bring in your data from Selah on the computer: copy state.json from %LOCALAPPDATA%\\Selah (and the Torah files from D:\\BV\\StudyData) to your phone, then import them here. Imported items are merged with what is already on the phone.' }),
    el('div', { class: 'row wrap' }, [
      el('button', { class: 'btn ghost', onclick: exportBackup }, [icon('download'), 'Save backup']),
      el('button', { class: 'btn ghost', onclick: importFile }, [icon('upload'), 'Import file'])
    ])
  ]));
  pg.appendChild(el('div', { class: 'faint small', style: 'margin:14px 4px', text: 'Selah for Android · Scripture text: Berean Standard Bible (public domain) and King James Version. Romans questions © Bible Study Fellowship, for personal class study.' }));
}
function exportBackup() {
  var text = JSON.stringify(st, null, 1), name = 'selah-backup-' + isoDate(new Date()) + '.json';
  if (Android && Android.saveTextFile) Android.saveTextFile(name, 'application/json', text);
  else { var a = el('a', { href: URL.createObjectURL(new Blob([text], { type: 'application/json' })), download: name }); document.body.appendChild(a); a.click(); a.remove(); }
}
function importFile() {
  if (Android && Android.openTextFile) { Android.openTextFile(); return; }
  var input = el('input', { type: 'file', accept: '.json,application/json' });
  input.addEventListener('change', function () { var f = input.files[0]; if (!f) return; var r = new FileReader(); r.onload = function () { S.onFileOpened(String(r.result), f.name); }; r.readAsText(f); });
  input.click();
}
function mergeState(raw) {
  var counts = { verses: 0, reflections: 0, notes: 0, answers: 0 };
  (raw.verses || []).forEach(function (v) {
    if (!v || !v.reference) return;
    var ex = st.verses.filter(function (x) { return x.id === v.id || (x.reference === v.reference && x.text === v.text); })[0];
    if (!ex) { st.verses.push(v); counts.verses++; }
    else if ((v.passes || 0) > (ex.passes || 0) || (v.memorizedAt && !ex.memorizedAt)) { ex.passes = v.passes; ex.memorizedAt = v.memorizedAt; ex.lastReviewedAt = v.lastReviewedAt; counts.verses++; }
  });
  (raw.reflections || []).forEach(function (r) {
    if (!r || !r.date) return;
    var ex = st.reflections.filter(function (x) { return x.date === r.date; })[0];
    if (!ex) { st.reflections.push(r); counts.reflections++; }
    else if ((r.savedAt || '') > (ex.savedAt || '') && r.text !== ex.text) { ex.text = r.text; ex.savedAt = r.savedAt; counts.reflections++; }
  });
  (raw.bibleNotes || []).forEach(function (n) {
    if (!n || !n.key) return;
    var ex = noteFor(n.key);
    if (!ex) { st.bibleNotes.push(n); counts.notes++; }
    else if ((n.savedAt || '') > (ex.savedAt || '')) { ex.text = n.text; ex.savedAt = n.savedAt; counts.notes++; }
  });
  (raw.bsfAnswers || []).forEach(function (a) {
    if (!a || !a.lesson || !a.number) return;
    var ex = getAnswer(+a.lesson, +a.number, a.part || '');
    if (!ex) { st.bsfAnswers.push({ lesson: +a.lesson, number: +a.number, part: a.part || '', text: a.text, updatedAt: a.updatedAt }); counts.answers++; }
    else if ((a.updatedAt || '') > (ex.updatedAt || '') && a.text !== ex.text) { ex.text = a.text; ex.updatedAt = a.updatedAt; counts.answers++; }
  });
  if (raw.highlights && typeof raw.highlights === 'object') for (var hk in raw.highlights) { if (!st.highlights[hk]) st.highlights[hk] = raw.highlights[hk]; }
  if (!st.focusId && raw.focusId && getVerse(raw.focusId)) { st.focusId = raw.focusId; st.focusSince = raw.focusSince || new Date().toISOString(); }
  return counts;
}
S.onFileOpened = function (text, name) {
  try {
    var raw = JSON.parse(String(text).replace(/^\uFEFF/, ''));
    if (Array.isArray(raw) && raw.length && raw[0].torah && raw[0].date) {
      var t = loadTorahStore(); if (raw[0].number !== undefined) t.portions = raw; else t.special = raw;
      if (raw.every(function (r) { return r.number === undefined || r.number === null; })) { t.special = raw; } else { t.portions = raw; }
      localStorage.setItem('selah.torah', JSON.stringify(t)); applyTorah(); toast('Torah readings imported (' + raw.length + ')'); refresh(); return;
    }
    if (raw && (raw.verses || raw.bsfAnswers || raw.reflections)) {
      var c = mergeState(raw); save(); refresh();
      toast('Imported: ' + c.answers + ' answers, ' + c.verses + ' verses, ' + c.reflections + ' reflections, ' + c.notes + ' notes');
      return;
    }
    toast('That file is not a Selah backup or Torah file.');
  } catch (e) { toast('Could not read that file.'); }
};
function loadTorahStore() { try { return JSON.parse(localStorage.getItem('selah.torah') || '{}') || {}; } catch (e) { return {}; } }
function applyTorah() {
  if (S.data.torah && !S.data.torahMissing) return;
  var t = loadTorahStore();
  if (t.portions || t.special) { S.data.torah = { portions: t.portions || [], special: t.special || [] }; S.data.torahMissing = false; }
}

// ------------------------------------------------------------------ theme
function setTheme(t) {
  st.theme = t === 'Dark' ? 'Dark' : 'Light'; save();
  if (st.theme === 'Dark') document.documentElement.setAttribute('data-theme', 'dark'); else document.documentElement.removeAttribute('data-theme');
  $('themeBtn').innerHTML = ''; $('themeBtn').appendChild(icon(st.theme === 'Dark' ? 'sun' : 'moon'));
  if (Android && Android.setDarkTheme) Android.setDarkTheme(st.theme === 'Dark');
}

// ------------------------------------------------------------------ reminders
var REMINDER_TIMES = ['10:00', '12:30', '14:00', '16:30'];
var lastScheduleKey = '';
function scheduleReminders(force) {
  if (!Android || !Android.scheduleReminders) return;
  var f = getFocus();
  var body = f ? 'Can you recall ' + f.reference + '?' : "Read and memorize today's verse.";
  var key = st.remindersOn + '|' + body;
  if (!force && key === lastScheduleKey) return;
  lastScheduleKey = key;
  Android.scheduleReminders(!!st.remindersOn, 'A moment to remember', body);
}
function checkReminder(fromNotification) {
  if (practiceOpen || sheetStack.length) return;
  var now = new Date();
  if (!fromNotification && (now.getHours() < 10 || now.getHours() >= 17)) return;
  var focus = getFocus();
  if (!focus && !st.offerDailyWhenNoFocus) return;
  getDaily().then(function (d) {
    if (!focus && doneToday(todaysPracticeVerse(d), now)) return;
    var today = isoDate(now), start = focus ? new Date(st.focusSince || now) : new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var rid = focus ? focus.id : 'daily-' + st.daily.index, due = null;
    REMINDER_TIMES.forEach(function (clock) {
      var p = clock.split(':'), t = new Date(now.getFullYear(), now.getMonth(), now.getDate(), +p[0], +p[1]);
      if (t > now || t < start) return;
      var k = today + '|' + rid + '|' + clock;
      if (st.delivered.indexOf(k) < 0) { due = k; st.delivered.push(k); }
    });
    if (!due && !fromNotification) return;
    save();
    if (focus) showPractice(focus); else showDailyInvitation();
  });
}
S.onReminder = function () { go('today', true); setTimeout(function () { checkReminder(true); }, 350); };

// ------------------------------------------------------------------ passage search
function showSearch() {
  var rec = openSheet({ caption: 'Open a passage', title: 'Where would you like to read?', tile: iconTile('search', 'c-blue') });
  var input = el('input', { class: 'field', placeholder: 'e.g. Romans 8:28, Psalm 23, John 3', enterkeyhint: 'go' });
  var msg = el('div', { class: 'small muted', style: 'margin-top:8px' });
  function open() {
    var q = input.value.trim(); if (!q) return;
    var f = findRefs(q);
    if (f.links.length) { closeSheet(); setTimeout(function () { showScripture(f.links.map(function (l) { return l.reference; }).join('; ')); }, 260); return; }
    var b = resolveBook(q);
    if (b) { closeSheet(); bibleState.book = b; bibleState.chapter = 1; go('bible'); return; }
    msg.textContent = 'Type a reference such as John 3:16, Romans 8 or Psalm 23:1-4.';
  }
  input.addEventListener('keydown', function (e) { if (e.key === 'Enter') open(); });
  rec.body.appendChild(input); rec.body.appendChild(msg);
  rec.foot.appendChild(el('button', { class: 'btn primary', text: 'Open', onclick: open }));
  setTimeout(function () { input.focus(); }, 300);
}

// ------------------------------------------------------------------ start
function init() {
  loadState();
  applyTorah();
  if (S.data.torah && !S.data.torahMissing) S.data.torahMissing = false;
  $('logoBtn').appendChild(icon('book'));
  $('searchBtn').appendChild(icon('search'));
  $('fab').appendChild(icon('plus'));
  document.querySelectorAll('#tabbar [data-icon]').forEach(function (p) { p.appendChild(icon(p.getAttribute('data-icon'))); });
  document.querySelectorAll('#tabbar button').forEach(function (b) { b.addEventListener('click', function () { var t = b.getAttribute('data-tab'); history = []; if (t === 'romans') romansState.follow = true; go(t, true); }); });
  $('searchBtn').addEventListener('click', showSearch);
  $('themeBtn').addEventListener('click', function () { setTheme(st.theme === 'Dark' ? 'Light' : 'Dark'); });
  $('logoBtn').addEventListener('click', function () { history = []; go('today', true); });
  $('fab').addEventListener('click', function () { showAddVerse(); });
  setTheme(st.theme);
  ensureDaily();
  updateSub();
  go('today', true);
  scheduleReminders(true);
  pushDailyToPhone(true);
  var day = isoDate(new Date());
  setInterval(function () {
    var now = isoDate(new Date());
    if (now !== day) { day = now; journalDate = now; ensureDaily(); refresh(); pushDailyToPhone(false); }
    checkReminder(false);
  }, 30000);
  setTimeout(function () {
    if (location.hash === '#reminder' || (Android && Android.consumeReminder && Android.consumeReminder())) S.onReminder();
    else checkReminder(false);
  }, 600);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) { var now = isoDate(new Date()); if (now !== day) { day = now; ensureDaily(); refresh(); } } });
}
// Exposed for testing
S.debug = { planAhead: planAhead, findRefs: findRefs, parsePassages: parsePassages, lessonForDate: lessonForDate, weekStart: weekStart, hebrewDate: hebrewDate, getDaily: getDaily, st: function () { return st; }, go: go, showScripture: showScripture, showPractice: showPractice, getFocus: getFocus, addVerse: addVerse, questionParts: questionParts, mergeState: mergeState, exportHtml: exportHtml };
init();
})();
