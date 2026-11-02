# Torah dates, Romans lesson workspace, Scripture references, and offline passage dialogs.

function Set-Res($element, $property, [string]$key) {
    # Bind a colour to the current theme so it follows Light/Dark switches.
    $element.SetResourceReference($property, $key)
}

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

function Get-TorahPortion([datetime]$date) {
    foreach ($portion in $script:torahPortions) {
        if ([datetime]$portion.date -ge $date.Date) { return $portion }
    }
    return $null
}

function Get-TorahReading([datetime]$date) {
    $all = @($script:torahPortions) + @($script:torahSpecialReadings)
    return @($all | Where-Object { [datetime]$_.date -ge $date.Date } |
        Sort-Object { [datetime]$_.date } | Select-Object -First 1)[0]
}

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

function Get-TranslationName([string]$code = $script:translation) {
    if ($code -eq 'KJV') { return 'King James Version' }
    return 'Berean Standard Bible'
}

function Resolve-BookName([string]$name) {
    $name = ($name -replace '\s+', ' ').Trim()
    $aliases = @{ 'Psalm' = 'Psalms'; 'Song of Songs' = 'Song of Solomon'; 'Revelations' = 'Revelation' }
    if ($aliases.ContainsKey($name)) { $name = $aliases[$name] }
    $canonical = @($script:allBibleBookNames | Where-Object { $_ -ieq $name } | Select-Object -First 1)
    if (-not $canonical.Count) { return $null }
    return [string]$canonical[0]
}

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

function Get-DisplayBookName([string]$book) {
    if ($book -eq 'Psalms') { return 'Psalm' }
    return $book
}

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

function Get-VerseText([string]$reference, [string]$translation = $script:translation) {
    $passages = @(Get-ScripturePassages $reference $translation)
    $words = foreach ($p in $passages) { foreach ($v in $p.verses) { $v.text } }
    return (@($words) -join ' ').Trim()
}

function Get-NivUrl([string]$reference) {
    return 'https://www.biblegateway.com/passage/?search=' + [uri]::EscapeDataString($reference.Trim()) + '&version=NIV'
}

function Open-Niv([string]$reference) {
    if (-not $reference) { return }
    try { Start-Process (Get-NivUrl $reference) }
    catch { [System.Windows.MessageBox]::Show("Could not open your browser.`n`n$($_.Exception.Message)", 'Selah', 'OK', 'Warning') | Out-Null }
}

function New-ScriptureDocument([string]$reference, [string]$translation) {
    $doc = [System.Windows.Documents.FlowDocument]::new()
    $doc.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Text, Segoe UI')
    $doc.FontSize = 17
    $doc.LineHeight = 29
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

function Get-ReferenceContext([string]$reference) {
    $found = Find-ScriptureReferences $reference
    if (@($found.links).Count) { return [pscustomobject]@{ book = $found.links[0].book; chapter = [int]$found.links[0].chapter } }
    return [pscustomobject]@{ book = ''; chapter = 0 }
}

function Add-LinkedInlines($inlines, [string]$text, [string]$contextBook = '', [int]$contextChapter = 0) {
    # Adds plain runs and clickable Scripture hyperlinks to a TextBlock or Paragraph.
    $found = Find-ScriptureReferences $text $contextBook $contextChapter
    $position = 0
    foreach ($link in $found.links) {
        if ($link.index -lt $position) { continue }
        if ($link.index -gt $position) { $inlines.Add([System.Windows.Documents.Run]::new($text.Substring($position, $link.index - $position))) }
        $hyperlink = [System.Windows.Documents.Hyperlink]::new([System.Windows.Documents.Run]::new($text.Substring($link.index, $link.length)))
        $hyperlink.Tag = [string]$link.reference
        $hyperlink.ToolTip = "Read $($link.reference)"
        $hyperlink.FontWeight = [System.Windows.FontWeights]::SemiBold
        $hyperlink.Add_Click({ Show-Scripture ([string]$this.Tag) })
        $inlines.Add($hyperlink)
        $position = $link.index + $link.length
    }
    if ($position -lt $text.Length) { $inlines.Add([System.Windows.Documents.Run]::new($text.Substring($position))) }
    return $found
}

function New-LinkedTextBlock([string]$text, [string]$contextBook = '', [int]$contextChapter = 0) {
    $block = [System.Windows.Controls.TextBlock]::new()
    $block.TextWrapping = 'Wrap'
    Add-LinkedInlines $block.Inlines $text $contextBook $contextChapter | Out-Null
    return $block
}

# ------------------------------------------------------------- Romans study

# Lessons change each Wednesday. Lesson 5 began Wednesday 14 October 2026.
$script:bsfAnchor = [datetime]'2026-10-14'

function Get-BsfLessonForDate([datetime]$date) {
    $number = 5 + [int][math]::Floor(($date.Date - $script:bsfAnchor).TotalDays / 7)
    return [math]::Max(1, [math]::Min(30, $number))
}

function Get-BsfWeekStart([int]$number) {
    return $script:bsfAnchor.AddDays(($number - 5) * 7)
}

function Get-BsfQuestionParts([string]$questionText) {
    $markers = [regex]::Matches($questionText, '(?m)^[ \t]*([a-z])\.[ \t]+')
    if ($markers.Count -lt 2 -or $markers[0].Groups[1].Value -ne 'a') {
        [pscustomobject]@{ label = ''; text = $questionText; introduction = '' }
        return
    }
    $introduction = $questionText.Substring(0, $markers[0].Index).Trim()
    for ($i = 0; $i -lt $markers.Count; $i++) {
        $start = $markers[$i].Index + $markers[$i].Length
        $end = if ($i + 1 -lt $markers.Count) { $markers[$i + 1].Index } else { $questionText.Length }
        [pscustomobject]@{
            label = $markers[$i].Groups[1].Value
            text = $questionText.Substring($start, $end - $start).Trim()
            introduction = if ($i -eq 0) { $introduction } else { '' }
        }
    }
}

function Get-BsfAnswer([int]$lesson, [int]$number, [string]$part = '') {
    foreach ($answer in $script:bsfAnswers) {
        if ([int]$answer.lesson -eq $lesson -and [int]$answer.number -eq $number -and [string]$answer.part -eq $part) { return $answer }
    }
    return $null
}

function Set-BsfAnswer([int]$lesson, [int]$number, [string]$text, [string]$part = '') {
    $existing = Get-BsfAnswer $lesson $number $part
    if ($null -ne $existing -and [string]$existing.text -ceq $text) { return }
    if ($null -eq $existing) {
        $existing = [pscustomobject]@{ lesson = $lesson; number = $number; part = $part; text = $text; updatedAt = (Get-Date).ToString('o') }
        $script:bsfAnswers.Add($existing)
    } else {
        $existing.text = $text
        $existing.updatedAt = (Get-Date).ToString('o')
    }
    Save-State
    $script:ui.BsfSavedLabel.Text = 'Saved ✓'
}

function Set-BsfTab([string]$tab) {
    $script:bsfTab = $tab
    $script:ui.BsfQuestionsView.Visibility = if ($tab -eq 'Questions') { 'Visible' } else { 'Collapsed' }
    $script:ui.BsfNotesView.Visibility = if ($tab -eq 'Notes') { 'Visible' } else { 'Collapsed' }
    $script:ui.BsfQuestionsTab.Tag = if ($tab -eq 'Questions') { 'Selected' } else { $null }
    $script:ui.BsfNotesTab.Tag = if ($tab -eq 'Notes') { 'Selected' } else { $null }
}

function New-RefChip([string]$reference) {
    $button = [System.Windows.Controls.Button]::new()
    $button.Style = $script:app.FindResource('RefChip')
    $panel = [System.Windows.Controls.StackPanel]::new()
    $panel.Orientation = 'Horizontal'
    $icon = [System.Windows.Controls.TextBlock]::new()
    $icon.Text = [string][char]0xE736
    $icon.Style = $script:app.FindResource('Icon')
    $icon.FontSize = 11
    $label = [System.Windows.Controls.TextBlock]::new()
    $label.Text = $reference
    $label.Margin = [System.Windows.Thickness]::new(6,0,0,0)
    $panel.Children.Add($icon) | Out-Null
    $panel.Children.Add($label) | Out-Null
    $button.Content = $panel
    $button.Tag = $reference
    $button.ToolTip = "Read $reference"
    $button.Margin = [System.Windows.Thickness]::new(0,0,6,6)
    $button.Add_Click({ Show-Scripture ([string]$this.Tag) })
    return $button
}

function Update-BsfHomeTile {
    if (-not $script:ui.ContainsKey('BsfHomeLesson') -or $null -eq $script:ui.BsfHomeLesson) { return }
    if (-not $script:bsfLessons.Count) {
        $script:ui.BsfHomeLesson.Text = 'Lessons not added yet'
        $script:ui.BsfHomeMeta.Text = 'Put romans-lessons.json in the StudyData folder.'
        return
    }
    $number = Get-BsfLessonForDate (Get-Date)
    $lesson = $script:bsfLessons[$number - 1]
    $start = Get-BsfWeekStart $number
    $script:ui.BsfHomeLesson.Text = "Lesson $($lesson.number) · $($lesson.title)"
    $script:ui.BsfHomeMeta.Text = "$($lesson.scripture)  ·  Wed $($start.ToString('d MMM')) – Tue $($start.AddDays(6).ToString('d MMM'))"
}

function Update-BsfView {
    if (-not $script:bsfLessonNumber) { return }
    if (-not $script:bsfLessons.Count) {
        $script:ui.BsfLessonHeading.Text = 'Romans study'
        $script:ui.BsfLessonMeta.Text = 'The lesson file is not here. Build StudyData\romans-lessons.json with BuildStudyData.py from your own BSF lesson book.'
        $script:ui.BsfQuestionPanel.Children.Clear()
        foreach ($b in @('BsfPreviousButton','BsfNextButton','BsfCurrentButton','BsfExportButton','BsfNotesTab')) { $script:ui[$b].IsEnabled = $false }
        return
    }
    $lesson = $script:bsfLessons[$script:bsfLessonNumber - 1]
    $weekStart = Get-BsfWeekStart $script:bsfLessonNumber
    $weekEnd = $weekStart.AddDays(6)
    $script:ui.BsfLessonHeading.Text = "Lesson $($lesson.number)  ·  $($lesson.title)"
    $lessonContext = Get-ReferenceContext ([string]$lesson.scripture)
    $metaPanel = $script:ui.BsfLessonMetaPanel
    $metaPanel.Children.Clear()
    $metaPanel.Children.Add((New-RefChip ([string]$lesson.scripture))) | Out-Null
    $script:ui.BsfLessonMeta.Text = "Wednesday $($weekStart.ToString('d MMMM')) – Tuesday $($weekEnd.ToString('d MMMM yyyy'))"
    $script:ui.BsfLessonMeta.Margin = [System.Windows.Thickness]::new(4,0,0,6)
    $metaPanel.Children.Add($script:ui.BsfLessonMeta) | Out-Null
    $script:ui.BsfPreviousButton.IsEnabled = $script:bsfLessonNumber -gt 1
    $script:ui.BsfNextButton.IsEnabled = $script:bsfLessonNumber -lt 30
    $script:ui.BsfSavedLabel.Text = 'Answers save as you type'
    $panel = $script:ui.BsfQuestionPanel
    $panel.Children.Clear()
    $lastDay = ''
    foreach ($question in $lesson.questions) {
        $instructionContext = Get-ReferenceContext ([string]$question.instruction)
        if (-not $instructionContext.book -and @($question.references).Count) { $instructionContext = Get-ReferenceContext ([string]@($question.references)[0]) }
        if (-not $instructionContext.book) { $instructionContext = $lessonContext }
        if ($question.day -ne $lastDay) {
            $dayHeading = New-LinkedTextBlock "$($question.day)  ·  $($question.instruction)" $lessonContext.book $lessonContext.chapter
            Set-Res $dayHeading ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'TextSecondary'
            $dayHeading.FontSize = 13
            $dayHeading.FontWeight = [System.Windows.FontWeights]::SemiBold
            $dayHeading.Margin = [System.Windows.Thickness]::new(4,18,0,10)
            $panel.Children.Add($dayHeading) | Out-Null
            $lastDay = [string]$question.day
        }
        foreach ($part in @(Get-BsfQuestionParts ([string]$question.text))) {
            $card = [System.Windows.Controls.Border]::new()
            $card.Style = $script:app.FindResource('CardStyle')
            $card.Padding = [System.Windows.Thickness]::new(20,18,20,18)
            $card.Margin = [System.Windows.Thickness]::new(0,0,0,10)
            $stack = [System.Windows.Controls.StackPanel]::new()
            $chipRefs = [System.Collections.Generic.List[string]]::new()
            if ($part.introduction) {
                $intro = New-LinkedTextBlock ([string]$part.introduction) $instructionContext.book $instructionContext.chapter
                Set-Res $intro ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'TextSecondary'
                $intro.FontSize = 13
                $intro.Margin = [System.Windows.Thickness]::new(0,0,0,10)
                $stack.Children.Add($intro) | Out-Null
                foreach ($l in (Find-ScriptureReferences ([string]$part.introduction) $instructionContext.book $instructionContext.chapter).links) { if (-not $chipRefs.Contains($l.reference)) { $chipRefs.Add($l.reference) } }
            }
            $label = if ($part.label) { "$($question.number)$($part.label).  " } else { "$($question.number).  " }
            $prompt = [System.Windows.Controls.TextBlock]::new()
            $prompt.TextWrapping = 'Wrap'
            $prompt.FontSize = 15
            $prompt.LineHeight = 23
            Set-Res $prompt ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Text'
            $numberRun = [System.Windows.Documents.Run]::new($label)
            $numberRun.FontWeight = [System.Windows.FontWeights]::SemiBold
            Set-Res $numberRun ([System.Windows.Documents.TextElement]::ForegroundProperty) 'Accent'
            $prompt.Inlines.Add($numberRun)
            $found = Add-LinkedInlines $prompt.Inlines ([string]$part.text) $instructionContext.book $instructionContext.chapter
            $stack.Children.Add($prompt) | Out-Null
            foreach ($l in $found.links) { if (-not $chipRefs.Contains($l.reference)) { $chipRefs.Add($l.reference) } }
            if (-not $part.label -or $part.label -eq 'a') {
                foreach ($r in @($question.references)) { if ($r -and -not $chipRefs.Contains([string]$r)) { $chipRefs.Insert(0, [string]$r) } }
            }
            if ($chipRefs.Count) {
                $refs = [System.Windows.Controls.WrapPanel]::new()
                $refs.Margin = [System.Windows.Thickness]::new(0,10,0,2)
                foreach ($reference in $chipRefs) { $refs.Children.Add((New-RefChip $reference)) | Out-Null }
                $stack.Children.Add($refs) | Out-Null
            }
            $answerBorder = [System.Windows.Controls.Border]::new()
            $answerBorder.Style = $script:app.FindResource('FieldStyle')
            $answerBorder.Margin = [System.Windows.Thickness]::new(0,8,0,0)
            $answer = [System.Windows.Controls.TextBox]::new()
            $answer.Style = $script:app.FindResource('PlainTextBox')
            $answer.Tag = [pscustomobject]@{ lesson = [int]$lesson.number; number = [int]$question.number; part = [string]$part.label }
            $saved = Get-BsfAnswer ([int]$lesson.number) ([int]$question.number) ([string]$part.label)
            $answer.Text = if ($null -ne $saved) { [string]$saved.text } else { '' }
            $answer.AcceptsReturn = $true
            $answer.TextWrapping = 'Wrap'
            $answer.VerticalScrollBarVisibility = 'Auto'
            $answer.MinHeight = 76
            $answer.FontSize = 14
            $answer.SpellCheck.IsEnabled = $true
            $answer.Add_TextChanged({
                $metadata = $this.Tag
                Set-BsfAnswer ([int]$metadata.lesson) ([int]$metadata.number) ([string]$this.Text) ([string]$metadata.part)
            })
            $answerBorder.Child = $answer
            $stack.Children.Add($answerBorder) | Out-Null
            if ($part.label -eq 'a') {
                $previous = Get-BsfAnswer ([int]$lesson.number) ([int]$question.number)
                if ($null -ne $previous -and -not [string]::IsNullOrWhiteSpace([string]$previous.text)) {
                    $legacyLabel = [System.Windows.Controls.TextBlock]::new()
                    $legacyLabel.Text = 'EARLIER COMBINED ANSWER  ·  Copy into the separate parts when ready'
                    Set-Res $legacyLabel ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Partial'
                    $legacyLabel.FontSize = 11
                    $legacyLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
                    $legacyLabel.Margin = [System.Windows.Thickness]::new(0,14,0,6)
                    $stack.Children.Add($legacyLabel) | Out-Null
                    $legacyText = [System.Windows.Controls.TextBox]::new()
                    $legacyText.Style = $script:app.FindResource('PlainTextBox')
                    $legacyText.Text = [string]$previous.text
                    $legacyText.IsReadOnly = $true
                    $legacyText.TextWrapping = 'Wrap'
                    Set-Res $legacyText ([System.Windows.Controls.TextBox]::BackgroundProperty) 'CardAlt'
                    Set-Res $legacyText ([System.Windows.Controls.TextBox]::ForegroundProperty) 'TextSecondary'
                    $legacyText.Padding = [System.Windows.Thickness]::new(10)
                    $stack.Children.Add($legacyText) | Out-Null
                }
            }
            $card.Child = $stack
            $panel.Children.Add($card) | Out-Null
        }
    }
    Update-BsfNotes
    $script:ui.BsfQuestionsView.ScrollToTop()
    Set-BsfTab $script:bsfTab
}

function Update-BsfNotes {
    $previous = $script:bsfLessonNumber - 1
    $doc = [System.Windows.Documents.FlowDocument]::new()
    $doc.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Variable Text, Segoe UI')
    $doc.FontSize = 15
    $doc.LineHeight = 24
    $doc.PagePadding = [System.Windows.Thickness]::new(18,12,18,12)
    $doc.Background = [System.Windows.Media.Brushes]::Transparent
    Set-Res $doc ([System.Windows.Documents.FlowDocument]::ForegroundProperty) 'Text'
    $script:bsfNotesText = ''
    if ($previous -ge 1) {
        $previousLesson = $script:bsfLessons[$previous - 1]
        $script:ui.BsfNotesHeading.Text = "LESSON $previous NOTES  ·  $($previousLesson.scripture)"
        $context = Get-ReferenceContext ([string]$previousLesson.scripture)
        $book = $context.book
        $chapter = $context.chapter
        $plain = [System.Collections.Generic.List[string]]::new()
        foreach ($page in $previousLesson.notesPages) {
            $pageLabel = [System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new("PAGE $($page.printedPage)"))
            $pageLabel.FontSize = 11
            $pageLabel.FontWeight = [System.Windows.FontWeights]::Bold
            $pageLabel.Margin = [System.Windows.Thickness]::new(0,14,0,8)
            Set-Res $pageLabel ([System.Windows.Documents.TextElement]::ForegroundProperty) 'Accent'
            $doc.Blocks.Add($pageLabel)
            $plain.Add("PAGE $($page.printedPage)")
            foreach ($paragraphText in ([regex]::Split([string]$page.text, '\r?\n\s*\r?\n'))) {
                $clean = ($paragraphText -replace '\s*\r?\n\s*', ' ').Trim()
                if (-not $clean) { continue }
                $paragraph = [System.Windows.Documents.Paragraph]::new()
                $paragraph.Margin = [System.Windows.Thickness]::new(0,0,0,10)
                if ($clean.Length -lt 60 -and $clean -notmatch '[.?!:\u201D]$' -and $clean -notmatch '^●') {
                    $paragraph.FontWeight = [System.Windows.FontWeights]::SemiBold
                    $paragraph.FontSize = 16
                }
                $found = Add-LinkedInlines $paragraph.Inlines $clean $book $chapter
                $book = $found.book
                $chapter = $found.chapter
                $doc.Blocks.Add($paragraph)
                $plain.Add($clean)
            }
        }
        $script:bsfNotesText = $plain -join "`r`n"
    } else {
        $script:ui.BsfNotesHeading.Text = 'PREVIOUS LESSON NOTES'
        $doc.Blocks.Add([System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new('This is the first lesson. There are no earlier lesson notes in the book.')))
        $script:bsfNotesText = 'This is the first lesson.'
    }
    $script:ui.BsfNotesBody.Document = $doc
}

function Select-BsfLesson([int]$number, [bool]$followCurrent = $false) {
    $script:bsfLessonNumber = [math]::Max(1, [math]::Min(30, $number))
    $script:bsfFollowCurrent = $followCurrent
    Update-BsfView
}

function Update-BsfForDate {
    Update-BsfHomeTile
    if ($script:bsfFollowCurrent) {
        $number = Get-BsfLessonForDate (Get-Date)
        if ($number -ne $script:bsfLessonNumber) { Select-BsfLesson $number $true }
    }
}

function Get-BsfExportHtml([int]$lessonNumber) {
    $lesson = $script:bsfLessons[$lessonNumber - 1]
    $encode = [System.Net.WebUtility]
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Romans lesson answers</title>')
    $parts.Add('<style>body{font:15px/1.55 "Segoe UI",Arial,sans-serif;color:#1b1b1f;max-width:800px;margin:38px auto;padding:0 24px}h1{font:600 30px "Segoe UI",Arial,sans-serif;margin-bottom:3px}header p{color:#5b6370;margin-top:0}.day{font:700 13px "Segoe UI",Arial,sans-serif;letter-spacing:.04em;color:#0f6cbd;border-bottom:1px solid #c7d6ea;padding-bottom:7px;margin-top:28px}.question{page-break-inside:avoid;margin:20px 0 25px}.question h3{font:600 16px/1.45 "Segoe UI",Arial,sans-serif;white-space:pre-wrap}.introduction{color:#5b6370;white-space:pre-wrap}.answer{white-space:pre-wrap;border-left:3px solid #0f6cbd;padding:4px 0 4px 13px;min-height:32px}.empty{color:#9da5aa}.legacy{white-space:pre-wrap;color:#586375;background:#f1f4f9;padding:10px;margin-top:12px}footer{margin-top:36px;color:#77818a;font-size:11px}@media print{body{margin:0;max-width:none}.question{break-inside:avoid}}</style></head><body>')
    $parts.Add('<header><h1>Romans · Lesson ' + $lesson.number + '</h1><p>' + $encode::HtmlEncode([string]$lesson.title) + ' · ' + $encode::HtmlEncode([string]$lesson.scripture) + '</p></header>')
    $lastDay = ''
    foreach ($q in $lesson.questions) {
        if ($q.day -ne $lastDay) {
            $parts.Add('<div class="day">' + $encode::HtmlEncode([string]$q.day) + ' · ' + $encode::HtmlEncode([string]$q.instruction) + '</div>')
            $lastDay = [string]$q.day
        }
        foreach ($part in @(Get-BsfQuestionParts ([string]$q.text))) {
            $answer = Get-BsfAnswer ([int]$lesson.number) ([int]$q.number) ([string]$part.label)
            $answerText = if ($null -ne $answer) { [string]$answer.text } else { '' }
            $answerClass = if ($answerText.Trim()) { 'answer' } else { 'answer empty' }
            $displayAnswer = if ($answerText.Trim()) { $encode::HtmlEncode($answerText) } else { 'Answer space' }
            $label = if ($part.label) { "$($q.number)$($part.label)." } else { "$($q.number)." }
            $introduction = if ($part.introduction) { '<p class="introduction">' + $encode::HtmlEncode([string]$part.introduction) + '</p>' } else { '' }
            $legacy = ''
            if ($part.label -eq 'a') {
                $earlier = Get-BsfAnswer ([int]$lesson.number) ([int]$q.number)
                if ($null -ne $earlier -and -not [string]::IsNullOrWhiteSpace([string]$earlier.text)) {
                    $legacy = '<div class="legacy"><strong>Earlier combined answer:</strong> ' + $encode::HtmlEncode([string]$earlier.text) + '</div>'
                }
            }
            $parts.Add('<section class="question">' + $introduction + '<h3>' + $label + ' ' + $encode::HtmlEncode([string]$part.text) + '</h3><div class="' + $answerClass + '">' + $displayAnswer + '</div>' + $legacy + '</section>')
        }
    }
    $parts.Add('<footer>Prepared in Selah for personal BSF class study. Questions © Bible Study Fellowship.</footer></body></html>')
    return ($parts -join "`r`n")
}

function Export-BsfAnswers {
    $dialog = [Microsoft.Win32.SaveFileDialog]::new()
    $dialog.Title = 'Export Romans lesson answers'
    $dialog.FileName = ('Selah-Romans-Lesson-{0:D2}.html' -f $script:bsfLessonNumber)
    $dialog.DefaultExt = '.html'
    $dialog.Filter = 'Printable web page (*.html)|*.html'
    if ($dialog.ShowDialog($script:window) -ne $true) { return }
    [System.IO.File]::WriteAllText($dialog.FileName, (Get-BsfExportHtml $script:bsfLessonNumber), [System.Text.UTF8Encoding]::new($false))
    $script:ui.BsfSavedLabel.Text = 'Exported ✓'
    [System.Windows.MessageBox]::Show("Answers saved to:`n$($dialog.FileName)`n`nOpen the file in a browser to print or save as PDF.", 'Selah', 'OK', 'Information') | Out-Null
}
