# =====================================================================================
# Selah.ps1 - the Selah desktop app (Windows PowerShell 5.1 + WPF).
#
# How this file is organised:
#   1. Startup safety: error trap, hidden console, single-instance lock.
#   2. App state: the in-memory lists that mirror %LOCALAPPDATA%\Selah\state.json.
#   3. Themes: the Chalk Light/Dark palettes and Set-Theme.
#   4. Saving and loading state.json.
#   5. Verses, the daily verse and practice (type from memory, hints, peek).
#   6. Shortcuts, settings, page switching and the Home / My verses / Reflections / Bible pages.
#   7. Reminders, then window creation, event wiring, the tray icon and the 30-second timer.
# Other features live in StudyFeatures.ps1 (Scripture, Torah), BibleFeatures.ps1 (highlights,
# book list) and WeekFeatures.ps1 (Week page), which are dot-sourced into this script's scope.
# Save this file as UTF-8 with BOM, or Windows PowerShell will misread its special characters.
# =====================================================================================
param([switch]$TestMode, [string]$SnapshotPath, [ValidateSet('Home','Week','Bible','Highlights','Library','Journal','Torah','Settings')][string]$SnapshotPage = 'Home', [ValidateSet('','Light','Dark')][string]$SnapshotTheme = '')

trap {
    # Show any startup problem instead of closing silently (Selah runs without a console window).
    $problem = ($_.Exception.Message) + "`r`n`r`nWhere:`r`n" + $_.ScriptStackTrace + "`r`n`r`n" + ($_ | Out-String)
    try { [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'startup-error.log'), $problem) } catch { }
    if (-not $TestMode) {
        try { Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show("Selah could not start.`n`n$problem", 'Selah', 'OK', 'Error') | Out-Null } catch { }
    }
    break
}

# Selah is a self-contained Windows Presentation Foundation application.
# User data is stored under LocalAppData unless SELAH_DATA_DIR is set.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Small native helpers: hide any console window that hosts this script, and colour the title bar for dark mode.
try {
    if (-not ('SelahNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SelahNative {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
'@ -ErrorAction Stop
    }
    if (-not $TestMode) {
        $consoleWindow = [SelahNative]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) { [SelahNative]::ShowWindow($consoleWindow, 0) | Out-Null }
    }
} catch { }

# Allow only one copy of Selah at a time (a named mutex); a second launch explains and exits.
$script:instanceMutex = $null
if (-not $TestMode) {
    $createdNew = $false
    $script:instanceMutex = [System.Threading.Mutex]::new($true, 'Local\SelahDesktopApp', [ref]$createdNew)
    if (-not $createdNew) {
        [System.Windows.MessageBox]::Show('Selah is already running. Open it from the tray, or quit it there before launching the updated version.', 'Selah', 'OK', 'Information') | Out-Null
        $script:instanceMutex.Dispose()
        return
    }
}

# ------------------------------------------------------------------ App state
# The WPF application object. It keeps running when the window is closed (Selah lives in the tray).
$script:app = [System.Windows.Application]::new()
$script:app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
# Where user data lives. Tests point SELAH_DATA_DIR at a temporary folder.
$script:dataDir = if ($env:SELAH_DATA_DIR) { $env:SELAH_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'Selah' }
$script:dataFile = Join-Path $script:dataDir 'state.json'
# In-memory copies of what state.json stores. Save-State writes them back.
$script:verses = [System.Collections.Generic.List[object]]::new()
$script:reflections = [System.Collections.Generic.List[object]]::new()
$script:bibleNotes = [System.Collections.Generic.List[object]]::new()
$script:delivered = [System.Collections.Generic.List[string]]::new()
$script:dailyUsed = [System.Collections.Generic.List[int]]::new()
$script:focusId = ''
$script:focusSince = ''
$script:offerDailyWhenNoFocus = $true
$script:daily = $null
$script:theme = 'Light'
$script:translation = 'BSB'
$script:dailyPoolVersion = 2
$script:referenceRegex = $null
# The 446-verse daily pool (references only; text comes from the chosen translation).
$script:dailyVerses = [object[]](Get-Content -LiteralPath (Join-Path $PSScriptRoot 'daily-verses.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
# Reads one personal study file from StudyData (for example the Torah card).
# Returns an empty array when the file is missing, so Selah still starts without it.
# Personal study files (not in the public repository). Selah still runs when they are missing.
function Read-StudyJson([string]$name) {
    $path = Join-Path $PSScriptRoot "StudyData\$name"
    if (-not [System.IO.File]::Exists($path)) { return [object[]]@() }
    return [object[]](Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}
$script:torahPortions = Read-StudyJson 'torah-portions.json'
$script:torahSpecialReadings = Read-StudyJson 'torah-special-readings.json'
$script:allBibleBookNames = [object[]](Get-Content -LiteralPath (Join-Path $PSScriptRoot 'BibleData\Books.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
# Runtime-only values: loaded Bible books, which page/date/chapter is open, and flags that stop
# event handlers from reacting to changes made by the code itself.
$script:bibleCache = @{}
$script:torahCurrent = $null
$script:journalDate = (Get-Date).ToString('yyyy-MM-dd')
$script:openingJournalDate = $false
$script:updatingReflectionList = $false
$script:bibleBook = 'Proverbs'
$script:bibleChapter = (Get-Date).Day
$script:bibleVerseKey = ''
$script:quitting = $false
$script:practiceOpen = $false
# Named controls from MainWindow.xaml, filled once the window is loaded (see 'Main window' below).
$script:ui = @{}

# Loads a .xaml window or control from disk and returns the WPF object.
# Windows get the Selah icon and a title bar that follows Light/Dark.
function Load-Xaml([string]$path) {
    $reader = [System.Xml.XmlReader]::Create($path)
    try { $loaded = [System.Windows.Markup.XamlReader]::Load($reader) }
    finally { $reader.Dispose() }
    if ($loaded -is [System.Windows.Window]) {
        if ($script:appIcon) { $loaded.Icon = $script:appIcon }
        $loaded.Add_SourceInitialized({ Set-TitleBarTheme $this })
    }
    return $loaded
}

# Asks Windows (DWM attribute 20, 'immersive dark mode') to draw the window's title bar
# dark or light so it matches the current theme. Fails quietly on older Windows.
function Set-TitleBarTheme($targetWindow) {
    try {
        $handle = [System.Windows.Interop.WindowInteropHelper]::new($targetWindow).Handle
        if ($handle -eq [IntPtr]::Zero) { return }
        $dark = if ($script:theme -eq 'Dark') { 1 } else { 0 }
        [SelahNative]::DwmSetWindowAttribute($handle, 20, [ref]$dark, 4) | Out-Null
    } catch { }
}

# ------------------------------------------------------------------ Themes
# Colour keys used across the XAML files (Text, Card, Accent, Pop, ...). Values are '#RRGGBB' or
# '#AARRGGBB'. Bg/Hero lists become WindowBg/HeroBrush; with equal colours they are flat fills.
$script:palettes = @{
    # Chalk palette: chalk #F7F7F1 (60%), ink #0A0A0A (30%), lime #C7FF2E (10%), mist #C9D0D6, slate #6F7780.
    Light = @{
        Pane = '#EEEFEA'; Card = '#EEEFEA'; CardHover = '#E6E8E3'; CardAlt = '#E4E7E8'; CardBorder = '#170A0A0A'
        Field = '#FBFBF7'; FieldBorder = '#C9D0D6'; Control = '#FBFBF7'; ControlBorder = '#1F0A0A0A'
        Hover = '#0F0A0A0A'; Divider = '#DDE1E5'; DialogBg = '#F7F7F1'
        Text = '#0A0A0A'; TextSecondary = '#555D66'; TextTertiary = '#6F7780'
        Accent = '#0A0A0A'; AccentHover = '#26282B'; AccentText = '#F7F7F1'; AccentSoft = '#DDE1E5'; AccentSoftHover = '#C9D0D6'
        Success = '#3F6B1F'; SuccessSoft = '#E6F5CF'; Partial = '#555D66'; PartialSoft = '#E4E7E8'; Warning = '#A33A2C'; WarningSoft = '#F2DED9'
        Pop = '#C7FF2E'; PopHover = '#D6FF66'; PopText = '#0A0A0A'
        HeroText = '#F7F7F1'; HeroCaption = '#C7FF2E'; TileBg = '#0A0A0A'; TileFg = '#C7FF2E'
        ScrollThumb = '#666F7780'
        Bg = @('#F7F7F1', '#F7F7F1', '#F7F7F1')
        Hero = @('#0A0A0A', '#0A0A0A')
    }
    Dark = @{
        Pane = '#161718'; Card = '#161718'; CardHover = '#1D1F21'; CardAlt = '#111213'; CardBorder = '#17F7F7F1'
        Field = '#111213'; FieldBorder = '#33373C'; Control = '#1D1F21'; ControlBorder = '#1FF7F7F1'
        Hover = '#0FF7F7F1'; Divider = '#26292D'; DialogBg = '#0A0A0A'
        Text = '#F7F7F1'; TextSecondary = '#C9D0D6'; TextTertiary = '#8B939C'
        Accent = '#C9D0D6'; AccentHover = '#DDE2E6'; AccentText = '#0A0A0A'; AccentSoft = '#23262A'; AccentSoftHover = '#2E3236'
        Success = '#A8D86A'; SuccessSoft = '#1C2612'; Partial = '#C9D0D6'; PartialSoft = '#23262A'; Warning = '#F09484'; WarningSoft = '#33160F'
        Pop = '#C7FF2E'; PopHover = '#D6FF66'; PopText = '#0A0A0A'
        HeroText = '#F7F7F1'; HeroCaption = '#C7FF2E'; TileBg = '#23262A'; TileFg = '#C7FF2E'
        ScrollThumb = '#668B939C'
        Bg = @('#0A0A0A', '#0A0A0A', '#0A0A0A')
        Hero = @('#161718', '#161718')
    }
}

# Turns a hex colour such as '#F7F7F1' (or '#AARRGGBB') into a frozen WPF brush.
# Frozen brushes are faster and can be shared between windows.
function New-ColorBrush([string]$hex) {
    $brush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
    $brush.Freeze()
    return $brush
}

# Builds a diagonal gradient from a list of colours (the Chalk theme passes the same colour
# several times, which gives a flat fill).
function New-GradientBrush([string[]]$colors) {
    $brush = [System.Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [System.Windows.Point]::new(0,0)
    $brush.EndPoint = [System.Windows.Point]::new(1,1)
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.ColorConverter]::ConvertFromString($colors[$i]), $i / [math]::Max(1, $colors.Count - 1)))
    }
    $brush.Freeze()
    return $brush
}

# Switches the whole app to the Light or Dark Chalk palette.
# Every colour in $script:palettes is written into Application.Resources, and controls that use
# DynamicResource/SetResourceReference repaint immediately. Old theme names from phone backups
# (Dusk, Midnight, Harbor Night) map to Dark; anything else maps to Light.
function Set-Theme([string]$name) {
    # Older phone backups may carry themes that no longer exist: dark ones become Dark, the rest Light.
    $name = if ($name -in @('Dark','Dusk','Midnight','Harbor Night')) { 'Dark' } else { 'Light' }
    $script:theme = $name
    $palette = $script:palettes[$name]
    $resources = $script:app.Resources
    foreach ($key in $palette.Keys) {
        $value = $palette[$key]
        if ($value -is [string] -and $value.StartsWith('#')) { $resources[$key] = New-ColorBrush $value }
    }
    $resources['WindowBg'] = New-GradientBrush $palette.Bg
    $resources['HeroBrush'] = New-GradientBrush $palette.Hero
    if ($script:window) {
        Set-TitleBarTheme $script:window
        foreach ($owned in $script:window.OwnedWindows) { Set-TitleBarTheme $owned }
        if ($script:ui.ContainsKey('ThemeQuickIcon')) {
            # Moon in light mode (switch to dark), sun in dark mode (switch to light).
            $script:ui.ThemeQuickIcon.Text = if ($name -eq 'Dark') { [string][char]0xE706 } else { [string][char]0xE708 }
        }
        Update-SettingsView
        if ($script:ui.ContainsKey('BibleVersesPanel') -and $script:bibleBook) {
            foreach ($row in $script:ui.BibleVersesPanel.Children) { Paint-VerseRow $row }
            Update-HighlightSwatches $script:bibleVerseKey
            if ($script:ui.HighlightsPage.Visibility -eq 'Visible') { Update-HighlightsPage }
        }
    }
}

# Writes everything the user owns to state.json (verses, reflections, notes, highlights, weeks,
# settings). It writes to a temporary file first and then swaps it in, keeping state.bak as the
# previous copy, so a crash mid-save can never leave a half-written file.
function Save-State {
    [System.IO.Directory]::CreateDirectory($script:dataDir) | Out-Null
    $state = [pscustomobject]@{
        version = 1
        verses = @($script:verses.ToArray())
        reflections = @($script:reflections.ToArray())
        bibleNotes = @($script:bibleNotes.ToArray())
        delivered = @($script:delivered.ToArray())
        dailyUsed = @($script:dailyUsed.ToArray())
        highlights = Get-HighlightsForSave
        focusId = $script:focusId
        focusSince = $script:focusSince
        offerDailyWhenNoFocus = $script:offerDailyWhenNoFocus
        daily = $script:daily
        dailyPoolVersion = $script:dailyPoolVersion
        theme = $script:theme
        translation = $script:translation
        weeks = $script:weeks
        habits = @($script:habits.ToArray())
    }
    $json = ConvertTo-Json -InputObject $state -Depth 12
    $tempFile = Join-Path $script:dataDir ('state.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))
    try {
        if ([System.IO.File]::Exists($script:dataFile)) {
            [System.IO.File]::Replace($tempFile, $script:dataFile, (Join-Path $script:dataDir 'state.bak'))
        } else {
            [System.IO.File]::Move($tempFile, $script:dataFile)
        }
    } finally {
        if ([System.IO.File]::Exists($tempFile)) { [System.IO.File]::Delete($tempFile) }
    }
}

# Reads state.json at startup and fills the in-memory lists. Missing fields keep their defaults.
# If the file cannot be read the user is told where the backup is instead of losing data.
function Load-State {
    if (-not [System.IO.File]::Exists($script:dataFile)) { return }
    try {
        $raw = Get-Content -LiteralPath $script:dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($v in @($raw.verses)) { if ($null -ne $v -and $v.id) { $script:verses.Add($v) } }
        foreach ($r in @($raw.reflections)) { if ($null -ne $r -and $r.date) { $script:reflections.Add($r) } }
        foreach ($n in @($raw.bibleNotes)) { if ($null -ne $n -and $n.key) { $script:bibleNotes.Add($n) } }
        foreach ($d in @($raw.delivered)) { if ($d) { $script:delivered.Add([string]$d) } }
        foreach ($index in @($raw.dailyUsed)) { if ($null -ne $index) { $script:dailyUsed.Add([int]$index) } }
        Read-Highlights $raw.highlights
        Read-WeekData $raw
        # Romans (BSF) study was removed. Keep a one-time copy of any old answers beside state.json.
        if ($null -ne $raw.bsfAnswers -and @($raw.bsfAnswers).Count) {
            $archive = Join-Path $script:dataDir 'bsf-answers-archive.json'
            if (-not [System.IO.File]::Exists($archive)) {
                [System.IO.File]::WriteAllText($archive, (ConvertTo-Json -InputObject @($raw.bsfAnswers) -Depth 4), [System.Text.UTF8Encoding]::new($false))
            }
        }
        $script:focusId = [string]$raw.focusId
        $script:focusSince = [string]$raw.focusSince
        if ($null -ne $raw.offerDailyWhenNoFocus) { $script:offerDailyWhenNoFocus = [bool]$raw.offerDailyWhenNoFocus }
        $script:daily = $raw.daily
        if ($raw.theme) { $script:theme = [string]$raw.theme }
        if ($raw.translation) { $script:translation = [string]$raw.translation }
        if ([int]$raw.dailyPoolVersion -ne $script:dailyPoolVersion) {
            # The old 12-verse list used different index numbers; start the new whole-Bible cycle fresh.
            $script:dailyUsed.Clear()
            $script:daily = $null
        }
    } catch {
        [System.Windows.MessageBox]::Show("Saved data could not be read. A backup may be in $script:dataDir`n`n$($_.Exception.Message)", 'Selah', 'OK', 'Warning') | Out-Null
    }
}

# Finds a saved verse by its id, or returns $null.
function Get-Verse([string]$id) {
    foreach ($v in $script:verses) { if ($v.id -eq $id) { return $v } }
    return $null
}

# Returns the verse currently being memorized (the 'focus'), unless it is already memorized.
function Get-Focus {
    $v = Get-Verse $script:focusId
    if ($null -ne $v -and -not $v.memorizedAt) { return $v }
    return $null
}

# Makes a saved verse the focus for practice reminders and remembers when that started.
function Set-Focus([string]$id) {
    $v = Get-Verse $id
    if ($null -eq $v -or $v.memorizedAt) { return }
    $script:focusId = $id
    $script:focusSince = (Get-Date).ToString('o')
    Save-State
    Update-View
}

# Makes sure today's verse of the day is chosen. A verse is picked at random from the
# 446-verse pool, never repeating until every verse has been shown once.
function Ensure-DailyVerse {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if ($null -ne $script:daily -and $script:daily.date -eq $today -and
        [int]$script:daily.index -ge 0 -and [int]$script:daily.index -lt $script:dailyVerses.Count) {
        if (-not $script:dailyUsed.Contains([int]$script:daily.index)) {
            $script:dailyUsed.Add([int]$script:daily.index)
            Save-State
        }
        return
    }
    $previous = if ($null -ne $script:daily) { [int]$script:daily.index } else { -1 }
    if ($script:dailyUsed.Count -ge $script:dailyVerses.Count) { $script:dailyUsed.Clear() }
    $choices = @(0..($script:dailyVerses.Count - 1) | Where-Object {
        -not $script:dailyUsed.Contains([int]$_) -and ([int]$_ -ne $previous -or $script:dailyVerses.Count -eq 1)
    })
    if (-not $choices.Count) { $choices = @(0..($script:dailyVerses.Count - 1) | Where-Object { [int]$_ -ne $previous }) }
    $index = [int](Get-Random -InputObject $choices)
    $script:dailyUsed.Add($index)
    $script:daily = [pscustomobject]@{ date = $today; index = $index }
    Save-State
}

# Returns the verse-of-the-day reference and its text in the chosen translation.
# 'startsWith' trims Psalm headings so the verse starts where the pool entry says.
function Get-DailyVerse([int]$index = -1) {
    if ($index -lt 0) { $index = [int]$script:daily.index }
    $entry = $script:dailyVerses[$index]
    $text = Get-VerseText ([string]$entry.reference)
    if ($entry.startsWith) {
        $at = $text.IndexOf([string]$entry.startsWith, [StringComparison]::Ordinal)
        if ($at -gt 0) { $text = $text.Substring($at) }
    }
    return [pscustomobject]@{ reference = [string]$entry.reference; text = $text.Trim() }
}

# The 'Another' button: picks a different, not-yet-seen verse for today.
function New-DailyVerse {
    # "Another" on the home card: choose a different, not-yet-seen verse for today.
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $current = if ($null -ne $script:daily) { [int]$script:daily.index } else { -1 }
    if ($script:dailyUsed.Count -ge $script:dailyVerses.Count) { $script:dailyUsed.Clear() }
    $choices = @(0..($script:dailyVerses.Count - 1) | Where-Object { -not $script:dailyUsed.Contains([int]$_) -and [int]$_ -ne $current })
    if (-not $choices.Count) { $choices = @(0..($script:dailyVerses.Count - 1) | Where-Object { [int]$_ -ne $current }) }
    $index = [int](Get-Random -InputObject $choices)
    $script:dailyUsed.Add($index)
    $script:daily = [pscustomobject]@{ date = $today; index = $index }
    Save-State
    Update-View
}

# Saves a new memory verse (or reuses an identical one) and optionally makes it the focus.
# $source records where it came from: 'personal', 'daily' or 'bible'.
function Add-Verse([string]$reference, [string]$text, [bool]$makeFocus = $true, [string]$source = 'personal') {
    $reference = $reference.Trim()
    $text = $text.Trim()
    if (-not $reference -or -not $text) { return $null }
    foreach ($existing in $script:verses) {
        if ($existing.reference -eq $reference -and $existing.text -eq $text) {
            if ($makeFocus -and -not $existing.memorizedAt) { Set-Focus $existing.id }
            return $existing
        }
    }
    $v = [pscustomobject]@{
        id = [guid]::NewGuid().ToString('N')
        reference = $reference
        text = $text
        addedAt = (Get-Date).ToString('o')
        passes = 0
        memorizedAt = $null
        lastReviewedAt = $null
        source = $source
    }
    $script:verses.Add($v)
    if ($makeFocus) { Set-Focus $v.id } else { Save-State; Update-View }
    return $v
}

# Simplifies text for comparing answers: lower case, letters and digits only, single spaces.
# This is why capitals and punctuation never count against the user.
function Normalize-Verse([string]$text) {
    # Dashes (-, –, —) separate words, so "come—the" can be typed as "come the".
    $clean = [regex]::Replace($text.ToLowerInvariant(), '\p{Pd}+', ' ')
    $clean = [regex]::Replace($clean, '[\p{P}\p{S}]', '')
    return ([regex]::Replace($clean, '\s+', ' ')).Trim()
}

# True when the typed answer has the same words as the verse (spacing ignored).
function Test-VerseMatch([string]$answerText, [string]$verseText) {
    # Words must match; "come the", "come-the" and "comethe" are all accepted for "come—the".
    $a = Normalize-Verse $answerText
    $b = Normalize-Verse $verseText
    return ($a -eq $b) -or ($a.Replace(' ', '') -eq $b.Replace(' ', ''))
}

# Splits text into words. Dashes count as spaces, so 'come-the' and 'come—the' are two words.
function Split-VerseWords([string]$text) {
    return @(([regex]::Replace($text, '\p{Pd}+', ' ')).Trim() -split '\s+' | Where-Object { $_ })
}

# Marks each typed word as correct, partial (the word being typed and so far right) or wrong.
# Used by the green/coral live word check under the answer box.
function Get-LiveWords([string]$answerText, [string]$verseText) {
    $expected = @(Split-VerseWords $verseText | Where-Object { (Normalize-Verse $_) })
    $typed = @(Split-VerseWords $answerText)
    if (-not $answerText.Trim()) { return }
    for ($i = 0; $i -lt $typed.Count; $i++) {
        $word = [string]$typed[$i]
        $actual = Normalize-Verse $word
        $target = if ($i -lt $expected.Count) { Normalize-Verse ([string]$expected[$i]) } else { '' }
        $status = if ($actual -and $actual -eq $target) { 'correct' }
                  elseif ($i -eq ($typed.Count - 1) -and $answerText -notmatch '[\s\p{Pd}]$' -and
                          $actual -and $target.StartsWith($actual, [StringComparison]::OrdinalIgnoreCase)) { 'partial' }
                  else { 'wrong' }
        [pscustomobject]@{ word = $word; status = $status }
    }
}

# Index of the first word the user has not typed correctly yet (where a hint should help).
function Get-HintIndex([string]$answerText, [string]$verseText) {
    $expected = @(Split-VerseWords $verseText | Where-Object { (Normalize-Verse $_) })
    $typed = @(Split-VerseWords $answerText)
    $index = 0
    while ($index -lt $typed.Count -and $index -lt $expected.Count -and
           (Normalize-Verse ([string]$typed[$index])) -eq (Normalize-Verse ([string]$expected[$index]))) { $index++ }
    return $index
}

# Builds the hint message for the next word. Each press of Hint shows one more letter,
# up to three letters; short words are shown whole.
function Get-NextHint([string]$answerText, [string]$verseText, [int]$level = 1) {
    $expected = @(Split-VerseWords $verseText | Where-Object { (Normalize-Verse $_) })
    $typed = @(Split-VerseWords $answerText)
    $index = 0
    while ($index -lt $typed.Count -and $index -lt $expected.Count -and
           (Normalize-Verse ([string]$typed[$index])) -eq (Normalize-Verse ([string]$expected[$index]))) { $index++ }
    if ($index -ge $expected.Count) { return 'You have reached the end. Check your answer.' }
    # Each press shows one more letter of the next word, up to three letters.
    $word = ([string]$expected[$index]).Trim([char[]](',.;:!?"''()[]' + [char]0x201C + [char]0x201D + [char]0x2018 + [char]0x2019))
    if (-not $word) { $word = [string]$expected[$index] }
    $level = [math]::Max(1, [math]::Min(3, $level))
    if ($word.Length -le $level) { return ('Hint: word {0} is "{1}".' -f ($index + 1), $word) }
    $shown = $word.Substring(0, $level) + [char]0x2026
    if ($level -lt 3) { return ('Hint: word {0} starts with "{1}". Press Hint again for one more letter.' -f ($index + 1), $shown) }
    return ('Hint: word {0} starts with "{1}". That is as far as Hint goes; you have got this.' -f ($index + 1), $shown)
}

# Hold-to-peek: shows the verse with the word the user is up to underlined in lime,
# and scrolls the peek panel so that word is visible.
# Peek: mark the word you are up to and scroll the verse so that word is in view.
function Show-PeekAt($answer, [string]$verseText, $peekText, $peekScroll) {
    $peekText.Inlines.Clear()
    $target = Get-HintIndex $answer.Text $verseText
    $count = 0
    $mark = $null
    $position = 0
    foreach ($m in [regex]::Matches($verseText, '\S+')) {
        $words = @(Split-VerseWords $m.Value | Where-Object { (Normalize-Verse $_) }).Count
        if ($null -eq $mark -and $words -gt 0 -and $target -lt ($count + $words)) {
            if ($m.Index -gt $position) { $peekText.Inlines.Add([System.Windows.Documents.Run]::new($verseText.Substring($position, $m.Index - $position))) }
            $mark = [System.Windows.Documents.Run]::new($m.Value)
            $mark.SetResourceReference([System.Windows.Documents.TextElement]::ForegroundProperty, 'HeroCaption')
            $mark.TextDecorations = [System.Windows.TextDecorations]::Underline
            $peekText.Inlines.Add($mark)
            $position = $m.Index + $m.Length
        }
        $count += $words
    }
    if ($position -lt $verseText.Length) { $peekText.Inlines.Add([System.Windows.Documents.Run]::new($verseText.Substring($position))) }
    $peekScroll.ScrollToTop()
    if ($null -eq $mark) { return }
    try {
        $peekScroll.UpdateLayout()
        $rect = $mark.ContentStart.GetCharacterRect([System.Windows.Documents.LogicalDirection]::Forward)
        $peekScroll.ScrollToVerticalOffset([math]::Max(0, $rect.Top - 40))
    } catch { }
}

# Keeps the live word check scrolled to the word under the text cursor.
# At the end of the answer it simply scrolls to the bottom.
# Keep the live word check scrolled to the word being typed.
function Show-CaretWord($answer, $panel, $scroll) {
    if ($panel.Children.Count -eq 0) { $scroll.ScrollToTop(); return }
    $before = $answer.Text.Substring(0, [math]::Min($answer.CaretIndex, $answer.Text.Length))
    $index = @(Split-VerseWords $before).Count - 1
    if ($before -match '[\s\p{Pd}]$') { $index++ }
    $index = [math]::Max(0, [math]::Min($index, $panel.Children.Count - 1))
    if ($index -ge $panel.Children.Count - 1) { $scroll.ScrollToEnd(); return }
    $panel.UpdateLayout()
    $panel.Children[$index].BringIntoView()
}

# Rebuilds the coloured word chips under the answer box from Get-LiveWords.
function Update-WordFeedback([string]$answerText, [string]$verseText, $panel) {
    $panel.Children.Clear()
    foreach ($word in @(Get-LiveWords $answerText $verseText)) {
        if ($null -eq $word) { continue }
        $chip = [System.Windows.Controls.Border]::new()
        $chip.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $chip.Margin = [System.Windows.Thickness]::new(2)
        $chip.Padding = [System.Windows.Thickness]::new(5,3,5,3)
        $label = [System.Windows.Controls.TextBlock]::new()
        $label.Text = $word.word
        $label.FontSize = 14
        $label.FontWeight = [System.Windows.FontWeights]::SemiBold
        $keys = switch ($word.status) {
            'correct' { @('Success','SuccessSoft') }
            'partial' { @('Partial','PartialSoft') }
            default { @('Warning','WarningSoft') }
        }
        $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $keys[0])
        $chip.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $keys[1])
        $chip.Child = $label
        $panel.Children.Add($chip) | Out-Null
    }
}

# Hides every place the verse is visible on the main window while practice is open,
# so the user cannot read the answer behind the dialog.
function Hide-PracticeSources {
    $script:ui.DailyText.Text = 'Verse hidden while you practice.'
    $script:ui.SelectedText.Text = 'Verse hidden while you practice.'
    $script:ui.BibleVersesPanel.Visibility = 'Hidden'
}

# Opens the Add verse / Edit verse dialog. 'Fill in' looks the text up in the chosen
# translation; saving validates both fields and then adds or updates the verse.
function Show-AddVerse($editVerse = $null) {
    $dialog = Load-Xaml (Join-Path $PSScriptRoot 'AddVerseWindow.xaml')
    $dialog.Owner = $script:window
    $reference = $dialog.FindName('ReferenceInput')
    $verseText = $dialog.FindName('VerseInput')
    $validation = $dialog.FindName('ValidationLabel')
    if ($null -ne $editVerse) {
        $dialog.Title = 'Edit verse — Selah'
        $dialog.FindName('DialogTitle').Text = 'Edit verse'
        $dialog.FindName('DialogCaption').Text = 'CHANGE THE WORDING'
        $dialog.FindName('SaveButton').Content = 'Save changes'
        $reference.Text = [string]$editVerse.reference
        $verseText.Text = [string]$editVerse.text
    }
    $dialog.FindName('CancelButton').Add_Click({ $dialog.DialogResult = $false })
    $dialog.FindName('FillVerseButton').Add_Click({
        $found = Find-ScriptureReferences $reference.Text
        if (-not @($found.links).Count) { $validation.Text = 'Type a reference such as John 3:16 first.'; return }
        $text = Get-VerseText ([string]$found.links[0].reference)
        if (-not $text) { $validation.Text = 'That passage could not be found.'; return }
        $reference.Text = [string]$found.links[0].reference
        $verseText.Text = $text
        $validation.Text = "Filled in from the $(Get-TranslationName). Edit the wording if you like."
    })
    $dialog.FindName('SaveButton').Add_Click({
        if (-not $reference.Text.Trim() -or -not $verseText.Text.Trim()) {
            $validation.Text = 'Please enter a reference and the verse text.'
            return
        }
        $dialog.Tag = [pscustomobject]@{ reference = $reference.Text; text = $verseText.Text }
        $dialog.DialogResult = $true
    })
    $reference.Focus() | Out-Null
    if ($dialog.ShowDialog() -eq $true) {
        if ($null -ne $editVerse) {
            $editVerse.reference = $dialog.Tag.reference.Trim()
            $editVerse.text = $dialog.Tag.text.Trim()
            Save-State
            Update-View
        } else {
            Add-Verse $dialog.Tag.reference $dialog.Tag.text | Out-Null
        }
        Show-Page 'Library'
    }
}

# Counts one correct recitation. Three passes move a verse into the memorized collection.
# For an already memorized verse it only records the review date. Returns the message to show.
function Record-Pass($verse) {
    if ($verse.memorizedAt) {
        if ($null -eq $verse.PSObject.Properties['lastReviewedAt']) { $verse | Add-Member -NotePropertyName lastReviewedAt -NotePropertyValue $null }
        $verse.lastReviewedAt = (Get-Date).ToString('o')
        Save-State
        Update-View
        return 'Passed! You still remember this verse.'
    }
    $verse.passes = [int]$verse.passes + 1
    $mastered = $verse.passes -ge 3
    if ($mastered) {
        $verse.memorizedAt = (Get-Date).ToString('o')
        if ($script:focusId -eq $verse.id) {
            $script:focusId = ''
            $script:focusSince = ''
            foreach ($candidate in $script:verses) {
                if (-not $candidate.memorizedAt -and $candidate.source -ne 'daily') {
                    $script:focusId = $candidate.id
                    $script:focusSince = (Get-Date).ToString('o')
                    break
                }
            }
        }
    }
    Save-State
    Update-View
    if ($mastered) { return 'Beautifully done. This verse is now in your memorized collection.' }
    return "Passed! $($verse.passes) of 3 correct recitations completed."
}

# Works out whether a saved verse uses BSB wording, KJV wording or the user's own wording.
# Shown as a small badge in the practice dialog.
function Get-WordingSource($verse) {
    # Which wording is this verse saved in? Compared word-for-word with the BSB and KJV text.
    $saved = Normalize-Verse ([string]$verse.text)
    foreach ($code in @('BSB', 'KJV')) {
        try {
            $bible = Normalize-Verse (Get-VerseText ([string]$verse.reference) $code)
            if ($bible -and $bible -eq $saved) {
                return [pscustomobject]@{ label = "$code wording"; icon = [string][char]0xE736; color = 'Accent'; tip = "This verse is saved exactly as the $(Get-TranslationName $code) has it." }
            }
            if ($bible -and $bible.Contains($saved) -and $saved.Length -gt 12) {
                return [pscustomobject]@{ label = "Part of the $code"; icon = [string][char]0xE736; color = 'Accent'; tip = "This is a part of the $(Get-TranslationName $code) verse." }
            }
        } catch { }
    }
    return [pscustomobject]@{ label = 'Your own wording'; icon = [string][char]0xE70F; color = 'Partial'; tip = 'You typed or pasted this wording yourself. It is not the BSB or KJV text. Edit it in My verses if you want to practise a Bible translation instead.' }
}

# Opens the 'Type it from memory' dialog for a verse: blurs the main window, wires up the
# live word check, hints, hold-to-peek and Check answer, then records a pass when correct.
function Show-Practice($verse, [bool]$scheduled = $false) {
    if ($null -eq $verse -or $script:practiceOpen) { return }
    $script:practiceOpen = $true
    $previousEffect = $script:window.Content.Effect
    try {
        Hide-PracticeSources
        if ($script:window.IsVisible) {
            $blur = [System.Windows.Media.Effects.BlurEffect]::new()
            $blur.Radius = 22
            $script:window.Content.Effect = $blur
        }
        $dialog = Load-Xaml (Join-Path $PSScriptRoot 'PracticeWindow.xaml')
        if ($script:window.IsVisible) { $dialog.Owner = $script:window }
        $answer = $dialog.FindName('AnswerInput')
        $feedback = $dialog.FindName('FeedbackLabel')
        $hint = $dialog.FindName('HintLabel')
        $wordPanel = $dialog.FindName('WordFeedbackPanel')
        $wordScroll = $dialog.FindName('WordFeedbackScroll')
        $dialog.FindName('PracticeReference').Text = $verse.reference
        $wording = Get-WordingSource $verse
        $dialog.FindName('SourceLabel').Text = $wording.label
        $dialog.FindName('SourceIcon').Text = $wording.icon
        $dialog.FindName('SourceBadge').ToolTip = $wording.tip
        $dialog.FindName('SourceLabel').SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $wording.color)
        $dialog.FindName('SourceIcon').SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $wording.color)
        $peekPanel = $dialog.FindName('PeekPanel')
        $peekText = $dialog.FindName('PeekText')
        $peekScroll = $dialog.FindName('PeekScroll')
        $peekText.Text = [string]$verse.text
        $dialog.FindName('PeekCaption').Text = ('PEEK  ·  ' + $wording.label.ToUpperInvariant() + '  ·  RELEASE TO HIDE')
        $peekButton = $dialog.FindName('PeekButton')
        $peekButton.Add_PreviewMouseLeftButtonDown({ $peekPanel.Visibility = 'Visible'; Show-PeekAt $answer ([string]$verse.text) $peekText $peekScroll; $script:peeks++ })
        # While holding, the mouse wheel scrolls the verse.
        $peekButton.Add_PreviewMouseWheel({
            if ($peekPanel.Visibility -eq 'Visible') { $peekScroll.ScrollToVerticalOffset($peekScroll.VerticalOffset - ($_.Delta / 3)); $_.Handled = $true }
        })
        $peekButton.Add_PreviewMouseLeftButtonUp({ $peekPanel.Visibility = 'Collapsed'; $answer.Focus() | Out-Null })
        $peekButton.Add_MouseLeave({ $peekPanel.Visibility = 'Collapsed' })
        $peekButton.Add_PreviewKeyDown({
            if ($_.Key -eq 'Space' -or $_.Key -eq 'Return') {
                if ($peekPanel.Visibility -ne 'Visible') { $peekPanel.Visibility = 'Visible'; Show-PeekAt $answer ([string]$verse.text) $peekText $peekScroll; $script:peeks++ }
                $_.Handled = $true
            } elseif ($peekPanel.Visibility -eq 'Visible' -and ($_.Key -eq 'Down' -or $_.Key -eq 'Up')) {
                $step = if ($_.Key -eq 'Down') { 40 } else { -40 }
                $peekScroll.ScrollToVerticalOffset($peekScroll.VerticalOffset + $step); $_.Handled = $true
            }
        })
        $peekButton.Add_PreviewKeyUp({ if ($_.Key -eq 'Space' -or $_.Key -eq 'Return') { $peekPanel.Visibility = 'Collapsed'; $_.Handled = $true } })
        $script:peeks = 0
        $dialog.FindName('LaterButton').Add_Click({ $dialog.DialogResult = $false })
        $script:hintWord = -1
        $script:hintLevel = 0
        $dialog.FindName('HintButton').Add_Click({
            $wordIndex = Get-HintIndex $answer.Text $verse.text
            if ($wordIndex -eq $script:hintWord) { $script:hintLevel = [math]::Min(3, $script:hintLevel + 1) } else { $script:hintWord = $wordIndex; $script:hintLevel = 1 }
            $hint.Text = Get-NextHint $answer.Text $verse.text $script:hintLevel
        })
        $answer.Add_TextChanged({
            Update-WordFeedback $answer.Text $verse.text $wordPanel
            Show-CaretWord $answer $wordPanel $wordScroll
            $feedback.Text = ''
        })
        $answer.Add_SelectionChanged({ Show-CaretWord $answer $wordPanel $wordScroll })
        $dialog.FindName('CheckButton').Add_Click({
            if (-not $answer.Text.Trim()) { $feedback.Text = 'Type the verse before checking.'; return }
            if ((Test-VerseMatch $answer.Text $verse.text)) {
                $dialog.DialogResult = $true
            } else {
                $feedback.Text = 'Not quite. Review the coral words, then try again. Hint shows the next word one letter at a time.'
            }
        })
        $answer.Focus() | Out-Null
        $passed = $dialog.ShowDialog()
        if ($passed -eq $true) {
            $message = Record-Pass $verse
            [System.Windows.MessageBox]::Show($message, 'Selah', 'OK', 'Information') | Out-Null
        }
    } finally {
        $script:window.Content.Effect = $previousEffect
        $script:ui.BibleVersesPanel.Visibility = 'Visible'
        $script:practiceOpen = $false
        Update-View
    }
}

# Returns today's verse of the day if the user has already saved it as a memory verse.
function Get-TodaysPracticeVerse {
    Ensure-DailyVerse
    $dailyVerse = (Get-DailyVerse)
    foreach ($v in $script:verses) {
        if ($v.reference -eq $dailyVerse.reference -and $v.text -eq $dailyVerse.text) { return $v }
    }
    return $null
}

# True if the daily verse was already practised successfully today (no more invitations).
function Test-DailyCompletedToday($verse, [datetime]$now) {
    if ($null -eq $verse) { return $false }
    foreach ($stamp in @($verse.memorizedAt, $verse.lastReviewedAt)) {
        if (-not $stamp) { continue }
        try { if (([datetime]$stamp).Date -eq $now.Date) { return $true } } catch { }
    }
    return $false
}

# When no verse is in focus: invites the user to read today's verse and then practise it.
function Show-DailyInvitation {
    $todayVerse = (Get-DailyVerse)
    $dialog = Load-Xaml (Join-Path $PSScriptRoot 'DailyInviteWindow.xaml')
    if ($script:window.IsVisible) { $dialog.Owner = $script:window }
    $dialog.FindName('DailyInviteReference').Text = [string]$todayVerse.reference
    $dialog.FindName('DailyInviteText').Text = [string]$todayVerse.text
    $previousPractice = Get-TodaysPracticeVerse
    $dialog.FindName('DailyInviteProgress').Text = if ($null -eq $previousPractice) { 'A fresh verse for today' }
        elseif ($previousPractice.memorizedAt) { 'A verse you know — take a fresh look today' }
        else { '{0} of 3 correct recitations' -f [int]$previousPractice.passes }
    $dialog.FindName('DailyInviteLaterButton').Add_Click({ $dialog.DialogResult = $false })
    $dialog.FindName('DailyInviteReadButton').Add_Click({
        $dialog.FindName('DailyInviteIntro').Visibility = 'Collapsed'
        $dialog.FindName('DailyInviteReading').Visibility = 'Visible'
        $dialog.FindName('DailyInviteReadButton').Visibility = 'Collapsed'
        $dialog.FindName('DailyInviteReadyButton').Visibility = 'Visible'
    })
    $dialog.FindName('DailyInviteReadyButton').Add_Click({ $dialog.DialogResult = $true })
    if ($dialog.ShowDialog() -eq $true) {
        $verse = Get-TodaysPracticeVerse
        if ($null -eq $verse) { $verse = Add-Verse $todayVerse.reference $todayVerse.text $false 'daily' }
        Show-Practice $verse $true
    }
}

# Path of the shortcut in the Windows Startup folder (used by 'Start with Windows').
function Get-StartupShortcutPath {
    return (Join-Path ([Environment]::GetFolderPath('Startup')) 'Selah Scripture.lnk')
}

# Creates or refreshes a .lnk shortcut that starts Selah without a console window.
function Save-SelahShortcut([string]$path, [string]$description) {
    # conhost --headless runs PowerShell with no console window at all, so Windows Terminal never opens.
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = (Join-Path $env:SystemRoot 'System32\conhost.exe')
    $shortcut.Arguments = '--headless "' + (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') + '" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "' + (Join-Path $PSScriptRoot 'Selah.ps1') + '"'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $iconPath = Join-Path $PSScriptRoot 'selah.ico'
    if ([System.IO.File]::Exists($iconPath)) { $shortcut.IconLocation = "$iconPath,0" }
    $shortcut.Description = $description
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

# Path of the optional desktop shortcut.
function Get-DesktopShortcutPath { return (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Selah.lnk') }

# Keeps the folder, Start menu, Startup and desktop shortcuts pointing at the launcher.
function Update-Shortcuts {
    # Keep the folder, Start menu, and sign-in shortcuts pointing at the windowless launcher.
    try {
        Save-SelahShortcut (Join-Path $PSScriptRoot 'Selah.lnk') 'Open Selah'
        Save-SelahShortcut (Join-Path ([Environment]::GetFolderPath('Programs')) 'Selah.lnk') 'Selah — Scripture, remembered'
        if (Get-StartupEnabled) { Save-SelahShortcut (Get-StartupShortcutPath) 'Start Selah at Windows sign-in' }
        if ([System.IO.File]::Exists((Get-DesktopShortcutPath))) { Save-SelahShortcut (Get-DesktopShortcutPath) 'Open Selah' }
    } catch { }
}

# True when Selah is set to start at Windows sign-in.
function Get-StartupEnabled {
    return [System.IO.File]::Exists((Get-StartupShortcutPath))
}

# Turns 'Start with Windows' on or off by adding or removing the Startup shortcut.
function Set-StartupEnabled([bool]$enabled) {
    $path = Get-StartupShortcutPath
    if ($enabled) {
        Save-SelahShortcut $path 'Start Selah at Windows sign-in'
    } elseif ([System.IO.File]::Exists($path)) {
        Remove-Item -LiteralPath $path -Force
    }
}

# Refreshes the Settings page toggles and segment buttons from the current settings.
function Update-SettingsView {
    if (-not $script:ui.ContainsKey('StartupToggleButton')) { return }
    $script:ui.StartupToggleButton.IsChecked = [bool](Get-StartupEnabled)
    $script:ui.DailyOfferToggleButton.IsChecked = [bool]$script:offerDailyWhenNoFocus
    $script:ui.ThemeLightButton.Tag = if ($script:theme -ne 'Dark') { 'Selected' } else { $null }
    $script:ui.ThemeDarkButton.Tag = if ($script:theme -eq 'Dark') { 'Selected' } else { $null }
    $script:ui.TranslationBsbButton.Tag = if ($script:translation -ne 'KJV') { 'Selected' } else { $null }
    $script:ui.TranslationKjvButton.Tag = if ($script:translation -eq 'KJV') { 'Selected' } else { $null }
    $hasDesktop = [System.IO.File]::Exists((Get-DesktopShortcutPath))
    $script:ui.DesktopShortcutButton.Content = if ($hasDesktop) { 'On desktop ✓' } else { 'Add to desktop' }
    $script:ui.DesktopShortcutButton.IsEnabled = -not $hasDesktop
}

# Shows one page of the main window (Home, Week, Bible, ...) and highlights its sidebar button.
# Some pages refresh their content when opened.
function Show-Page([string]$page) {
    foreach ($name in @('Home','Week','Bible','Highlights','Library','Journal','Torah','Settings')) {
        $script:ui["${name}Page"].Visibility = if ($name -eq $page) { 'Visible' } else { 'Collapsed' }
        $script:ui["${name}Nav"].Tag = if ($name -eq $page) { 'Selected' } else { $null }
    }
    if ($page -eq 'Journal') { Open-JournalDate (Get-Date).ToString('yyyy-MM-dd') }
    if ($page -eq 'Highlights') { Update-HighlightsPage }
    if ($page -eq 'Week') { $script:weekStart = ''; $script:weekDay = ''; Update-WeekPage }
}

# Refreshes the Home page: date, greeting, verse of the day, current focus and progress,
# then the verse library, reflections list, reading links, Torah card and settings.
function Update-View {
    Ensure-DailyVerse
    $now = Get-Date
    $script:ui.DateLabel.Text = $now.ToString('dddd, d MMMM yyyy')
    $script:ui.HebrewDateLabel.Text = Get-HebrewDate $now
    $script:ui.GreetingLabel.Text = if ($now.Hour -lt 12) { 'Good morning' } elseif ($now.Hour -lt 17) { 'Good afternoon' } else { 'Good evening' }
    $script:ui.StatusLabel.Text = 'Ready to grow'
    $d = (Get-DailyVerse)
    $script:ui.DailyText.Text = [char]0x201C + $d.text + [char]0x201D
    $script:ui.DailyReference.Text = $d.reference
    $script:ui.DailyVersionLabel.Text = "$($script:translation)  ·  NEW EACH DAY"
    $script:ui.BibleVersionLabel.Text = (Get-TranslationName).ToUpperInvariant()
    $focus = Get-Focus
    $dailyPractice = if ($null -eq $focus) { Get-TodaysPracticeVerse } else { $null }
    $dailyDoneToday = Test-DailyCompletedToday $dailyPractice $now
    $script:ui.PracticeButton.IsEnabled = ($null -ne $focus -or ($script:offerDailyWhenNoFocus -and -not $dailyDoneToday))
    if ($null -ne $focus) {
        $script:ui.FocusTitle.Text = 'CURRENT FOCUS'
        $script:ui.FocusReference.Text = $focus.reference
        $script:ui.FocusHint.Text = 'Write it from memory when you are ready. Three correct recitations complete a verse.'
        $script:ui.FocusProgress.Text = ('PASS {0} / 3' -f [int]$focus.passes)
        $script:ui.PracticeButton.Content = 'Practice now'
    } elseif ($script:offerDailyWhenNoFocus -and $null -ne $dailyPractice -and -not $dailyDoneToday) {
        $script:ui.FocusTitle.Text = "TODAY'S VERSE"
        $script:ui.FocusReference.Text = $dailyPractice.reference
        $script:ui.FocusHint.Text = 'Read it once more, then write it from memory.'
        $script:ui.FocusProgress.Text = if ($dailyPractice.memorizedAt) { 'READY TO REVIEW' } else { 'PASS {0} / 3' -f [int]$dailyPractice.passes }
        $script:ui.PracticeButton.Content = 'Read & practice'
    } else {
        $script:ui.FocusTitle.Text = 'CURRENT FOCUS'
        $script:ui.FocusReference.Text = 'Choose a verse'
        $script:ui.FocusHint.Text = 'Add your own verse or begin with today''s suggestion.'
        $script:ui.FocusProgress.Text = 'READY WHEN YOU ARE'
        $script:ui.PracticeButton.Content = if ($script:offerDailyWhenNoFocus -and $null -eq $dailyPractice) { 'Read today''s verse' } else { 'Practice now' }
    }
    $mastered = @($script:verses | Where-Object { $_.memorizedAt }).Count
    $script:ui.MasteredCount.Text = [string]$mastered
    Update-Library
    Update-ReflectionList
    Refresh-ReadingLinks
    Update-TorahView
    Update-SettingsView
    if ($script:practiceOpen) { Hide-PracticeSources }
}

# Rebuilds the 'My verses' list (memorized, focus and active markers) and keeps the selection.
function Update-Library {
    $selectedId = if ($script:ui.VerseList.SelectedItem) { [string]$script:ui.VerseList.SelectedItem.Tag } else { '' }
    $script:ui.VerseList.Items.Clear()
    foreach ($v in $script:verses) {
        $item = [System.Windows.Controls.ListBoxItem]::new()
        $item.Tag = $v.id
        $label = if ($v.memorizedAt) { '✓  ' } elseif ($v.id -eq $script:focusId) { '●  ' } else { '○  ' }
        $item.Content = $label + $v.reference
        $item.Padding = '10,10'
        $item.Margin = '0,2'
        $script:ui.VerseList.Items.Add($item) | Out-Null
        if ($v.id -eq $selectedId) { $script:ui.VerseList.SelectedItem = $item }
    }
    if ($null -eq $script:ui.VerseList.SelectedItem -and $script:ui.VerseList.Items.Count -gt 0) { $script:ui.VerseList.SelectedIndex = 0 }
    Update-SelectedVerse
}

# Shows the verse selected in 'My verses' with its progress and the buttons that apply to it.
function Update-SelectedVerse {
    $selected = $script:ui.VerseList.SelectedItem
    $v = if ($null -ne $selected) { Get-Verse ([string]$selected.Tag) } else { $null }
    if ($null -eq $v) {
        $script:ui.SelectedState.Text = 'NO VERSES YET'
        $script:ui.SelectedReference.Text = 'Your collection begins here.'
        $script:ui.SelectedText.Text = 'Add a verse to start practicing.'
        $script:ui.SelectedProgress.Text = ''
        $script:ui.FocusSelectedButton.IsEnabled = $false
        $script:ui.PracticeSelectedButton.IsEnabled = $false
        $script:ui.EditSelectedButton.IsEnabled = $false
        return
    }
    $script:ui.SelectedState.Text = if ($v.memorizedAt) { '✓  MEMORIZED' } elseif ($v.id -eq $script:focusId) { '●  CURRENT FOCUS' } else { '○  IN PROGRESS' }
    $script:ui.SelectedReference.Text = $v.reference
    $script:ui.SelectedText.Text = $v.text
    $script:ui.SelectedProgress.Text = if ($v.memorizedAt) { "Memorized $(([datetime]$v.memorizedAt).ToString('dd MMM yyyy'))" } else { "$($v.passes) / 3 correct recitations" }
    $script:ui.SelectedProgress.Text += '   ·   ' + (Get-WordingSource $v).label
    $script:ui.FocusSelectedButton.IsEnabled = -not [bool]$v.memorizedAt
    $script:ui.PracticeSelectedButton.IsEnabled = $true
    $script:ui.EditSelectedButton.IsEnabled = $true
}

# Opens the Reflections editor on a given date (yyyy-MM-dd) and loads that day's text.
function Open-JournalDate([string]$date) {
    $script:openingJournalDate = $true
    try {
        $script:journalDate = $date
        $script:ui.JournalDate.Text = ([datetime]::ParseExact($date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)).ToString('dddd, dd MMMM yyyy').ToUpperInvariant()
        $entry = @($script:reflections | Where-Object { $_.date -eq $date } | Select-Object -First 1)
        $script:ui.JournalEditor.Text = if ($entry.Count) { [string]$entry[0].text } else { '' }
        $script:ui.JournalSavedLabel.Text = 'Autosaves as you type'
    } finally {
        $script:openingJournalDate = $false
    }
    Update-ReflectionList
}

# Rebuilds the list of past reflections, newest first.
function Update-ReflectionList {
    $script:updatingReflectionList = $true
    try {
        $script:ui.ReflectionList.Items.Clear()
        foreach ($r in @($script:reflections | Sort-Object date -Descending)) {
            $item = [System.Windows.Controls.ListBoxItem]::new()
            $item.Tag = $r.date
            $preview = [string]$r.text -replace '\s+', ' '
            if ($preview.Length -gt 30) { $preview = $preview.Substring(0,30) + '…' }
            $item.Content = "$($r.date)`n$preview"
            $item.Padding = '8,9'
            $item.Margin = '0,2'
            $script:ui.ReflectionList.Items.Add($item) | Out-Null
            if ($r.date -eq $script:journalDate) { $script:ui.ReflectionList.SelectedItem = $item }
        }
    } finally {
        $script:updatingReflectionList = $false
    }
}

# Saves the Reflections editor text for the open date (an empty text removes the entry).
# Called on every keystroke, so nothing is ever lost.
function Save-Reflection {
    $text = [string]$script:ui.JournalEditor.Text
    $hasContent = -not [string]::IsNullOrWhiteSpace($text)
    $entry = @($script:reflections | Where-Object { $_.date -eq $script:journalDate } | Select-Object -First 1)
    if ($entry.Count) {
        if ($hasContent) {
            if ([string]$entry[0].text -eq $text) { return }
            $entry[0].text = $text
            $entry[0].savedAt = (Get-Date).ToString('o')
        } else {
            $script:reflections.Remove($entry[0]) | Out-Null
        }
    } elseif ($hasContent) {
        $script:reflections.Add([pscustomobject]@{ date = $script:journalDate; text = $text; savedAt = (Get-Date).ToString('o') })
    } else {
        return
    }
    Save-State
    Update-ReflectionList
    $script:ui.JournalSavedLabel.Text = if ($hasContent) { 'Saved automatically ✓' } else { 'Empty entry removed' }
}

# Today's reading plan: Proverbs <day of month>, then Psalms day, day+30, day+60 ... up to 150.
function Get-TodayReadings([datetime]$date) {
    $day = $date.Day
    [pscustomobject]@{ book = 'Proverbs'; chapter = $day; label = "Proverbs $day" }
    for ($chapter = $day; $chapter -le 150; $chapter += 30) {
        [pscustomobject]@{ book = 'Psalms'; chapter = $chapter; label = "Psalm $chapter" }
    }
}

# Returns one chapter (its verses) of a book in the current translation, or $null.
function Get-BibleChapter([string]$book, [int]$chapter) {
    $data = Get-BibleBookData $book
    if ($null -eq $data) { return $null }
    $chapters = $data.chapters
    if ($chapter -lt 1 -or $chapter -gt $chapters.Count) { return $null }
    return $chapters[$chapter - 1]
}

# Jumps to the chapter number typed in the Bible page's chapter box (or restores the box).
function Apply-ChapterInput {
    $number = 0
    if ([int]::TryParse($script:ui.ChapterNumberInput.Text, [ref]$number) -and (Get-BibleChapter $script:bibleBook $number)) {
        if ($number -ne $script:bibleChapter) { Set-BibleChapter $script:bibleBook $number }
    } else { $script:ui.ChapterNumberInput.Text = [string]$script:bibleChapter }
}

# Finds the note saved for a verse key 'Book|chapter|verse', or $null.
function Get-BibleNote([string]$key) {
    foreach ($note in $script:bibleNotes) { if ($note.key -eq $key) { return $note } }
    return $null
}

# Makes one reading-plan button: a small chip on Home, or a wide row on the Bible page.
function New-ReadingButton($reading, [bool]$wide) {
    $button = [System.Windows.Controls.Button]::new()
    $button.Content = $reading.label
    $button.Tag = "$($reading.book)|$($reading.chapter)"
    $button.Style = $script:app.FindResource($(if ($wide) { 'VerseRowButton' } else { 'RefChip' }))
    $button.Margin = if ($wide) { [System.Windows.Thickness]::new(0,0,0,2) } else { [System.Windows.Thickness]::new(0,0,7,7) }
    if ($wide) {
        $label = [System.Windows.Controls.TextBlock]::new()
        $label.Text = $reading.label
        $label.FontSize = 14
        $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Text')
        $button.Content = $label
    } else {
        $button.FontSize = 13
        $button.Padding = [System.Windows.Thickness]::new(4,2,4,2)
    }
    $button.Add_Click({
        param($sender, $eventArgs)
        $parts = ([string]$sender.Tag) -split '\|'
        Show-Page 'Bible'
        Set-BibleChapter $parts[0] ([int]$parts[1])
    })
    return $button
}

# Rebuilds today's reading buttons on the Home and Bible pages.
function Refresh-ReadingLinks {
    $script:ui.TodayReadingsPanel.Children.Clear()
    $script:ui.BibleTodayPanel.Children.Clear()
    foreach ($reading in @(Get-TodayReadings (Get-Date))) {
        $script:ui.TodayReadingsPanel.Children.Add((New-ReadingButton $reading $false)) | Out-Null
        $script:ui.BibleTodayPanel.Children.Add((New-ReadingButton $reading $true)) | Out-Null
    }
}

# Opens a chapter on the Bible page: title, NIV link, one clickable row per verse (with its
# highlight colour and note marker), and syncs the book list on the left.
function Set-BibleChapter([string]$book, [int]$chapter) {
    $data = Get-BibleChapter $book $chapter
    if ($null -eq $data) { return }
    $script:bibleBook = $book
    $script:bibleChapter = $chapter
    $script:ui.ChapterNumberInput.Text = [string]$chapter
    $script:ui.PreviousChapterButton.IsEnabled = $chapter -gt 1
    $script:ui.NextChapterButton.IsEnabled = $chapter -lt (Get-BibleBookData $book).chapters.Count
    $script:ui.BibleChapterTitle.Text = "$book $chapter"
    Sync-BookList $book $chapter
    $script:ui.BibleVersesPanel.Children.Clear()
    $script:bibleVerseKey = ''
    $script:ui.BibleNoteReference.Text = 'Select a verse to highlight it or write a note'
    Update-HighlightSwatches ''
    $script:ui.BibleNoteEditor.Text = ''
    $script:ui.BibleNoteEditor.IsEnabled = $false
    $script:ui.SaveBibleNoteButton.IsEnabled = $false
    $script:ui.MemorizeBibleVerseButton.IsEnabled = $false
    $script:ui.BibleNoteSavedLabel.Text = ''
    foreach ($verse in $data.verses) {
        $key = "$book|$chapter|$($verse.verse)"
        $button = [System.Windows.Controls.Button]::new()
        $button.Tag = $key
        $button.Style = $script:app.FindResource('VerseRowButton')
        $button.Margin = [System.Windows.Thickness]::new(0,0,0,5)
        $row = [System.Windows.Controls.Grid]::new()
        $numberColumn = [System.Windows.Controls.ColumnDefinition]::new()
        $numberColumn.Width = [System.Windows.GridLength]::new(31)
        $row.ColumnDefinitions.Add($numberColumn)
        $row.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
        $numberLabel = [System.Windows.Controls.TextBlock]::new()
        $numberLabel.Text = [string]$verse.verse
        $numberLabel.FontSize = 12
        $numberLabel.FontWeight = [System.Windows.FontWeights]::Bold
        $numberLabel.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent')
        $numberLabel.Margin = [System.Windows.Thickness]::new(0,4,0,0)
        $row.Children.Add($numberLabel) | Out-Null
        $textLabel = [System.Windows.Controls.TextBlock]::new()
        $textLabel.Text = [string]$verse.text
        $textLabel.TextWrapping = 'Wrap'
        $textLabel.FontFamily = $script:app.FindResource('ReadingFont')
        $textLabel.FontSize = 17
        $textLabel.LineHeight = 28
        $textLabel.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Text')
        if (Get-BibleNote $key) { $numberLabel.Text = [string]$verse.verse + ' •' }
        [System.Windows.Controls.Grid]::SetColumn($textLabel,1)
        $row.Children.Add($textLabel) | Out-Null
        $button.Content = $row
        Paint-VerseRow $button
        $button.Add_Click({
            param($sender, $eventArgs)
            Open-BibleVerse ([string]$sender.Tag)
        })
        $script:ui.BibleVersesPanel.Children.Add($button) | Out-Null
    }
    $script:ui.BibleVerseScroll.ScrollToTop()
}

# Selects a verse on the Bible page: shows its note, highlight swatches and Memorize button.
function Open-BibleVerse([string]$key) {
    $parts = $key -split '\|'
    if ($parts.Count -ne 3) { return }
    $chapter = Get-BibleChapter $parts[0] ([int]$parts[1])
    if ($null -eq $chapter) { return }
    $verse = @($chapter.verses | Where-Object { $_.verse -eq $parts[2] } | Select-Object -First 1)
    if (-not $verse.Count) { return }
    $script:bibleVerseKey = $key
    $bookName = Get-DisplayBookName $parts[0]
    $script:ui.BibleNoteReference.Text = "$($bookName.ToUpperInvariant()) $($parts[1]):$($parts[2])  ·  HIGHLIGHT OR WRITE A NOTE"
    Update-HighlightSwatches $key
    $note = Get-BibleNote $key
    $script:ui.BibleNoteEditor.Text = if ($null -ne $note) { [string]$note.text } else { '' }
    $script:ui.BibleNoteEditor.IsEnabled = $true
    $script:ui.SaveBibleNoteButton.IsEnabled = $true
    $script:ui.MemorizeBibleVerseButton.IsEnabled = $true
    $script:ui.BibleNoteSavedLabel.Text = ''
    foreach ($button in $script:ui.BibleVersesPanel.Children) {
        if ($button.Tag -eq $key) { $button.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, 'AccentSoft') }
        else { $button.Background = [System.Windows.Media.Brushes]::Transparent }
    }
}

# Saves (or clears) the note for the selected verse.
function Save-BibleNote {
    if (-not $script:bibleVerseKey) { return }
    $text = $script:ui.BibleNoteEditor.Text.Trim()
    $note = Get-BibleNote $script:bibleVerseKey
    if ($null -ne $note) {
        if ($text) { $note.text = $text; $note.savedAt = (Get-Date).ToString('o') }
        else { $script:bibleNotes.Remove($note) | Out-Null }
    } elseif ($text) {
        $script:bibleNotes.Add([pscustomobject]@{ key = $script:bibleVerseKey; text = $text; savedAt = (Get-Date).ToString('o') })
    }
    Save-State
    $script:ui.BibleNoteSavedLabel.Text = if ($text) { 'Saved ✓' } else { 'Note removed' }
}

# Adds the selected Bible verse to My verses as the new focus.
function Memorize-BibleVerse {
    if (-not $script:bibleVerseKey) { return }
    $parts = $script:bibleVerseKey -split '\|'
    $chapter = Get-BibleChapter $parts[0] ([int]$parts[1])
    $verse = @($chapter.verses | Where-Object { $_.verse -eq $parts[2] } | Select-Object -First 1)
    if (-not $verse.Count) { return }
    $bookName = Get-DisplayBookName $parts[0]
    Add-Verse "$bookName $($parts[1]):$($parts[2])" ([string]$verse[0].text) | Out-Null
    Show-Page 'Library'
}

# Switches between BSB and KJV and refreshes every page that shows Scripture.
function Set-Translation([string]$code) {
    if ($code -ne 'KJV') { $code = 'BSB' }
    if ($code -eq $script:translation) { Update-SettingsView; return }
    $script:translation = $code
    Save-State
    Update-View
    Set-BibleChapter $script:bibleBook $script:bibleChapter
}

# The four daily practice moments (local time).
function Get-ReminderTimes { return @('10:00','12:30','14:00','16:30') }

# Runs every 30 seconds. Between 10:00 and 17:00 it opens practice (or the daily invitation)
# when a reminder time has passed and was not delivered yet. After a long gap it offers one
# prompt, not a pile of missed ones. A tray balloon appears if the window is hidden.
function Check-Reminder {
    if ($script:practiceOpen) { return }
    $now = Get-Date
    if ($now.Hour -lt 10 -or $now.Hour -ge 17) { return }
    $focus = Get-Focus
    if ($null -eq $focus -and -not $script:offerDailyWhenNoFocus) { return }
    if ($null -eq $focus) {
        $dailyPractice = Get-TodaysPracticeVerse
        if (Test-DailyCompletedToday $dailyPractice $now) { return }
    }
    $start = if ($null -ne $focus) { try { [datetime]$script:focusSince } catch { $now } } else { $now.Date }
    $reminderId = if ($null -ne $focus) { [string]$focus.id } else { "daily-$($script:daily.index)" }
    $today = $now.ToString('yyyy-MM-dd')
    $due = $null
    foreach ($clock in @(Get-ReminderTimes)) {
        $time = [datetime]::ParseExact("$today $clock", 'yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
        if ($time -gt $now -or $time -lt $start) { continue }
        $key = "$today|$reminderId|$clock"
        if (-not $script:delivered.Contains($key)) { $due = $key }
    }
    if (-not $due) { return }
    # On return after downtime, offer one current prompt rather than a stack of missed prompts.
    foreach ($clock in @(Get-ReminderTimes)) {
        $time = [datetime]::ParseExact("$today $clock", 'yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
        $key = "$today|$reminderId|$clock"
        if ($time -le $now -and $time -ge $start -and -not $script:delivered.Contains($key)) { $script:delivered.Add($key) }
    }
    Save-State
    if (-not $script:window.IsVisible) {
        $script:tray.BalloonTipTitle = 'A moment to remember'
        $script:tray.BalloonTipText = if ($null -ne $focus) { "Can you recall $($focus.reference)?" } else { 'Read and memorize today''s verse.' }
        $script:tray.ShowBalloonTip(5000)
    }
    if ($null -ne $focus) { Show-Practice $focus $true } else { Show-DailyInvitation }
}

# ------------------------------------------------------------------ Feature files
# Dot-sourcing runs these files in this script's scope, so they share $script: variables.
. (Join-Path $PSScriptRoot 'StudyFeatures.ps1')
. (Join-Path $PSScriptRoot 'BibleFeatures.ps1')
. (Join-Path $PSScriptRoot 'WeekFeatures.ps1')

# Theme dictionary and colours live in Application.Resources so every window shares them.
# The base URI lets Theme.xaml find the bundled fonts in .\Fonts (Inter and Source Serif 4, SIL OFL).
$themeStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot 'Theme.xaml'))
try {
    $themeContext = [System.Windows.Markup.ParserContext]::new()
    $themeContext.BaseUri = [uri]::new((Join-Path $PSScriptRoot 'Theme.xaml'))
    $script:app.Resources.MergedDictionaries.Add([System.Windows.Markup.XamlReader]::Load($themeStream, $themeContext))
}
finally { $themeStream.Dispose() }
# App icon for windows and the tray.
$script:appIcon = $null
$script:iconPath = Join-Path $PSScriptRoot 'selah.ico'
if ([System.IO.File]::Exists($script:iconPath)) {
    try { $script:appIcon = [System.Windows.Media.Imaging.BitmapFrame]::Create([uri]::new($script:iconPath)) } catch { }
}

# ------------------------------------------------------------------ Start up
# Load saved data, apply the theme and make sure today's verse is chosen before any window opens.
Load-State
Set-Theme $script:theme
Ensure-DailyVerse
# ------------------------------------------------------------------ Main window
# Load the main window and look up every named control once. A missing name stops startup
# with a clear message, which catches XAML and code getting out of step.
$script:window = Load-Xaml (Join-Path $PSScriptRoot 'MainWindow.xaml')
foreach ($name in @('WeekNav','WeekPage','WeekContent','HomeNav','BibleNav','LibraryNav','JournalNav','TorahNav','SettingsNav','HomePage','BiblePage','LibraryPage','JournalPage','TorahPage','SettingsPage','DateLabel','HebrewDateLabel','StatusLabel','GreetingLabel',
    'DailyText','DailyReference','DailyVersionLabel','NewDailyButton','DailyNivButton','PracticeButton','AddVerseButton','AddDailyButton','FocusTitle','FocusReference','FocusHint',
    'FocusProgress','MasteredCount','ViewLibraryButton','WriteReflectionButton','LibraryAddButton','VerseList',
    'SelectedState','SelectedReference','SelectedText','SelectedProgress','FocusSelectedButton','PracticeSelectedButton','EditSelectedButton',
    'NavColumn','BrandText','PracticeCard','NavList','SearchBorder','ExploreGrid','BibleSideColumn','MainArea',
    'JournalDate','JournalEditor','SaveReflectionButton','JournalSavedLabel','ReflectionList',
    'TodayReadingsPanel','BibleTodayPanel','BibleBookPanel','BibleBookScroll','HighlightSwatchPanel','HighlightsNav','HighlightsPage','HighlightFilterPanel','HighlightListPanel','PreviousChapterButton','BibleVersionLabel','BibleNivButton',
    'NextChapterButton','ChapterNumberInput','BibleChapterTitle',
    'BibleVerseScroll','BibleVersesPanel','BibleNoteReference','BibleNoteEditor','SaveBibleNoteButton',
    'MemorizeBibleVerseButton','BibleNoteSavedLabel','StartupToggleButton','DailyOfferToggleButton',
    'ThemeLightButton','ThemeDarkButton','TranslationBsbButton','TranslationKjvButton','DesktopShortcutButton','ShortcutStatusLabel',
    'ThemeQuickButton','ThemeQuickIcon','PassageSearchBox','PassageSearchHint','PassageSearchButton',
    'TorahHomeName','TorahHomeReading','TorahHomeDate','TorahHomeOpenButton','TorahCurrentName','TorahCurrentDate',
    'TorahCurrentKindLabel','TorahCurrentTorah','TorahCurrentHaftarah','TorahCurrentGospel','ReadTorahButton','ReadHaftarahButton',
    'ReadGospelButton','TorahUpcomingPanel')) {
    $script:ui[$name] = $script:window.FindName($name)
    if ($null -eq $script:ui[$name]) { throw "MainWindow.xaml is missing the element '$name'." }
}

# Bible book list (all 66 books; click a book to show its chapters)
Initialize-BookList

# ------------------------------------------------------------------ Tray icon
# Closing the window hides it; Selah keeps running in the tray so reminders still work.
$script:tray = [System.Windows.Forms.NotifyIcon]::new()
$script:tray.Icon = if ([System.IO.File]::Exists($script:iconPath)) { try { [System.Drawing.Icon]::new($script:iconPath) } catch { [System.Drawing.SystemIcons]::Information } } else { [System.Drawing.SystemIcons]::Information }
$script:tray.Text = 'Selah — Scripture, remembered'
$script:tray.Visible = $true
$menu = [System.Windows.Forms.ContextMenuStrip]::new()
$openItem = $menu.Items.Add('Open Selah')
$quitItem = $menu.Items.Add('Quit Selah')
$script:tray.ContextMenuStrip = $menu
$openAction = {
    $script:window.Show()
    $script:window.WindowState = 'Normal'
    $script:window.Activate() | Out-Null
}
$openItem.Add_Click($openAction)
$script:tray.Add_DoubleClick($openAction)
$quitItem.Add_Click({
    $script:quitting = $true
    $script:tray.Visible = $false
    $script:tray.Dispose()
    $script:window.Close()
    $script:app.Shutdown()
})
$script:window.Add_Closing({
    if (-not $script:quitting) {
        $_.Cancel = $true
        $script:window.Hide()
        $script:tray.BalloonTipTitle = 'Selah is still here'
        $script:tray.BalloonTipText = 'Your practice reminders will appear from the system tray.'
        $script:tray.ShowBalloonTip(3000)
    }
})

# Adapts the main window to its width: a narrow window gets icon-only navigation,
# a smaller search box and fewer tile columns.
function Update-Layout {
    # Narrow windows (split view): icon-only navigation, smaller search box, two-column tiles.
    $width = $script:window.ActualWidth
    if ($width -le 0) { $width = $script:window.Width }
    $compact = $width -lt 1060
    $script:ui.NavColumn.Width = [System.Windows.GridLength]::new($(if ($compact) { 84 } else { 252 }))
    $script:ui.BrandText.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
    $script:ui.PracticeCard.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
    foreach ($button in $script:ui.NavList.Children) {
        $label = $button.Content.Children[1]
        $label.Visibility = if ($compact) { 'Collapsed' } else { 'Visible' }
        $button.ToolTip = if ($compact) { $label.Text } else { $null }
    }
    $script:ui.MainArea.Margin = if ($compact) { [System.Windows.Thickness]::new(16,16,16,12) } else { [System.Windows.Thickness]::new(26,20,26,16) }
    $script:ui.SearchBorder.Width = if ($width -lt 820) { 190 } else { 300 }
    $script:ui.ExploreGrid.Columns = if ($width -lt 760) { 1 } else { 2 }
    $script:ui.BibleSideColumn.Width = [System.Windows.GridLength]::new($(if ($width -lt 900) { 190 } else { 250 }))
}

# The search box at the top: opens any typed reference (e.g. 'John 3:16; Psalm 23'),
# or a whole book when only a book name is typed.
function Open-PassageSearch {
    $query = $script:ui.PassageSearchBox.Text.Trim()
    if (-not $query) { return }
    $found = Find-ScriptureReferences $query
    if (@($found.links).Count) {
        $reference = (@($found.links) | ForEach-Object { $_.reference }) -join '; '
        Show-Scripture $reference
    } else {
        $bookOnly = Resolve-BookName $query
        if ($bookOnly) { Show-Page 'Bible'; Set-BibleChapter $bookOnly 1 }
        else { [System.Windows.MessageBox]::Show("Type a reference such as John 3:16, Romans 8 or Psalm 23:1-4.", 'Selah', 'OK', 'Information') | Out-Null }
    }
}

# ------------------------------------------------------------------ Buttons and events
# Sidebar navigation, then each page's buttons. Handlers call the functions defined above.
$script:ui.HomeNav.Add_Click({ Show-Page 'Home' })
$script:ui.WeekNav.Add_Click({ Show-Page 'Week' })
$script:ui.BibleNav.Add_Click({ Show-Page 'Bible' })
$script:ui.LibraryNav.Add_Click({ Show-Page 'Library' })
$script:ui.JournalNav.Add_Click({ Show-Page 'Journal' })
$script:ui.TorahNav.Add_Click({ Show-Page 'Torah' })
$script:ui.TorahHomeOpenButton.Add_Click({ Show-Page 'Torah' })
$script:ui.ReadTorahButton.Add_Click({ if ($script:torahCurrent) { Show-Scripture ([string]$script:torahCurrent.torah) } })
$script:ui.ReadHaftarahButton.Add_Click({ if ($script:torahCurrent) { Show-Scripture ([string]$script:torahCurrent.haftarah) } })
$script:ui.ReadGospelButton.Add_Click({ if ($script:torahCurrent) { Show-Scripture ([string]$script:torahCurrent.gospel) } })
$script:ui.SettingsNav.Add_Click({ Show-Page 'Settings' })
$script:ui.StartupToggleButton.Add_Click({
    try { Set-StartupEnabled (-not (Get-StartupEnabled)) }
    catch { [System.Windows.MessageBox]::Show("Could not update Windows startup: $($_.Exception.Message)", 'Selah', 'OK', 'Warning') | Out-Null }
    Update-SettingsView
})
$script:ui.DailyOfferToggleButton.Add_Click({
    $script:offerDailyWhenNoFocus = -not $script:offerDailyWhenNoFocus
    Save-State
    Update-View
})
$script:ui.ThemeLightButton.Add_Click({ Set-Theme 'Light'; Save-State })
$script:ui.ThemeDarkButton.Add_Click({ Set-Theme 'Dark'; Save-State })
$script:ui.ThemeQuickButton.Add_Click({ Set-Theme $(if ($script:theme -eq 'Dark') { 'Light' } else { 'Dark' }); Save-State })
$script:ui.TranslationBsbButton.Add_Click({ Set-Translation 'BSB' })
$script:ui.TranslationKjvButton.Add_Click({ Set-Translation 'KJV' })
$script:ui.DesktopShortcutButton.Add_Click({
    try { Save-SelahShortcut (Get-DesktopShortcutPath) 'Open Selah' }
    catch { [System.Windows.MessageBox]::Show("Could not create the desktop icon: $($_.Exception.Message)", 'Selah', 'OK', 'Warning') | Out-Null }
    Update-SettingsView
})
$script:ui.ViewLibraryButton.Add_Click({ Show-Page 'Library' })
$script:ui.WriteReflectionButton.Add_Click({ Show-Page 'Journal' })
$script:ui.AddVerseButton.Add_Click({ Show-AddVerse })
$script:ui.LibraryAddButton.Add_Click({ Show-AddVerse })
$script:ui.AddDailyButton.Add_Click({
    $d = (Get-DailyVerse)
    Add-Verse $d.reference $d.text | Out-Null
    Show-Page 'Library'
})
$script:ui.NewDailyButton.Add_Click({ New-DailyVerse })
$script:ui.DailyNivButton.Add_Click({ Open-Niv ([string](Get-DailyVerse).reference) })
$script:ui.BibleNivButton.Add_Click({ Open-Niv ("$(Get-DisplayBookName $script:bibleBook) $script:bibleChapter") })
$script:ui.PassageSearchBox.Add_TextChanged({
    $script:ui.PassageSearchHint.Visibility = if ($script:ui.PassageSearchBox.Text) { 'Collapsed' } else { 'Visible' }
})
$script:ui.PassageSearchBox.Add_KeyDown({
    if ($_.Key -eq 'Return') { Open-PassageSearch; $_.Handled = $true }
})
$script:ui.PassageSearchButton.Add_Click({ Open-PassageSearch })
$script:ui.PracticeButton.Add_Click({
    $focus = Get-Focus
    if ($null -ne $focus) { Show-Practice $focus } elseif ($script:offerDailyWhenNoFocus) { Show-DailyInvitation }
})
$script:ui.VerseList.Add_SelectionChanged({ Update-SelectedVerse })
$script:ui.FocusSelectedButton.Add_Click({
    $item = $script:ui.VerseList.SelectedItem
    if ($item) { Set-Focus ([string]$item.Tag) }
})
$script:ui.EditSelectedButton.Add_Click({
    $item = $script:ui.VerseList.SelectedItem
    if ($item) { Show-AddVerse (Get-Verse ([string]$item.Tag)) }
})
$script:ui.PracticeSelectedButton.Add_Click({
    $item = $script:ui.VerseList.SelectedItem
    if ($item) { Show-Practice (Get-Verse ([string]$item.Tag)) }
})
$script:ui.SaveReflectionButton.Add_Click({ Save-Reflection })
$script:ui.JournalEditor.Add_TextChanged({
    if (-not $script:openingJournalDate) { Save-Reflection }
})
$script:ui.ReflectionList.Add_SelectionChanged({
    if ($script:updatingReflectionList) { return }
    $item = $script:ui.ReflectionList.SelectedItem
    if ($item -and [string]$item.Tag -ne $script:journalDate) { Open-JournalDate ([string]$item.Tag) }
})
$script:ui.HighlightsNav.Add_Click({ Show-Page 'Highlights' })
$script:ui.PreviousChapterButton.Add_Click({ Set-BibleChapter $script:bibleBook ($script:bibleChapter - 1) })
$script:ui.NextChapterButton.Add_Click({ Set-BibleChapter $script:bibleBook ($script:bibleChapter + 1) })
$script:ui.ChapterNumberInput.Add_KeyDown({
    if ($_.Key -eq 'Return') {
        Apply-ChapterInput
        $_.Handled = $true
    }
})
$script:ui.ChapterNumberInput.Add_LostFocus({ Apply-ChapterInput })
$script:ui.SaveBibleNoteButton.Add_Click({ Save-BibleNote })
$script:ui.MemorizeBibleVerseButton.Add_Click({ Memorize-BibleVerse })

# ------------------------------------------------------------------ Timer
# Every 30 seconds: roll over to a new day after midnight, then check practice reminders.
$script:timer = [System.Windows.Threading.DispatcherTimer]::new()
$script:timer.Interval = [timespan]::FromSeconds(30)
$script:timer.Add_Tick({
    if ($script:daily.date -ne (Get-Date).ToString('yyyy-MM-dd')) {
        Ensure-DailyVerse
        Update-View
        Open-JournalDate (Get-Date).ToString('yyyy-MM-dd')
    }
    Check-Reminder
})
$script:timer.Start()
# First paint: Home page, today's Proverbs chapter on the Bible page, and the layout for this width.
Update-View
Set-BibleChapter 'Proverbs' (Get-Date).Day
Show-Page 'Home'
$script:window.Add_ContentRendered({ Check-Reminder })
$script:window.Add_SizeChanged({ Update-Layout })
Update-Layout
if (-not $TestMode) { Update-Shortcuts }

if ($TestMode) {
    # Used by the local smoke test to verify XAML and initialization without opening the UI.
    if ($SnapshotPath) {
        if ($SnapshotTheme) { Set-Theme $SnapshotTheme }
        Show-Page $SnapshotPage
        $script:window.Show()
        $script:window.Measure([System.Windows.Size]::new(1180,800))
        $script:window.Arrange([System.Windows.Rect]::new(0,0,1180,800))
        $script:window.UpdateLayout()
        $script:window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
        $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(1180,800,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
        $backdrop = [System.Windows.Media.DrawingVisual]::new()
        $context = $backdrop.RenderOpen()
        $context.DrawRectangle($script:app.Resources['WindowBg'], $null, [System.Windows.Rect]::new(0,0,1180,800))
        $context.Close()
        $bitmap.Render($backdrop)
        $bitmap.Render($script:window.Content)
        $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
        $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream = [System.IO.File]::Create($SnapshotPath)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
    }
    Write-Output "Loaded Selah; daily verse: $($script:ui.DailyReference.Text); daily count: $($script:dailyVerses.Count); data: $script:dataFile"
    $script:quitting = $true
    $script:window.Close()
    $script:tray.Visible = $false
    $script:tray.Dispose()
    return
}

# A problem inside a button or timer is logged and shown, but Selah keeps running instead of closing.
$script:app.Add_DispatcherUnhandledException({
    param($sender, $e)
    $err = $e.Exception
    $inner = if ($err.InnerException) { $err.InnerException } else { $err }
    $where = ''
    if ($inner -is [System.Management.Automation.RuntimeException] -and $inner.ErrorRecord) { $where = $inner.ErrorRecord.ScriptStackTrace }
    $report = "$(Get-Date -Format o)`r`n$($inner.Message)`r`n$where`r`n`r`n"
    try { [System.IO.File]::AppendAllText((Join-Path $PSScriptRoot 'selah-errors.log'), $report) } catch { }
    $e.Handled = $true
    $script:practiceOpen = $false
    try { [System.Windows.MessageBox]::Show("Something went wrong, but Selah is still running.`n`n$($inner.Message)`n`n$where`n`nDetails are saved in selah-errors.log.", 'Selah', 'OK', 'Warning') | Out-Null } catch { }
})

try { $script:app.Run($script:window) | Out-Null }
finally {
    $script:timer.Stop()
    if ($script:tray -and -not $script:tray.IsDisposed) { $script:tray.Visible = $false; $script:tray.Dispose() }
    if ($script:instanceMutex) { $script:instanceMutex.ReleaseMutex(); $script:instanceMutex.Dispose() }
}
