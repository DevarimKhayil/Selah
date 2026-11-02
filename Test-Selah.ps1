$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $PSScriptRoot ('.selah-test-' + [guid]::NewGuid().ToString('N'))
$env:SELAH_DATA_DIR = $testRoot

try {
    . (Join-Path $PSScriptRoot 'Selah.ps1') -TestMode
    if ($script:dailyVerses.Count -lt 400) { throw 'Daily verse list did not load.' }
    $poolBooks = @($script:dailyVerses | ForEach-Object { ($_.reference -replace '\s+\d+:\d+$', '') } | Sort-Object -Unique)
    if ($poolBooks.Count -lt 60) { throw 'Daily verses should come from across the whole Bible.' }
    foreach ($entry in $script:dailyVerses) { if (-not (Get-VerseText ([string]$entry.reference))) { throw "Daily verse $($entry.reference) has no text." } }
    if ((Get-DailyVerse 0).text -notmatch 'In the beginning') { throw 'Daily verse text lookup failed.' }
    $psalm23 = @(0..($script:dailyVerses.Count - 1) | Where-Object { $script:dailyVerses[$_].reference -eq 'Psalm 23:1' })[0]
    if ((Get-DailyVerse $psalm23).text -notmatch '^The LORD is my shepherd') { throw 'Psalm heading was not trimmed from the daily verse.' }
    if ($script:allBibleBookNames.Count -ne 66 -or $script:bsfLessons.Count -ne 30 -or $script:torahPortions.Count -ne 51 -or $script:torahSpecialReadings.Count -ne 12) { throw 'Study data did not load.' }
    if ((Get-HebrewDate ([datetime]'2026-10-16')) -ne '5 Cheshvan 5787' -or
        (Get-HebrewDate ([datetime]'2027-02-10')) -ne '3 Adar I 5787' -or
        (Get-HebrewDate ([datetime]'2027-04-22')) -ne '15 Nisan 5787' -or
        (Get-HebrewDate ([datetime]'2028-04-10')) -ne '14 Nisan 5788') { throw 'English Hebrew date failed.' }
    $portion = Get-TorahPortion ([datetime]'2026-10-16')
    if ($portion.name -ne 'Noach' -or $portion.torah -ne 'Genesis 6:9–11:32') { throw 'Weekly Torah selection failed.' }
    if ((Get-TorahPortion ([datetime]'2027-08-07')).name -ne 'Devarim') { throw 'Later Torah selection failed.' }
    if ((Get-TorahReading ([datetime]'2027-04-22')).name -ne 'Pesach I' -or (Get-TorahReading ([datetime]'2027-06-12')).name -ne 'Shavuot II') { throw 'Special Torah reading selection failed.' }
    if ($null -ne (Get-TorahReading ([datetime]'2027-10-25'))) { throw 'Completed Torah card should not invent another reading.' }
    if ((Get-BsfLessonForDate ([datetime]'2026-10-14')) -ne 5 -or (Get-BsfLessonForDate ([datetime]'2026-10-21')) -ne 6 -or
        (Get-BsfLessonForDate ([datetime]'2026-10-20')) -ne 5 -or (Get-BsfLessonForDate ([datetime]'2026-10-13')) -ne 4 -or
        (Get-BsfWeekStart 7).DayOfWeek -ne 'Wednesday') { throw 'Wednesday BSF lesson schedule failed.' }
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
    $questionWithIntroduction = @($script:bsfLessons[28].questions | Where-Object { $_.number -eq 6 })[0]
    $introducedParts = @(Get-BsfQuestionParts ([string]$questionWithIntroduction.text))
    if ($introducedParts.Count -ne 3 -or $introducedParts[0].introduction -notmatch 'Review Romans' -or
        ($introducedParts | ForEach-Object { $_.label }) -join ',' -ne 'a,b,c') { throw 'Lettered question introduction was not split correctly.' }
    $script:bsfAnswers.Add([pscustomobject]@{ lesson = 5; number = 9; text = 'Earlier combined answer'; updatedAt = (Get-Date).ToString('o') })
    Save-State
    Select-BsfLesson 5 $true
    if ($script:ui.BsfLessonHeading.Text -notmatch 'Lesson 5' -or $script:ui.BsfNotesHeading.Text -notmatch 'LESSON 4 NOTES' -or
        $script:bsfNotesText -notmatch 'Inadequate Defense' -or $null -eq $script:ui.BsfNotesBody.Document) { throw 'Romans lesson and previous notes view failed.' }
    $noteLinks = @($script:ui.BsfNotesBody.Document.Blocks | ForEach-Object { $_.Inlines } | Where-Object { $_ -is [System.Windows.Documents.Hyperlink] })
    if ($noteLinks.Count -lt 5) { throw 'Scripture references in the notes are not clickable.' }
    function Get-CardTextBoxes($card) {
        foreach ($child in $card.Child.Children) {
            if ($child -is [System.Windows.Controls.TextBox]) { $child }
            elseif ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.TextBox]) { $child.Child }
        }
    }
    $questionCards = @($script:ui.BsfQuestionPanel.Children | Where-Object { $_ -is [System.Windows.Controls.Border] })
    $promptLinks = @($script:ui.BsfQuestionPanel.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] } | ForEach-Object { $_.Inlines } | Where-Object { $_ -is [System.Windows.Documents.Hyperlink] })
    if ($promptLinks.Count -lt 1) { throw 'Day instructions do not link their Scripture.' }
    if ($questionCards.Count -ne 20) { throw 'Lettered Romans questions were not given separate cards.' }
    $question9a = @($questionCards | Where-Object { $_.Child.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] -and $_.Text -like '9a.*' } })[0]
    $question9b = @($questionCards | Where-Object { $_.Child.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] -and $_.Text -like '9b.*' } })[0]
    if ($null -eq $question9a -or $null -eq $question9b -or $null -eq (Get-BsfAnswer 5 9)) { throw 'Question 9 parts or earlier answer are missing.' }
    if (@(Get-CardTextBoxes $question9a | Where-Object { $_.IsReadOnly -and $_.Text -eq 'Earlier combined answer' }).Count -ne 1) { throw 'Earlier combined answer is not visible beside the new fields.' }
    $answer9a = @(Get-CardTextBoxes $question9a | Where-Object { -not $_.IsReadOnly -and $_.Tag.part -eq 'a' })[0]
    $answer9b = @(Get-CardTextBoxes $question9b | Where-Object { -not $_.IsReadOnly -and $_.Tag.part -eq 'b' })[0]
    $answer9a.Text = 'Answer for part a'
    $answer9b.Text = 'Answer for part b'
    if ((Get-BsfAnswer 5 9 'a').text -ne 'Answer for part a' -or (Get-BsfAnswer 5 9 'b').text -ne 'Answer for part b') { throw 'Separate Romans answers did not autosave.' }
    $firstAnswerBox = @(Get-CardTextBoxes $questionCards[0])[0]
    $firstAnswerBox.Text = 'Grace & truth <saved>'
    if ((Get-BsfAnswer 5 1).text -ne 'Grace & truth <saved>') { throw 'Romans answer did not autosave.' }
    Select-BsfLesson 6
    Select-BsfLesson 5
    $restoredCards = @($script:ui.BsfQuestionPanel.Children | Where-Object { $_ -is [System.Windows.Controls.Border] })
    $restoredAnswerBox = @(Get-CardTextBoxes $restoredCards[0])[0]
    if ($restoredAnswerBox.Text -ne 'Grace & truth <saved>') { throw 'Romans answer was lost when switching lessons.' }
    $restored9b = @($restoredCards | ForEach-Object { Get-CardTextBoxes $_ } | Where-Object { -not $_.IsReadOnly -and $_.Tag.part -eq 'b' -and $_.Tag.number -eq 9 })[0]
    if ($restored9b.Text -ne 'Answer for part b') { throw 'Lettered answer was lost when switching lessons.' }
    $exportHtml = Get-BsfExportHtml 5
    if ($exportHtml -notmatch 'Grace &amp; truth &lt;saved&gt;' -or $exportHtml -notmatch '9a\.' -or
        $exportHtml -notmatch '9b\.' -or $exportHtml -notmatch 'Earlier combined answer' -or
        $exportHtml -notmatch 'Answer for part a' -or $exportHtml -notmatch 'Answer for part b') { throw 'Romans printable export failed.' }
    if ((Normalize-Verse '  Be still, LORD! ') -ne (Normalize-Verse 'be still lord')) { throw 'Answer comparison failed.' }
    $practiceUi = Load-Xaml (Join-Path $PSScriptRoot 'PracticeWindow.xaml')
    if ($null -eq $practiceUi.FindName('AnswerInput').CaretBrush) { throw 'Practice caret brush is missing.' }
    if ($null -eq $practiceUi.FindName('HintButton')) { throw 'Hint control is missing.' }
    $inviteUi = Load-Xaml (Join-Path $PSScriptRoot 'DailyInviteWindow.xaml')
    if ($null -eq $inviteUi.FindName('DailyInviteReadButton') -or $null -eq $inviteUi.FindName('DailyInviteReadyButton')) { throw 'Daily invitation controls are missing.' }
    if ((@(Get-ReminderTimes) -join ',') -ne '10:00,12:30,14:00,16:30') { throw 'Practice reminder times are incorrect.' }
    if (-not $script:offerDailyWhenNoFocus) { throw 'Daily fallback should default to on.' }
    Update-WordFeedback 'The wrong shep' 'The LORD is my shepherd;' ($practiceUi.FindName('WordFeedbackPanel'))
    if ($practiceUi.FindName('WordFeedbackPanel').Children.Count -ne 3) { throw 'Colored word preview failed.' }
    $addUi = Load-Xaml (Join-Path $PSScriptRoot 'AddVerseWindow.xaml')
    if ($null -eq $addUi.FindName('FillVerseButton')) { throw 'Add verse Fill in button is missing.' }
    Set-Theme 'Dark'
    $darkCaret = $script:ui.JournalEditor.CaretBrush.Color.ToString()
    Set-Theme 'Light'
    if ($darkCaret -eq $script:ui.JournalEditor.CaretBrush.Color.ToString()) { throw 'Theme switch did not update the caret colour.' }
    if ($script:ui.HomeNav.Tag -ne 'Selected') { throw 'Navigation selection is not shown.' }
    $live = @(Get-LiveWords 'The wrong shep' 'The LORD is my shepherd;')
    if ($live.Count -ne 3 -or $live[0].status -ne 'correct' -or $live[1].status -ne 'wrong' -or $live[2].status -ne 'wrong') { throw 'Live word feedback failed.' }
    if ((Get-NextHint 'The' 'The LORD is my shepherd;') -notlike 'Hint: word 2 begins with "L".*' -or (Get-NextHint 'The' 'The LORD is my shepherd;' 2) -ne 'Hint: word 2 is "LORD".') { throw 'Hint failed.' }

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
    if ($saved.bsfAnswers.Count -ne 4 -or
        @($saved.bsfAnswers | Where-Object { $_.lesson -eq 5 -and $_.number -eq 9 -and $_.part -eq 'b' -and $_.text -eq 'Answer for part b' }).Count -ne 1 -or
        @($saved.bsfAnswers | Where-Object { $_.lesson -eq 5 -and $_.number -eq 1 -and $_.text -eq 'Grace & truth <saved>' }).Count -ne 1) { throw 'Separate Romans answers were not persisted.' }
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
    Write-Output 'PASS: startup, themes, reminders, Hebrew date, Torah schedule, Wednesday Romans lessons, clickable references, answers and export, BSB/KJV passages and NIV links, whole-Bible daily verses, verse practice, Bible notes, reflections'
} finally {
    $expectedPrefix = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\.selah-test-'
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and [System.IO.Directory]::Exists($resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Item Env:SELAH_DATA_DIR -ErrorAction SilentlyContinue
}
