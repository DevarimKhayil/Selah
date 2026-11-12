# =====================================================================================
# Test-Selah.ps1 - desktop smoke test (Windows PowerShell 5.1, run with -STA).
# Starts Selah in -TestMode with a throwaway data folder, then checks: file encodings, data
# loading, Hebrew dates and the Torah card, reference detection and passages, daily verses,
# practice (answer checking, hints, peek, live word check), dialogs, themes and fonts, the
# Week page, Bible browsing and highlights, notes, reflections and that state.json is saved.
# Any failure throws with a plain message. RunCheck.cmd runs this and saves preview images.
# =====================================================================================
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $PSScriptRoot ('.selah-test-' + [guid]::NewGuid().ToString('N'))
$env:SELAH_DATA_DIR = $testRoot

foreach ($psFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $head = [System.IO.File]::ReadAllBytes($psFile.FullName) | Select-Object -First 3
    if (($head -join ',') -ne '239,187,191') { throw "$($psFile.Name) must be saved as UTF-8 with BOM, or Windows PowerShell misreads it." }
}

try {
    . (Join-Path $PSScriptRoot 'Selah.ps1') -TestMode
    if ($script:dailyVerses.Count -lt 400) { throw 'Daily verse list did not load.' }
    $poolBooks = @($script:dailyVerses | ForEach-Object { ($_.reference -replace '\s+\d+:\d+$', '') } | Sort-Object -Unique)
    if ($poolBooks.Count -lt 60) { throw 'Daily verses should come from across the whole Bible.' }
    foreach ($entry in $script:dailyVerses) { if (-not (Get-VerseText ([string]$entry.reference))) { throw "Daily verse $($entry.reference) has no text." } }
    if ((Get-DailyVerse 0).text -notmatch 'In the beginning') { throw 'Daily verse text lookup failed.' }
    $psalm23 = @(0..($script:dailyVerses.Count - 1) | Where-Object { $script:dailyVerses[$_].reference -eq 'Psalm 23:1' })[0]
    if ((Get-DailyVerse $psalm23).text -notmatch '^The LORD is my shepherd') { throw 'Psalm heading was not trimmed from the daily verse.' }
    if ($script:allBibleBookNames.Count -ne 66 -or $script:torahPortions.Count -ne 51 -or $script:torahSpecialReadings.Count -ne 12) { throw 'Study data did not load.' }
    if ((Get-HebrewDate ([datetime]'2026-10-16')) -ne '5 Cheshvan 5787' -or
        (Get-HebrewDate ([datetime]'2027-02-10')) -ne '3 Adar I 5787' -or
        (Get-HebrewDate ([datetime]'2027-04-22')) -ne '15 Nisan 5787' -or
        (Get-HebrewDate ([datetime]'2028-04-10')) -ne '14 Nisan 5788') { throw 'English Hebrew date failed.' }
    $portion = Get-TorahPortion ([datetime]'2026-10-16')
    if ($portion.name -ne 'Noach' -or $portion.torah -ne 'Genesis 6:9–11:32') { throw 'Weekly Torah selection failed.' }
    if ((Get-TorahPortion ([datetime]'2027-08-07')).name -ne 'Devarim') { throw 'Later Torah selection failed.' }
    if ((Get-TorahReading ([datetime]'2027-04-22')).name -ne 'Pesach I' -or (Get-TorahReading ([datetime]'2027-06-12')).name -ne 'Shavuot II') { throw 'Special Torah reading selection failed.' }
    if ($null -ne (Get-TorahReading ([datetime]'2027-10-25'))) { throw 'Completed Torah card should not invent another reading.' }
    $found = Find-ScriptureReferences "See also John 1:12; 3:14-18;`n20:30-31; Ephesians 2:8-9; Hebrews 11; or other verses. From verse 27, what?" 'Romans' 3
    $refs = @($found.links | ForEach-Object { $_.reference }) -join '|'
    if ($refs -ne 'John 1:12|John 3:14-18|John 20:30-31|Ephesians 2:8-9|Hebrews 11|Hebrews 11:27') { throw "Reference detection failed: $refs" }
    $found = Find-ScriptureReferences 'From verse 27, what is excluded?' 'Romans' 3
    if (@($found.links)[0].reference -ne 'Romans 3:27') { throw 'Contextual verse link failed.' }
    if (@((Find-ScriptureReferences 'Read the Lesson 5 Notes.').links).Count -ne 0) { throw 'Reference detection found a false match.' }
    $romansText = Get-ScriptureText 'Romans 3:23'
    $scriptureUi = Load-Xaml (Join-Path $PSScriptRoot 'ScriptureWindow.xaml')
    if ($null -eq $scriptureUi.FindName('ScriptureDoc') -or $null -eq $scriptureUi.FindName('ScriptureNivButton')) { throw 'Scripture dialog did not load.' }
    $scriptureUi.FindName('ScriptureDoc').Document = New-ScriptureDocument 'Romans 3:21-26' 'BSB'
    if ((Get-ScriptureText 'Romans 3:23' 'KJV') -notmatch 'come short of the glory') { throw 'KJV passage lookup failed.' }
    if ((Get-NivUrl 'Romans 3:27-28') -ne 'https://www.biblegateway.com/passage/?search=Romans%203%3A27-28&version=NIV') { throw 'NIV link failed.' }
    if ($romansText -notmatch 'For all have sinned' -or (Get-ScriptureText 'Genesis 6:9–11:32') -notmatch '11:32' -or
        (Get-ScriptureText '1 Samuel 20:18–42') -notmatch '20:42') { throw 'Offline passage lookup failed.' }
    $multiPassage = Get-ScriptureText 'Joshua 3:5–7, 5:2–6:1, 6:27'
    if ($multiPassage -notmatch '3:5' -or $multiPassage -notmatch '5:2' -or $multiPassage -notmatch '6:27') { throw 'Multi-part KJV passage lookup failed.' }
    if ((Normalize-Verse '  Be still, LORD! ') -ne (Normalize-Verse 'be still lord')) { throw 'Answer comparison failed.' }
    if (-not (Test-VerseMatch 'is to come the Almighty' 'is to come—the Almighty') -or -not (Test-VerseMatch 'is to come-the Almighty' 'is to come—the Almighty') -or
        (Test-VerseMatch 'is to come Almighty' 'is to come—the Almighty')) { throw 'Dashed words should be typed as separate words.' }
    $practiceUi = Load-Xaml (Join-Path $PSScriptRoot 'PracticeWindow.xaml')
    if ($null -eq $practiceUi.FindName('AnswerInput').CaretBrush) { throw 'Practice caret brush is missing.' }
    if ($null -eq $practiceUi.FindName('HintButton')) { throw 'Hint control is missing.' }
    foreach ($needed in @('PeekButton','PeekPanel','PeekText','PeekCaption','SourceLabel','SourceIcon','SourceBadge','WordFeedbackScroll','PeekScroll')) {
        if ($null -eq $practiceUi.FindName($needed)) { throw "PracticeWindow.xaml is missing '$needed'." }
    }
    $inviteUi = Load-Xaml (Join-Path $PSScriptRoot 'DailyInviteWindow.xaml')
    if ($null -eq $inviteUi.FindName('DailyInviteReadButton') -or $null -eq $inviteUi.FindName('DailyInviteReadyButton')) { throw 'Daily invitation controls are missing.' }
    if ((@(Get-ReminderTimes) -join ',') -ne '10:00,12:30,14:00,16:30') { throw 'Practice reminder times are incorrect.' }
    if (-not $script:offerDailyWhenNoFocus) { throw 'Daily fallback should default to on.' }
    Update-WordFeedback 'The wrong shep' 'The LORD is my shepherd;' ($practiceUi.FindName('WordFeedbackPanel'))
    if ($practiceUi.FindName('WordFeedbackPanel').Children.Count -ne 3) { throw 'Colored word preview failed.' }
    $peekProbe = [System.Windows.Controls.TextBox]::new(); $peekProbe.Text = 'The LORD is'
    Show-PeekAt $peekProbe 'The LORD is my shepherd; I shall not want.' ($practiceUi.FindName('PeekText')) ($practiceUi.FindName('PeekScroll'))
    $peekRuns = @($practiceUi.FindName('PeekText').Inlines)
    if ($peekRuns.Count -ne 3 -or $peekRuns[1].Text -ne 'my') { throw 'Peek should mark the next word to type.' }
    $addUi = Load-Xaml (Join-Path $PSScriptRoot 'AddVerseWindow.xaml')
    if ($null -eq $addUi.FindName('FillVerseButton') -or $null -eq $addUi.FindName('DialogTitle') -or $null -eq $addUi.FindName('DialogCaption')) { throw 'Add verse dialog is out of date.' }
    Set-Theme 'Dark'
    $darkCaret = $script:ui.JournalEditor.CaretBrush.Color.ToString()
    Set-Theme 'Light'
    if ($darkCaret -eq $script:ui.JournalEditor.CaretBrush.Color.ToString()) { throw 'Theme switch did not update the caret colour.' }
    $script:weeks = @{}; $script:habits.Clear()
    Show-Page 'Week'
    if ($script:ui.WeekPage.Visibility -ne 'Visible' -or $script:ui.WeekContent.Children.Count -lt 2) { throw 'Week page did not open.' }
    Add-WeekItem 'goal' 'Test goal'
    Add-WeekItem 'task' 'Test task'
    $testWeek = Get-WeekData $script:weekStart $false
    if ($testWeek.goals.Count -ne 1 -or (Get-WeekDay $testWeek $script:weekDay).tasks.Count -ne 1) { throw 'Week goals or tasks were not added.' }
    Set-WeekTaskRepeat (Get-WeekDay $testWeek $script:weekDay).tasks[0] 'daily'
    if ($script:habits.Count -ne 1) { throw 'Repeating task was not saved as a habit.' }
    if ((Get-WeekNumber ([datetime]'2026-11-12')) -ne 46 -or (Get-WeekNumber ([datetime]'2026-01-01')) -ne 1) { throw 'Week number is wrong.' }
    $roundTrip = (ConvertTo-Json -InputObject ([pscustomobject]@{ weeks = $script:weeks; habits = @($script:habits.ToArray()) }) -Depth 12) | ConvertFrom-Json
    Read-WeekData $roundTrip
    if ((Get-WeekData $script:weekStart $false).goals[0].text -ne 'Test goal' -or $script:habits.Count -ne 1) { throw 'Week data did not survive saving.' }
    $script:weeks = @{}; $script:habits.Clear()
    Show-Page 'Home'
    if ($script:ui.HomeNav.Tag -ne 'Selected') { throw 'Navigation selection is not shown.' }
    $live = @(Get-LiveWords 'The wrong shep' 'The LORD is my shepherd;')
    if ($live.Count -ne 3 -or $live[0].status -ne 'correct' -or $live[1].status -ne 'wrong' -or $live[2].status -ne 'wrong') { throw 'Live word feedback failed.' }
    $ell = [string][char]0x2026
    if ((Get-NextHint 'The' 'The LORD is my shepherd;') -notlike ('Hint: word 2 starts with "L' + $ell + '".*') -or
        (Get-NextHint 'The' 'The LORD is my shepherd;' 2) -notlike ('Hint: word 2 starts with "LO' + $ell + '".*') -or
        (Get-NextHint 'The' 'The LORD is my shepherd;' 3) -notlike ('Hint: word 2 starts with "LOR' + $ell + '".*') -or
        (Get-NextHint 'The' 'The LORD is my shepherd;' 9) -notlike ('Hint: word 2 starts with "LOR' + $ell + '".*') -or
        (Get-NextHint 'The LORD is' 'The LORD is my shepherd;' 2) -ne 'Hint: word 4 is "my".') { throw 'Hint failed (one letter per press, at most three).' }
    foreach ($font in @('Inter-400.ttf','Inter-600.ttf','Inter-700.ttf','SourceSerif4-400.ttf','SourceSerif4-600.ttf')) {
        if (-not [System.IO.File]::Exists((Join-Path $PSScriptRoot "Fonts\$font"))) { throw "Fonts\$font is missing." }
    }
    if ([string]$script:app.FindResource('ReadingFont').Source -notlike '*Source Serif 4*') { throw 'Reading font is not set.' }
    if ($script:palettes.Light.Bg[0] -ne '#F7F7F1' -or $script:palettes.Dark.Bg[0] -ne '#0A0A0A') { throw 'Chalk palette is not in use.' }

    $firstDay = @(Get-TodayReadings ([datetime]'2026-10-01'))
    $lastDay = @(Get-TodayReadings ([datetime]'2026-10-31'))
    if ($firstDay.Count -ne 6 -or $firstDay[0].label -ne 'Proverbs 1' -or $firstDay[5].label -ne 'Psalm 121') { throw 'First-day reading plan failed.' }
    if ($lastDay.Count -ne 5 -or $lastDay[-1].label -ne 'Psalm 121') { throw 'Last-day reading plan failed.' }
    if ((Get-BibleBookData 'Psalms').chapters.Count -ne 150 -or (Get-BibleBookData 'Proverbs').chapters.Count -ne 31 -or
        (Get-BibleBookData 'Psalms' 'KJV').chapters.Count -ne 150 -or $script:bookRows.Count -ne 66) { throw 'Bible books did not load.' }
    Set-BibleChapter 'Romans' 8
    if ($script:ui.BibleChapterTitle.Text -ne 'Romans 8' -or $script:bookRows['Romans'].header.Tag -ne 'Selected' -or
        $script:bookRows['Romans'].grid.Children.Count -ne 16 -or $script:bookRows['Romans'].grid.Children[7].Tag -ne 'Selected') { throw 'Book browsing failed.' }
    Open-BibleVerse 'Romans|8|28'
    if ($script:ui.HighlightSwatchPanel.Children.Count -ne 13) { throw 'Highlight colours are missing.' }
    $script:ui.HighlightSwatchPanel.Children[7].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    if ((Get-Highlight 'Romans|8|28') -ne 'sky') { throw 'Highlight was not saved.' }
    Show-Page 'Highlights'
    if (@($script:ui.HighlightListPanel.Children).Count -ne 1) { throw 'Highlights page failed.' }
    Set-Highlight 'Romans|8|28' ''
    Show-Page 'Bible'
    if ((Get-BibleChapter 'Psalms' 150).verses.Count -eq 0 -or (Get-BibleChapter 'Proverbs' 31).verses.Count -eq 0) { throw 'Final Bible chapters are missing.' }
    $script:ui.TodayReadingsPanel.Children[0].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    if ($script:ui.BiblePage.Visibility -ne 'Visible' -or $script:ui.BibleChapterTitle.Text -ne "Proverbs $((Get-Date).Day)") { throw 'Daily reading link failed.' }
    Set-BibleChapter 'Psalms' 1
    $script:ui.BibleVersesPanel.Children[0].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    if ($script:ui.BibleNoteReference.Text -notmatch 'Psalm 1:1') { throw 'Bible verse selection failed.' }
    $script:ui.BibleNoteEditor.Text = 'A note on this Psalm.'
    Save-BibleNote

    $verse = Add-Verse 'Psalm 121:1' 'I will lift up mine eyes unto the hills, from whence cometh my help.'
    if ($script:verses.Count -ne 1 -or $script:focusId -ne $verse.id) { throw 'Verse add or focus failed.' }
    Add-Verse $verse.reference $verse.text | Out-Null
    if ($script:verses.Count -ne 1) { throw 'Duplicate prevention failed.' }

    Record-Pass $verse | Out-Null
    Record-Pass $verse | Out-Null
    if ($verse.passes -ne 2 -or $verse.memorizedAt) { throw 'Practice progress failed.' }
    Record-Pass $verse | Out-Null
    if (-not $verse.memorizedAt -or $script:focusId) { throw 'Memorized transition failed.' }

    $dailyText = Get-DailyVerse
    $dailyPractice = Add-Verse $dailyText.reference $dailyText.text $false 'daily'
    if ($script:focusId -or $dailyPractice.source -ne 'daily') { throw 'Daily verse should not become the focused verse automatically.' }
    Record-Pass $dailyPractice | Out-Null
    if ($dailyPractice.passes -ne 1 -or $dailyPractice.memorizedAt) { throw 'Daily practice was not saved.' }
    if ((Get-TodaysPracticeVerse).id -ne $dailyPractice.id) { throw 'Daily practice verse could not be recovered.' }
    if ($script:ui.FocusTitle.Text -ne "TODAY'S VERSE" -or $script:ui.FocusProgress.Text -ne 'PASS 1 / 3' -or -not $script:ui.PracticeButton.IsEnabled) { throw 'Daily verse is not shown on Today.' }
    $recycled = [pscustomobject]@{ memorizedAt = (Get-Date).AddDays(-1).ToString('o'); lastReviewedAt = $null }
    if (Test-DailyCompletedToday $recycled (Get-Date)) { throw 'An older memorized daily verse should be offered for review.' }
    $recycled.lastReviewedAt = (Get-Date).ToString('o')
    if (-not (Test-DailyCompletedToday $recycled (Get-Date))) { throw 'A reviewed daily verse should stop prompting today.' }

    Open-JournalDate (Get-Date).ToString('yyyy-MM-dd')
    $todayReflectionDate = $script:journalDate
    $previousReflectionDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
    $script:ui.JournalEditor.Text = 'A reflection saved today. '
    Open-JournalDate $previousReflectionDate
    if ($script:ui.JournalEditor.Text -ne '') { throw 'A new reflection date should start empty.' }
    $script:ui.JournalEditor.Text = 'A thought from yesterday.'
    Open-JournalDate $todayReflectionDate
    if ($script:ui.JournalEditor.Text -ne 'A reflection saved today. ') { throw 'Reflection text was lost when switching dates.' }
    $previousItem = @($script:ui.ReflectionList.Items | Where-Object { $_.Tag -eq $previousReflectionDate })[0]
    $script:ui.ReflectionList.SelectedItem = $previousItem
    if ($script:ui.JournalEditor.Text -ne 'A thought from yesterday.') { throw 'Previous reflection selection failed.' }
    Open-JournalDate $todayReflectionDate
    $saved = Get-Content -LiteralPath (Join-Path $testRoot 'state.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.verses.Count -ne 2 -or -not $saved.verses[0].memorizedAt -or $saved.verses[1].passes -ne 1) { throw 'Verses were not persisted.' }
    if (-not $saved.offerDailyWhenNoFocus) { throw 'Daily offer setting was not persisted.' }
    if ($saved.reflections.Count -ne 2 -or
        @($saved.reflections | Where-Object { $_.date -eq $todayReflectionDate -and $_.text -ceq 'A reflection saved today. ' }).Count -ne 1 -or
        @($saved.reflections | Where-Object { $_.date -eq $previousReflectionDate -and $_.text -eq 'A thought from yesterday.' }).Count -ne 1) { throw 'Reflections did not autosave by date.' }
    if ($saved.bibleNotes.Count -ne 1 -or $saved.bibleNotes[0].key -ne 'Psalms|1|1') { throw 'Bible note was not persisted.' }
    if ($null -ne $saved.bsfAnswers) { throw 'Romans answers should no longer be saved.' }
    $seen = [System.Collections.Generic.HashSet[int]]::new()
    $seen.Add([int]$script:daily.index) | Out-Null
    for ($i = 1; $i -lt $script:dailyVerses.Count; $i++) {
        $script:daily.date = '2000-01-01'
        Ensure-DailyVerse
        if (-not $seen.Add([int]$script:daily.index)) { throw 'Daily verse repeated before the set was used.' }
    }
    if ($seen.Count -ne $script:dailyVerses.Count) { throw 'Daily verse rotation did not cover the set.' }
    Set-Translation 'KJV'
    if ($script:ui.DailyVersionLabel.Text -notmatch 'KJV' -or $script:ui.BibleVersionLabel.Text -ne 'KING JAMES VERSION') { throw 'Translation switch failed.' }
    Set-Translation 'BSB'
    Write-Output 'PASS: startup, themes, reminders, Hebrew date, Torah schedule, Week page, Scripture references, BSB/KJV passages and NIV links, whole-Bible daily verses, verse practice, Bible notes, reflections'
} finally {
    $expectedPrefix = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\.selah-test-'
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and [System.IO.Directory]::Exists($resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Item Env:SELAH_DATA_DIR -ErrorAction SilentlyContinue
}
