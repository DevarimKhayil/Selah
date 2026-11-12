# =====================================================================================
# StudyFeatures.ps1 - Scripture and study helpers for the desktop app.
#   * Hebrew date and the weekly Torah card (Torah page and Home tile).
#   * Bible text: book data loading, reference parsing, passage text, the Scripture window
#     and NIV links on BibleGateway.
#   * Reference detection: finding Bible references inside any text.
# Dot-sourced by Selah.ps1, so it shares $script: variables with it.
# =====================================================================================
# Shortcut for element.SetResourceReference(property, key): the property follows a theme colour.
function Set-Res($element, $property, [string]$key) {
    # Bind a colour to the current theme so it follows Light/Dark switches.
    $element.SetResourceReference($property, $key)
}

# Hebrew date in English letters, e.g. '5 Cheshvan 5787', using .NET's HebrewCalendar.
# Leap years get Adar I and Adar II. It follows the computer's calendar day (no sunset switch).
function Get-HebrewDate([datetime]$date) {
    $calendar = [System.Globalization.HebrewCalendar]::new()
    $year = $calendar.GetYear($date)
    $month = $calendar.GetMonth($date)
    $day = $calendar.GetDayOfMonth($date)
    $months = if ($calendar.IsLeapYear($year)) {
        @('Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar I', 'Adar II', 'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul')
    } else {
        @('Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar', 'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul')
    }
    return '{0} {1} {2}' -f $day, $months[$month - 1], $year
}

# The next weekly portion on the user's 5787 card dated on or after $date.
function Get-TorahPortion([datetime]$date) {
    foreach ($portion in $script:torahPortions) {
        if ([datetime]$portion.date -ge $date.Date) { return $portion }
    }
    return $null
}

# The next reading of any kind (weekly portion or festival reading) dated on or after $date.
# Returns $null once the card is finished, rather than inventing a reading.
function Get-TorahReading([datetime]$date) {
    $all = @($script:torahPortions) + @($script:torahSpecialReadings)
    return @($all | Where-Object { [datetime]$_.date -ge $date.Date } |
        Sort-Object { [datetime]$_.date } | Select-Object -First 1)[0]
}

# Fills the Torah page and the Home tile: current reading, its Torah/Haftarah/Gospel
# references (each opens the passage) and the list of upcoming portions.
function Update-TorahView {
    $today = (Get-Date).Date
    $portion = Get-TorahReading $today
    $script:torahCurrent = $portion
    if ($null -eq $portion -and -not @($script:torahPortions).Count) {
        $script:ui.TorahHomeName.Text = 'Torah card not added'
        $script:ui.TorahHomeReading.Text = 'Put torah-portions.json in the StudyData folder.'
        $script:ui.TorahHomeDate.Text = ''
        $script:ui.TorahCurrentName.Text = 'Torah card not added'
        $script:ui.TorahCurrentDate.Text = 'Build StudyData\torah-portions.json with BuildStudyData.py from your Torah portions card.'
        $script:ui.TorahCurrentTorah.Text = ''; $script:ui.TorahCurrentHaftarah.Text = ''; $script:ui.TorahCurrentGospel.Text = ''
        foreach ($button in @('ReadTorahButton','ReadHaftarahButton','ReadGospelButton')) { $script:ui[$button].IsEnabled = $false }
        $script:ui.TorahUpcomingPanel.Children.Clear()
        return
    }
    if ($null -eq $portion) {
        $script:ui.TorahHomeName.Text = '5787 schedule complete'
        $script:ui.TorahHomeReading.Text = 'Add the next Torah card when it is available.'
        $script:ui.TorahHomeDate.Text = ''
        $script:ui.TorahCurrentName.Text = 'Schedule complete'
        $script:ui.TorahCurrentDate.Text = 'The supplied card ends 24 October 2027.'
        $script:ui.TorahCurrentTorah.Text = ''
        $script:ui.TorahCurrentHaftarah.Text = ''
        $script:ui.TorahCurrentGospel.Text = ''
        $script:ui.TorahCurrentKindLabel.Text = 'UPCOMING TORAH READING'
    } else {
        $readDate = [datetime]$portion.date
        $dateText = $readDate.ToString('dddd, d MMMM yyyy')
        $script:ui.TorahCurrentKindLabel.Text = if ($null -ne $portion.number) { 'UPCOMING SHABBAT PORTION' } else { 'UPCOMING SPECIAL READING' }
        $script:ui.TorahHomeName.Text = [string]$portion.name
        $script:ui.TorahHomeReading.Text = [string]$portion.torah
        $script:ui.TorahHomeDate.Text = $dateText
        $script:ui.TorahCurrentName.Text = [string]$portion.name
        $script:ui.TorahCurrentDate.Text = $dateText
        $script:ui.TorahCurrentTorah.Text = [string]$portion.torah
        $script:ui.TorahCurrentHaftarah.Text = [string]$portion.haftarah
        $script:ui.TorahCurrentGospel.Text = [string]$portion.gospel
    }
    foreach ($button in @('ReadTorahButton','ReadHaftarahButton','ReadGospelButton')) {
        $script:ui[$button].IsEnabled = $null -ne $portion
    }
    $script:ui.TorahUpcomingPanel.Children.Clear()
    $all = @($script:torahPortions) + @($script:torahSpecialReadings)
    $coming = @($all | Where-Object { [datetime]$_.date -gt $today -and $_ -ne $portion } | Sort-Object { [datetime]$_.date } | Select-Object -First 7)
    foreach ($reading in $coming) {
        $row = [System.Windows.Controls.Border]::new()
        Set-Res $row ([System.Windows.Controls.Border]::BackgroundProperty) 'CardAlt'
        $row.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $row.Padding = [System.Windows.Thickness]::new(14,10,10,10)
        $row.Margin = [System.Windows.Thickness]::new(0,0,0,6)
        $panel = [System.Windows.Controls.DockPanel]::new()
        $stack = [System.Windows.Controls.StackPanel]::new()
        $name = [System.Windows.Controls.TextBlock]::new()
        $kind = if ($null -ne $reading.number) { 'Portion' } else { 'Special reading' }
        $name.Text = "$($reading.name)"
        $name.FontWeight = [System.Windows.FontWeights]::SemiBold
        $name.FontSize = 14
        Set-Res $name ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Text'
        $detail = [System.Windows.Controls.TextBlock]::new()
        $detail.Text = "$kind  ·  $(([datetime]$reading.date).ToString('d MMMM yyyy'))  ·  $($reading.torah)"
        $detail.FontSize = 12
        $detail.TextWrapping = 'Wrap'
        Set-Res $detail ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'TextSecondary'
        $detail.Margin = [System.Windows.Thickness]::new(0,3,0,0)
        $stack.Children.Add($name) | Out-Null
        $stack.Children.Add($detail) | Out-Null
        $open = [System.Windows.Controls.Button]::new()
        $open.Content = 'Read'
        $open.Style = $script:app.FindResource('RefChip')
        $open.Tag = [string]$reading.torah
        $open.VerticalAlignment = 'Center'
        $open.Add_Click({ Show-Scripture ([string]$this.Tag) })
        [System.Windows.Controls.DockPanel]::SetDock($open, [System.Windows.Controls.Dock]::Right)
        $panel.Children.Add($open) | Out-Null
        $panel.Children.Add($stack) | Out-Null
        $row.Child = $panel
        $script:ui.TorahUpcomingPanel.Children.Add($row) | Out-Null
    }
}

# ---------------------------------------------------------------- Bible text

# Full name of a translation code: 'BSB' -> 'Berean Standard Bible'.
function Get-TranslationName([string]$code = $script:translation) {
    if ($code -eq 'KJV') { return 'King James Version' }
    return 'Berean Standard Bible'
}

# Turns a typed book name into the canonical one ('Psalm' -> 'Psalms', 'Song of Songs' ->
# 'Song of Solomon'); matching ignores case and extra spaces. Returns $null if unknown.
function Resolve-BookName([string]$name) {
    $name = ($name -replace '\s+', ' ').Trim()
    $aliases = @{ 'Psalm' = 'Psalms'; 'Song of Songs' = 'Song of Solomon'; 'Revelations' = 'Revelation' }
    if ($aliases.ContainsKey($name)) { $name = $aliases[$name] }
    $canonical = @($script:allBibleBookNames | Where-Object { $_ -ieq $name } | Select-Object -First 1)
    if (-not $canonical.Count) { return $null }
    return [string]$canonical[0]
}

# Loads (and caches) one book's JSON from BibleData (KJV) or BibleData\BSB.
function Get-BibleBookData([string]$name, [string]$translation = $script:translation) {
    $name = Resolve-BookName $name
    if (-not $name) { return $null }
    if ($translation -ne 'KJV') { $translation = 'BSB' }
    $cacheKey = "$translation|$name"
    if (-not $script:bibleCache.ContainsKey($cacheKey)) {
        $folder = Join-Path $PSScriptRoot 'BibleData'
        if ($translation -eq 'BSB') { $folder = Join-Path $folder 'BSB' }
        $path = Join-Path $folder (($name -replace '\s', '') + '.json')
        if (-not [System.IO.File]::Exists($path)) { return $null }
        $script:bibleCache[$cacheKey] = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    return $script:bibleCache[$cacheKey]
}

# Book name for display: 'Psalms' is shown as 'Psalm' (as in 'Psalm 23').
function Get-DisplayBookName([string]$book) {
    if ($book -eq 'Psalms') { return 'Psalm' }
    return $book
}

# Parses a reference such as 'Joshua 3:5-7, 5:2-6:1' into passages and fetches their verses.
function Get-ScripturePassages([string]$reference, [string]$translation = $script:translation) {
    # Returns one object per reference segment: title, verses (chapter/verse/text) and an optional error.
    $clean = $reference -replace '\s*[–—-]\s*', '-'
    $segments = [regex]::Split($clean, '[;,]\s*')
    $bookContext = ''
    $chapterContext = 0
    foreach ($segment in $segments) {
        $segment = $segment.Trim().TrimEnd('.', ')').TrimStart('(')
        $segment = $segment -replace '(\d)[a-c]\b', '$1'
        if (-not $segment) { continue }
        if ($segment -match '^\d+(?:-\d+)?$' -and $bookContext -and $chapterContext -gt 0) {
            $segment = "$bookContext ${chapterContext}:$segment"
        } elseif ($segment -match '^\d+(?::\d+)?(?:-.*)?$' -and $bookContext) {
            $segment = "$bookContext $segment"
        }
        if ($segment -notmatch '^(.+?)\s+(\d+)(?::(\d+))?(?:-(?:(\d+):)?(\d+))?$') {
            [pscustomobject]@{ title = $segment; verses = @(); error = "Could not read reference: $segment" }
            continue
        }
        $bookContext = $matches[1].Trim()
        $startChapter = [int]$matches[2]
        $startVerse = if ($matches[3]) { [int]$matches[3] } else { 1 }
        $endChapter = $startChapter
        $endVerse = [int]::MaxValue
        if ($matches[4]) {
            $endChapter = [int]$matches[4]
            $endVerse = [int]$matches[5]
        } elseif ($matches[5]) {
            if ($matches[3]) { $endVerse = [int]$matches[5] }
            else { $endChapter = [int]$matches[5] }
        } elseif ($matches[3]) {
            $endVerse = $startVerse
        }
        $chapterContext = if ($matches[3]) { $endChapter } else { 0 }
        $book = Get-BibleBookData $bookContext $translation
        if ($null -eq $book -or $endChapter -lt $startChapter -or ($endChapter - $startChapter) -gt 15) {
            [pscustomobject]@{ title = $segment; verses = @(); error = "Could not load passage: $segment" }
            continue
        }
        $verses = [System.Collections.Generic.List[object]]::new()
        for ($chapterNumber = $startChapter; $chapterNumber -le $endChapter; $chapterNumber++) {
            $chapter = @($book.chapters | Where-Object { [int]$_.chapter -eq $chapterNumber } | Select-Object -First 1)
            if (-not $chapter.Count) { continue }
            foreach ($verse in $chapter[0].verses) {
                $verseNumber = [int]$verse.verse
                if ($chapterNumber -eq $startChapter -and $verseNumber -lt $startVerse) { continue }
                if ($chapterNumber -eq $endChapter -and $verseNumber -gt $endVerse) { continue }
                $verses.Add([pscustomobject]@{ chapter = $chapterNumber; verse = $verseNumber; text = [string]$verse.text })
            }
        }
        $title = $segment -replace '^Psalms\b', 'Psalm'
        [pscustomobject]@{ title = $title; verses = @($verses.ToArray()); error = $(if ($verses.Count) { '' } else { 'No verses found for this reference.' }) }
    }
}

# Plain-text version of a reference: a title line, then 'chapter:verse  text' lines.
function Get-ScriptureText([string]$reference, [string]$translation = $script:translation) {
    $output = [System.Collections.Generic.List[string]]::new()
    foreach ($passage in @(Get-ScripturePassages $reference $translation)) {
        if ($null -eq $passage) { continue }
        $output.Add([string]$passage.title)
        $lastChapter = 0
        foreach ($v in $passage.verses) {
            if ($lastChapter -and $v.chapter -ne $lastChapter) { $output.Add('') }
            $output.Add(('{0}:{1}  {2}' -f $v.chapter, $v.verse, $v.text))
            $lastChapter = $v.chapter
        }
        if ($passage.error) { $output.Add([string]$passage.error) }
        $output.Add('')
    }
    return ($output -join "`r`n").Trim()
}

# Text of a reference with no verse numbers (used for the daily verse and Fill in).
function Get-VerseText([string]$reference, [string]$translation = $script:translation) {
    $passages = @(Get-ScripturePassages $reference $translation)
    $words = foreach ($p in $passages) { foreach ($v in $p.verses) { $v.text } }
    return (@($words) -join ' ').Trim()
}

# BibleGateway link for a reference in the NIV (NIV text itself is copyrighted, so not bundled).
function Get-NivUrl([string]$reference) {
    return 'https://www.biblegateway.com/passage/?search=' + [uri]::EscapeDataString($reference.Trim()) + '&version=NIV'
}

# Opens the NIV link in the user's browser.
function Open-Niv([string]$reference) {
    if (-not $reference) { return }
    try { Start-Process (Get-NivUrl $reference) }
    catch { [System.Windows.MessageBox]::Show("Could not open your browser.`n`n$($_.Exception.Message)", 'Selah', 'OK', 'Warning') | Out-Null }
}

# Builds the formatted passage (headings, verse numbers, reading font) shown in the Scripture window.
function New-ScriptureDocument([string]$reference, [string]$translation) {
    $doc = [System.Windows.Documents.FlowDocument]::new()
    $doc.FontFamily = $script:app.FindResource('ReadingFont')
    $doc.FontSize = 18
    $doc.LineHeight = 31
    $doc.PagePadding = [System.Windows.Thickness]::new(16,10,16,10)
    $doc.Background = [System.Windows.Media.Brushes]::Transparent
    Set-Res $doc ([System.Windows.Documents.FlowDocument]::ForegroundProperty) 'Text'
    $first = $true
    foreach ($passage in @(Get-ScripturePassages $reference $translation)) {
        if ($null -eq $passage) { continue }
        $heading = [System.Windows.Documents.Paragraph]::new()
        $heading.Margin = [System.Windows.Thickness]::new(0, $(if ($first) { 0 } else { 18 }), 0, 6)
        $headRun = [System.Windows.Documents.Run]::new([string]$passage.title)
        $headRun.FontWeight = [System.Windows.FontWeights]::SemiBold
        $headRun.FontSize = 14
        Set-Res $headRun ([System.Windows.Documents.TextElement]::ForegroundProperty) 'Accent'
        $heading.Inlines.Add($headRun)
        $doc.Blocks.Add($heading)
        $first = $false
        if ($passage.error) {
            $err = [System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new([string]$passage.error))
            Set-Res $err ([System.Windows.Documents.TextElement]::ForegroundProperty) 'TextSecondary'
            $doc.Blocks.Add($err)
            continue
        }
        $body = $null
        $lastChapter = 0
        foreach ($v in $passage.verses) {
            if ($null -eq $body -or $v.chapter -ne $lastChapter) {
                if ($null -ne $body -and $lastChapter) {
                    $chapterLabel = [System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new("Chapter $($v.chapter)"))
                    $chapterLabel.FontSize = 13
                    $chapterLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
                    $chapterLabel.Margin = [System.Windows.Thickness]::new(0,14,0,4)
                    Set-Res $chapterLabel ([System.Windows.Documents.TextElement]::ForegroundProperty) 'TextSecondary'
                    $doc.Blocks.Add($chapterLabel)
                }
                $body = [System.Windows.Documents.Paragraph]::new()
                $body.Margin = [System.Windows.Thickness]::new(0)
                $doc.Blocks.Add($body)
                $lastChapter = $v.chapter
            }
            $num = [System.Windows.Documents.Run]::new("$($v.verse) ")
            $num.FontSize = 11
            $num.FontWeight = [System.Windows.FontWeights]::Bold
            $num.BaselineAlignment = [System.Windows.BaselineAlignment]::Superscript
            Set-Res $num ([System.Windows.Documents.TextElement]::ForegroundProperty) 'Accent'
            $body.Inlines.Add($num)
            $body.Inlines.Add([System.Windows.Documents.Run]::new([string]$v.text + ' '))
        }
    }
    return $doc
}

# Opens the Scripture window for a reference, with BSB/KJV switch and a Read in NIV button.
function Show-Scripture([string]$reference) {
    if (-not $reference) { return }
    $dialog = Load-Xaml (Join-Path $PSScriptRoot 'ScriptureWindow.xaml')
    if ($script:window.IsVisible) { $dialog.Owner = $script:window }
    $dialog.FindName('ScriptureReference').Text = ($reference -replace '\bPsalms\b(?=\s+\d)', 'Psalm')
    $viewer = $dialog.FindName('ScriptureDoc')
    $label = $dialog.FindName('ScriptureVersionLabel')
    $bsb = $dialog.FindName('ScriptureBsbButton')
    $kjv = $dialog.FindName('ScriptureKjvButton')
    $render = {
        param([string]$code)
        $viewer.Document = New-ScriptureDocument $reference $code
        $label.Text = (Get-TranslationName $code).ToUpperInvariant()
        $bsb.Tag = if ($code -eq 'BSB') { 'Selected' } else { $null }
        $kjv.Tag = if ($code -eq 'KJV') { 'Selected' } else { $null }
    }
    & $render $script:translation
    $bsb.Add_Click({ & $render 'BSB' })
    $kjv.Add_Click({ & $render 'KJV' })
    $dialog.FindName('ScriptureNivButton').Add_Click({ Open-Niv $reference })
    $dialog.FindName('ScriptureCloseButton').Add_Click({ $dialog.Close() })
    $dialog.ShowDialog() | Out-Null
}

# ------------------------------------------------------- Reference detection

# Builds (once) the regular expressions that recognise Bible references in free text.
function Get-ReferenceRegexes {
    if ($script:referenceRegex) { return }
    $names = @($script:allBibleBookNames) + @('Psalm', 'Song of Songs') | Sort-Object { $_.Length } -Descending
    $bookPattern = (@($names | ForEach-Object { ([regex]::Escape([string]$_)) -replace '\\ ', '\s+' })) -join '|'
    $dash = '\s*[-–—]\s*'
    $range = "\d+(?::\d+[a-c]?)?(?:$dash\d+(?::\d+)?[a-c]?)?"
    $notBook = '(?!\s+(?:Samuel|Kings|Chronicles|Corinthians|Thessalonians|Timothy|Peter|John)\b)'
    $item = "(?:\d+:\d+[a-c]?|\d+)(?:$dash\d+(?::\d+)?[a-c]?)?$notBook"
    $script:referenceRegex = [regex]::new("(?<![\w])(?<book>$bookPattern)\s+(?<first>$range)(?<rest>(?:\s*[,;]\s*$item)*)")
    $script:referenceItemRegex = [regex]::new("(?<sep>\s*[,;]\s*)(?<item>(?:\d+:\d+[a-c]?|\d+)(?:$dash\d+(?::\d+)?[a-c]?)?)")
    $script:contextVerseRegex = [regex]::new("(?<![\w])(?:[Vv]erses?|vv?\.)\s+(?<a>\d+)[a-c]?(?:$dash(?<b>\d+)[a-c]?)?(?![\d:])")
}

# Finds every Bible reference in a piece of text, including follow-on ones such as
# 'John 1:12; 3:14' and 'verse 27' using the surrounding book and chapter as context.
function Find-ScriptureReferences([string]$text, [string]$contextBook = '', [int]$contextChapter = 0) {
    # Finds Bible references in free text. Returns links (index, length, reference) and the running
    # book/chapter context, so "verse 27" can follow the most recent explicit reference.
    Get-ReferenceRegexes
    $links = [System.Collections.Generic.List[object]]::new()
    $explicit = [System.Collections.Generic.List[object]]::new()
    if (-not $text) { return [pscustomobject]@{ links = @(); book = $contextBook; chapter = $contextChapter } }
    foreach ($m in $script:referenceRegex.Matches($text)) {
        $book = Resolve-BookName ($m.Groups['book'].Value)
        if (-not $book) { continue }
        $display = Get-DisplayBookName $book
        $first = $m.Groups['first'].Value -replace '\s*[–—-]\s*', '-'
        $firstEnd = $m.Groups['first'].Index + $m.Groups['first'].Length
        $explicit.Add([pscustomobject]@{ index = $m.Index; length = $firstEnd - $m.Index; reference = "$display $first"; book = $book; chapter = [int]($first -split '[:-]')[0] })
        $chapter = [int]($first -split '[:-]')[0]
        $verseMode = $first -match ':'
        if ($first -match '-(\d+):') { $chapter = [int]$matches[1] }
        foreach ($im in $script:referenceItemRegex.Matches($m.Groups['rest'].Value)) {
            $value = $im.Groups['item'].Value -replace '\s*[–—-]\s*', '-'
            if ($value -match '^(\d+):') {
                $chapter = [int]$matches[1]
                $verseMode = $true
                $ref = "$display $value"
                if ($value -match '-(\d+):') { $chapter = [int]$matches[1] }
            } elseif ($verseMode) {
                $ref = "$display ${chapter}:$value"
            } else {
                $chapter = [int]($value -split '-')[0]
                $ref = "$display $value"
            }
            $start = $m.Groups['rest'].Index + $im.Groups['item'].Index
            $explicit.Add([pscustomobject]@{ index = $start; length = $im.Groups['item'].Length; reference = $ref; book = $book; chapter = $chapter })
        }
    }
    $sorted = @($explicit | Sort-Object index)
    $contextual = foreach ($cm in $script:contextVerseRegex.Matches($text)) {
        $overlaps = @($sorted | Where-Object { $cm.Index -lt ($_.index + $_.length) -and $_.index -lt ($cm.Index + $cm.Length) }).Count
        if ($overlaps) { continue }
        $prior = @($sorted | Where-Object { $_.index -lt $cm.Index } | Select-Object -Last 1)
        $book = if ($prior.Count) { $prior[0].book } else { $contextBook }
        $chapter = if ($prior.Count) { $prior[0].chapter } else { $contextChapter }
        if (-not $book -or $chapter -le 0) { continue }
        $verses = if ($cm.Groups['b'].Success) { "$($cm.Groups['a'].Value)-$($cm.Groups['b'].Value)" } else { $cm.Groups['a'].Value }
        [pscustomobject]@{ index = $cm.Index; length = $cm.Length; reference = "$(Get-DisplayBookName $book) ${chapter}:$verses"; book = $book; chapter = $chapter }
    }
    $all = @(@($sorted) + @($contextual) | Where-Object { $null -ne $_ } | Sort-Object index)
    $endBook = $contextBook
    $endChapter = $contextChapter
    if ($sorted.Count) { $endBook = $sorted[-1].book; $endChapter = $sorted[-1].chapter }
    return [pscustomobject]@{ links = $all; book = $endBook; chapter = $endChapter }
}
