# =====================================================================================
# WeekFeatures.ps1 - the Week page (weekly goals and daily tasks), shared with the phone.
# Data shape in state.json:
#   weeks  = { '<Monday yyyy-MM-dd>': { words:[..], goals:[{id,text,tag,status}],
#              days:{ '<yyyy-MM-dd>': { tasks:[{id,text,status,goal,habit,from,carried}],
#                                       habitsAdded, carryDismissed } }, review, updatedAt } }
#   habits = [ { id, text, repeat:'daily'|'weekdays', goal } ]
# Status values: '' (open), 'done', 'partly', 'tried', 'no' (did not happen).
# Event handlers keep their data in each control's Tag instead of closures (closures lose
# access to script-scope functions in WPF event handlers).
# =====================================================================================
$script:weeks = @{}
$script:habits = [System.Collections.Generic.List[object]]::new()
$script:weekStart = ''
$script:weekDay = ''
$script:weekFocus = ''
$script:weekRendering = $false
$script:weekTags = @('Work','Study','Faith','Health','Family','Money','Investment','Personal')
$script:weekStatuses = @('', 'done', 'partly', 'tried', 'no')
$script:weekStatusLabel = @{ '' = 'Open'; 'done' = 'Done'; 'partly' = 'Partly'; 'tried' = 'Tried'; 'no' = [string][char]0x2715 }
$script:weekBoxMark = @{ '' = ''; 'done' = [string][char]0x2713; 'partly' = [string][char]0x00BD; 'tried' = '~'; 'no' = [string][char]0x2715 }
$script:weekDayNames = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')

# Turns data from ConvertFrom-Json (PSCustomObjects, fixed arrays) into hashtables and
# lists that can be edited in place. Week data is stored in that editable form.
# ConvertFrom-Json gives PSCustomObjects and fixed arrays; turn them into hashtables and lists we can edit.
function ConvertTo-PlainData($value) {
    if ($null -eq $value) { return $null }
    if ($value -is [string] -or $value -is [ValueType]) { return $value }
    if ($value -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in @($value.Keys)) { $h[[string]$k] = ConvertTo-PlainData $value[$k] }
        return $h
    }
    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $value.PSObject.Properties) { $h[$p.Name] = ConvertTo-PlainData $p.Value }
        return $h
    }
    if ($value -is [System.Collections.IEnumerable]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $value) { $list.Add((ConvertTo-PlainData $item)) }
        return ,$list
    }
    return $value
}

# Loads 'weeks' and 'habits' from state.json into $script:weeks and $script:habits.
function Read-WeekData($raw) {
    $script:weeks = @{}
    $script:habits.Clear()
    if ($null -ne $raw.weeks) {
        $plain = ConvertTo-PlainData $raw.weeks
        if ($plain -is [hashtable]) { foreach ($k in @($plain.Keys)) { if ($plain[$k] -is [hashtable]) { $script:weeks[$k] = $plain[$k] } } }
    }
    foreach ($h in @($raw.habits)) { if ($null -ne $h -and $h.id) { $script:habits.Add((ConvertTo-PlainData $h)) } }
}

# The Monday that starts the week containing $date (weeks run Monday to Sunday).
function Get-WeekMonday([datetime]$date) { $d = $date.Date; return $d.AddDays(-(([int]$d.DayOfWeek + 6) % 7)) }

# ISO week number (1-53). Implemented by hand because .NET Framework has no ISOWeek class.
function Get-WeekNumber([datetime]$date) {
    $thursday = $date.Date.AddDays(3 - (([int]$date.DayOfWeek + 6) % 7))
    return [int][math]::Floor(($thursday.DayOfYear - 1) / 7) + 1
}

# Formats a date as 'yyyy-MM-dd', the key used for days and weeks.
function ConvertTo-IsoDay([datetime]$date) { return $date.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }

# Parses a 'yyyy-MM-dd' key back into a date.
function ConvertFrom-IsoDay([string]$iso) { return [datetime]::ParseExact($iso, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }

# Short random id for goals, tasks and habits.
function New-WeekId { return [guid]::NewGuid().ToString('N').Substring(0, 10) }

# Next status when a pill or box is clicked: open -> done -> partly -> tried -> no -> open.
function Get-NextWeekStatus([string]$status) {
    $i = [array]::IndexOf($script:weekStatuses, [string]$status)
    return $script:weekStatuses[($i + 1) % $script:weekStatuses.Count]
}

# True for statuses that still need attention (open, partly, tried).
function Test-WeekStatusOpen([string]$status) { return (-not $status) -or $status -eq 'partly' -or $status -eq 'tried' }

# Makes sure $table[$key] is an editable list (JSON may give null, one item or an array).
# Make sure $table[$key] is an editable list (JSON may give null, one item or a fixed array).
function Initialize-WeekList($table, [string]$key) {
    if ($table[$key] -isnot [System.Collections.Generic.List[object]]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in @($table[$key])) { if ($null -ne $item) { $list.Add($item) } }
        $table[$key] = $list
    }
}

# Returns the week that starts on $startIso, creating an empty one when $create is true.
function Get-WeekData([string]$startIso, [bool]$create) {
    $week = $script:weeks[$startIso]
    if ($null -eq $week -and $create) {
        $week = @{ words = [System.Collections.Generic.List[object]]::new(); goals = [System.Collections.Generic.List[object]]::new(); days = @{}; review = ''; updatedAt = (Get-Date).ToString('o') }
        $script:weeks[$startIso] = $week
    }
    if ($null -ne $week) {
        Initialize-WeekList $week 'words'
        Initialize-WeekList $week 'goals'
        if ($week.days -isnot [hashtable]) { $week.days = @{} }
    }
    return $week
}

# Stamps the week as changed (used when syncing with the phone) and saves state.json.
function Save-Week($week) {
    $week.updatedAt = (Get-Date).ToString('o')
    Save-State
}

# True if a repeating task ('daily' or 'weekdays') belongs on the given day.
function Test-HabitApplies($habit, [string]$iso) {
    $weekday = ([int](ConvertFrom-IsoDay $iso).DayOfWeek + 6) % 7
    return $habit.repeat -eq 'daily' -or ($habit.repeat -eq 'weekdays' -and $weekday -lt 5)
}

# Returns a day's task list. The first time a day from today onwards is opened, repeating
# tasks (habits) are added to it automatically.
function Get-WeekDay($week, [string]$iso) {
    if ($week.days[$iso] -isnot [hashtable]) { $week.days[$iso] = @{ tasks = [System.Collections.Generic.List[object]]::new() } }
    $day = $week.days[$iso]
    Initialize-WeekList $day 'tasks'
    $tasks = $day.tasks
    # Daily habits fill themselves in the first time a day from today on is opened.
    if (-not $day.habitsAdded -and $iso -ge (ConvertTo-IsoDay (Get-Date))) {
        foreach ($habit in $script:habits) {
            if ((Test-HabitApplies $habit $iso) -and -not @($tasks | Where-Object { $_.habit -eq $habit.id }).Count) {
                $tasks.Add(@{ id = (New-WeekId); text = $habit.text; status = ''; goal = $habit.goal; habit = $habit.id })
            }
        }
        $day.habitsAdded = $true
        Save-Week $week
    }
    return $day
}

# Unfinished, not yet carried tasks from the day before $iso (for the 'Bring over' banner).
function Get-CarryCandidates([string]$iso) {
    $prevIso = ConvertTo-IsoDay ((ConvertFrom-IsoDay $iso).AddDays(-1))
    $prevWeek = Get-WeekData (ConvertTo-IsoDay (Get-WeekMonday (ConvertFrom-IsoDay $prevIso))) $false
    $result = @{ iso = $prevIso; week = $prevWeek; tasks = @() }
    if ($null -eq $prevWeek -or $prevWeek.days[$prevIso] -isnot [hashtable]) { return $result }
    $prevDay = $prevWeek.days[$prevIso]
    Initialize-WeekList $prevDay 'tasks'
    $result.tasks = @($prevDay.tasks | Where-Object { (Test-WeekStatusOpen ([string]$_.status)) -and -not $_.carried -and -not $_.habit -and $_.text })
    return $result
}

# Counts for the Sunday review: goals done, tasks done/total and days with progress.
function Get-WeekStats($week) {
    $stats = @{ goalsDone = 0; goals = $week.goals.Count; done = 0; total = 0; active = 0 }
    foreach ($g in $week.goals) { if ($g.status -eq 'done') { $stats.goalsDone++ } }
    foreach ($key in @($week.days.Keys)) {
        $any = $false
        Initialize-WeekList $week.days[$key] 'tasks'
        foreach ($t in $week.days[$key].tasks) {
            if ($t.carried) { continue }
            $stats.total++
            if ($t.status -eq 'done') { $stats.done++; $any = $true }
        }
        if ($any) { $stats.active++ }
    }
    return $stats
}

# ------------------------------------------------------------------ small UI helpers
# Small helper that makes a themed TextBlock.
function New-WeekText([string]$text, [double]$size = 14, [string]$brush = 'Text', [string]$weight = '') {
    $t = [System.Windows.Controls.TextBlock]::new()
    $t.Text = $text
    $t.FontSize = $size
    $t.TextWrapping = 'Wrap'
    $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $brush)
    if ($weight) { $t.FontWeight = [System.Windows.FontWeights]::$weight }
    return $t
}

# Small upper-case section caption.
function New-WeekCaption([string]$text) {
    $t = New-WeekText $text.ToUpperInvariant() 11.5 'TextSecondary' 'Bold'
    $t.Margin = [System.Windows.Thickness]::new(2, 18, 0, 8)
    return $t
}

# A clickable rounded status pill (Open, Done, Partly, Tried, X).
function New-WeekPill([string]$text, [string]$background, [string]$foreground, [string]$border, $tag, [scriptblock]$onClick, [string]$tip = '') {
    $b = [System.Windows.Controls.Border]::new()
    $b.CornerRadius = [System.Windows.CornerRadius]::new(12)
    $b.Padding = [System.Windows.Thickness]::new(11, 3, 11, 4)
    $b.MinWidth = 62
    $b.Cursor = [System.Windows.Input.Cursors]::Hand
    $b.VerticalAlignment = 'Center'
    if ($background) { $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $background) } else { $b.Background = [System.Windows.Media.Brushes]::Transparent }
    if ($border) { $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $border); $b.BorderThickness = [System.Windows.Thickness]::new(1.5) }
    $label = New-WeekText $text 12 $foreground 'Bold'
    $label.HorizontalAlignment = 'Center'
    $label.TextWrapping = 'NoWrap'
    $b.Child = $label
    $b.Tag = $tag
    if ($tip) { $b.ToolTip = $tip }
    $b.Add_MouseLeftButtonUp($onClick)
    return $b
}

# Theme colour keys (background, text, border) for each status.
function Get-WeekStatusLook([string]$status) {
    switch ($status) {
        'done'   { return @('Pop', 'PopText', '') }
        'partly' { return @('AccentSoft', 'Text', '') }
        'tried'  { return @('', 'TextSecondary', 'TextTertiary') }
        'no'     { return @('WarningSoft', 'Warning', '') }
        default  { return @('', 'TextTertiary', 'FieldBorder') }
    }
}

# Small black square with a lime number: a goal number, also shown on linked tasks.
function New-WeekNumber([int]$n) {
    $b = [System.Windows.Controls.Border]::new()
    $b.Width = 22; $b.Height = 22
    $b.CornerRadius = [System.Windows.CornerRadius]::new(7)
    $b.VerticalAlignment = 'Center'
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'TileBg')
    $t = New-WeekText ([string]$n) 12 'TileFg' 'Bold'
    $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
    $b.Child = $t
    return $b
}

# An 'Add a goal / Add a task' text box with a hint; Enter adds the item.
function New-WeekAddBox([string]$hint, [string]$kind) {
    $field = [System.Windows.Controls.Border]::new()
    $field.Style = $script:app.FindResource('FieldStyle')
    $field.Margin = [System.Windows.Thickness]::new(0, 8, 0, 4)
    $grid = [System.Windows.Controls.Grid]::new()
    $box = [System.Windows.Controls.TextBox]::new()
    $box.Style = $script:app.FindResource('PlainTextBox')
    $box.FontSize = 14
    $box.Tag = $kind
    $placeholder = New-WeekText ($hint + '   ' + [char]0x00B7 + '   press Enter') 14 'TextTertiary'
    $placeholder.IsHitTestVisible = $false
    $placeholder.Margin = [System.Windows.Thickness]::new(2, 0, 0, 0)
    $grid.Children.Add($box) | Out-Null
    $grid.Children.Add($placeholder) | Out-Null
    $box.Add_TextChanged({ param($s, $e) $s.Parent.Children[1].Visibility = if ($s.Text) { 'Collapsed' } else { 'Visible' } })
    $box.Add_KeyDown({
        param($s, $e)
        if ($e.Key -ne 'Return') { return }
        $e.Handled = $true
        $text = $s.Text.Trim()
        if (-not $text) { return }
        Add-WeekItem ([string]$s.Tag) $text
    })
    $field.Child = $grid
    if ($script:weekFocus -eq $kind) { $script:weekFocusBox = $box }
    return $field
}

# Adds a goal, a task (to the selected day) or a word for the week, then redraws.
function Add-WeekItem([string]$kind, [string]$text) {
    $week = Get-WeekData $script:weekStart $true
    switch ($kind) {
        'goal' { $week.goals.Add(@{ id = (New-WeekId); text = $text; tag = ''; status = '' }) }
        'task' { $day = Get-WeekDay $week $script:weekDay; $day.tasks.Add(@{ id = (New-WeekId); text = $text; status = ''; goal = $null }) }
        'word' { $week.words.Add($text) }
    }
    $script:weekFocus = $kind
    Save-Week $week
    Update-WeekPage
}

# Simple input box used to rename goals, tasks and words.
function Read-WeekText([string]$prompt, [string]$value) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($prompt, 'Selah', $value)
}

# Builds one context-menu item that carries its data in Tag.
function New-WeekMenuItem([string]$header, $tag, [scriptblock]$onClick, [bool]$checked = $false) {
    $m = [System.Windows.Controls.MenuItem]::new()
    $m.Header = $header
    $m.Tag = $tag
    $m.IsChecked = $checked
    $m.Add_Click($onClick)
    return $m
}

# ------------------------------------------------------------------ actions
# Moves a goal to its next status and redraws.
function Set-WeekGoalStatus($goal) { $goal.status = Get-NextWeekStatus ([string]$goal.status); Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage }

# Moves a task to its next status and redraws.
function Set-WeekTaskStatus($task) { $task.status = Get-NextWeekStatus ([string]$task.status); Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage }

# Menu for a goal: rename, tag (Work, Faith, ...) or delete. Deleting renumbers task links.
function Show-WeekGoalMenu($target) {
    $week = Get-WeekData $script:weekStart $true
    $goal = $target.Tag
    $menu = [System.Windows.Controls.ContextMenu]::new()
    $menu.Items.Add((New-WeekMenuItem 'Rename...' $goal {
        param($s, $e)
        $g = $s.Tag
        $v = Read-WeekText 'Weekly goal' ([string]$g.text)
        if ($v.Trim()) { $g.text = $v.Trim(); Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage }
    })) | Out-Null
    $tagMenu = [System.Windows.Controls.MenuItem]::new(); $tagMenu.Header = 'Tag'
    foreach ($t in @('') + $script:weekTags) {
        $label = if ($t) { $t } else { 'None' }
        $tagMenu.Items.Add((New-WeekMenuItem $label @($goal, $t) {
            param($s, $e)
            $s.Tag[0].tag = [string]$s.Tag[1]; Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage
        } ([string]$goal.tag -eq $t))) | Out-Null
    }
    $menu.Items.Add($tagMenu) | Out-Null
    $menu.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
    $menu.Items.Add((New-WeekMenuItem 'Delete goal' $goal {
        param($s, $e)
        $wk = Get-WeekData $script:weekStart $true
        $index = $wk.goals.IndexOf($s.Tag) + 1
        $wk.goals.Remove($s.Tag) | Out-Null
        # Keep task links pointing at the right goal numbers.
        foreach ($k in @($wk.days.Keys)) {
            Initialize-WeekList $wk.days[$k] 'tasks'
            foreach ($t in $wk.days[$k].tasks) {
                if ([int]$t.goal -eq $index) { $t.goal = $null } elseif ([int]$t.goal -gt $index) { $t.goal = [int]$t.goal - 1 }
            }
        }
        Save-Week $wk; Update-WeekPage
    })) | Out-Null
    $target.ContextMenu = $menu
    $menu.PlacementTarget = $target
    $menu.IsOpen = $true
}

# Menu for a task: rename, link to a goal number, repeat (just today, weekdays, every day)
# or delete.
function Show-WeekTaskMenu($target) {
    $week = Get-WeekData $script:weekStart $true
    $task = $target.Tag
    $habit = if ($task.habit) { @($script:habits | Where-Object { $_.id -eq $task.habit } | Select-Object -First 1) } else { @() }
    $repeat = if ($habit.Count) { [string]$habit[0].repeat } else { '' }
    $menu = [System.Windows.Controls.ContextMenu]::new()
    $menu.Items.Add((New-WeekMenuItem 'Rename...' $task {
        param($s, $e)
        $t = $s.Tag
        $v = Read-WeekText 'Task' ([string]$t.text)
        if ($v.Trim()) {
            $t.text = $v.Trim()
            if ($t.habit) { foreach ($h in $script:habits) { if ($h.id -eq $t.habit) { $h.text = $t.text } } }
            Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage
        }
    })) | Out-Null
    if ($week.goals.Count) {
        $goalMenu = [System.Windows.Controls.MenuItem]::new(); $goalMenu.Header = 'Counts toward goal'
        $goalMenu.Items.Add((New-WeekMenuItem 'None' @($task, 0) { param($s, $e) $s.Tag[0].goal = $null; Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage } (-not $task.goal))) | Out-Null
        for ($i = 0; $i -lt $week.goals.Count; $i++) {
            $header = ('{0}. {1}' -f ($i + 1), $week.goals[$i].text)
            $goalMenu.Items.Add((New-WeekMenuItem $header @($task, ($i + 1)) { param($s, $e) $s.Tag[0].goal = [int]$s.Tag[1]; Save-Week (Get-WeekData $script:weekStart $true); Update-WeekPage } ([int]$task.goal -eq ($i + 1)))) | Out-Null
        }
        $menu.Items.Add($goalMenu) | Out-Null
    }
    $repeatMenu = [System.Windows.Controls.MenuItem]::new(); $repeatMenu.Header = 'Repeat'
    foreach ($option in @(@('', 'Just today'), @('weekdays', 'Weekdays'), @('daily', 'Every day'))) {
        $repeatMenu.Items.Add((New-WeekMenuItem $option[1] @($task, $option[0]) { param($s, $e) Set-WeekTaskRepeat $s.Tag[0] ([string]$s.Tag[1]) } ($repeat -eq $option[0]))) | Out-Null
    }
    $menu.Items.Add($repeatMenu) | Out-Null
    $menu.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
    $menu.Items.Add((New-WeekMenuItem 'Delete task' $task {
        param($s, $e)
        $wk = Get-WeekData $script:weekStart $true
        (Get-WeekDay $wk $script:weekDay).tasks.Remove($s.Tag) | Out-Null
        Save-Week $wk; Update-WeekPage
    })) | Out-Null
    $target.ContextMenu = $menu
    $menu.PlacementTarget = $target
    $menu.IsOpen = $true
}

# Turns a task into a habit (or back). Habits appear by themselves on the days ahead.
function Set-WeekTaskRepeat($task, [string]$repeat) {
    $week = Get-WeekData $script:weekStart $true
    $habit = $null
    if ($task.habit) { $habit = @($script:habits | Where-Object { $_.id -eq $task.habit } | Select-Object -First 1)[0] }
    if ($repeat) {
        if ($null -ne $habit) { $habit.repeat = $repeat; $habit.text = $task.text; $habit.goal = $task.goal }
        else {
            $habit = @{ id = (New-WeekId); text = $task.text; repeat = $repeat; goal = $task.goal }
            $script:habits.Add($habit)
            $task.habit = $habit.id
        }
        # Add it to the days ahead in this week that are already open.
        foreach ($k in @($week.days.Keys)) {
            if ($k -le $script:weekDay) { continue }
            Initialize-WeekList $week.days[$k] 'tasks'
            $tasks = $week.days[$k].tasks
            if ((Test-HabitApplies $habit $k) -and -not @($tasks | Where-Object { $_.habit -eq $habit.id }).Count) {
                $tasks.Add(@{ id = (New-WeekId); text = $habit.text; status = ''; goal = $habit.goal; habit = $habit.id })
            }
        }
    } elseif ($null -ne $habit) {
        $script:habits.Remove($habit) | Out-Null
        $task.Remove('habit')
    }
    Save-Week $week
    Update-WeekPage
}

# Sunday review: copies goals that are still open into next week and marks them moved.
function Move-WeekOpenGoals {
    $week = Get-WeekData $script:weekStart $true
    $nextIso = ConvertTo-IsoDay ((ConvertFrom-IsoDay $script:weekStart).AddDays(7))
    $next = Get-WeekData $nextIso $true
    $open = @($week.goals | Where-Object { (Test-WeekStatusOpen ([string]$_.status)) -and -not $_.moved })
    foreach ($g in $open) {
        if (-not @($next.goals | Where-Object { $_.text -eq $g.text }).Count) { $next.goals.Add(@{ id = (New-WeekId); text = $g.text; tag = [string]$g.tag; status = '' }) }
        $g.moved = $true
    }
    $next.updatedAt = (Get-Date).ToString('o')
    Save-Week $week
    Update-WeekPage
}

# ------------------------------------------------------------------ the page
# Draws the whole Week page from the data: header and week arrows, words for the week,
# weekly goals, Mon-Sun day strip, the selected day's tasks, the carry-over banner and,
# on Sunday or for past weeks, the review card. The page is rebuilt after every change.
function Update-WeekPage {
    if (-not $script:ui.ContainsKey('WeekContent')) { return }
    $script:weekRendering = $true
    $script:weekFocusBox = $null
    try {
        $todayIso = ConvertTo-IsoDay (Get-Date)
        if (-not $script:weekStart) { $script:weekStart = ConvertTo-IsoDay (Get-WeekMonday (Get-Date)) }
        $start = ConvertFrom-IsoDay $script:weekStart
        $end = $start.AddDays(6)
        $endIso = ConvertTo-IsoDay $end
        if (-not $script:weekDay -or $script:weekDay -lt $script:weekStart -or $script:weekDay -gt $endIso) {
            $script:weekDay = if ($todayIso -ge $script:weekStart -and $todayIso -le $endIso) { $todayIso } else { $script:weekStart }
        }
        $week = Get-WeekData $script:weekStart $true
        $panel = $script:ui.WeekContent
        $panel.Children.Clear()

        # Header with previous / next week
        $head = [System.Windows.Controls.DockPanel]::new()
        $head.LastChildFill = $true
        $nextButton = [System.Windows.Controls.Button]::new(); $nextButton.Style = $script:app.FindResource('GhostButton'); $nextButton.Content = 'Next ' + [char]0x203A; $nextButton.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $nextButton.Add_Click({ $script:weekStart = ConvertTo-IsoDay ((ConvertFrom-IsoDay $script:weekStart).AddDays(7)); $script:weekDay = ''; Update-WeekPage })
        [System.Windows.Controls.DockPanel]::SetDock($nextButton, 'Right'); $head.Children.Add($nextButton) | Out-Null
        $isThisWeek = $script:weekStart -eq (ConvertTo-IsoDay (Get-WeekMonday (Get-Date)))
        if (-not $isThisWeek) {
            $thisButton = [System.Windows.Controls.Button]::new(); $thisButton.Style = $script:app.FindResource('GhostButton'); $thisButton.Content = 'This week'; $thisButton.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            $thisButton.Add_Click({ $script:weekStart = ''; $script:weekDay = ''; Update-WeekPage })
            [System.Windows.Controls.DockPanel]::SetDock($thisButton, 'Right'); $head.Children.Add($thisButton) | Out-Null
        }
        $prevButton = [System.Windows.Controls.Button]::new(); $prevButton.Style = $script:app.FindResource('GhostButton'); $prevButton.Content = [string][char]0x2039 + ' Previous'
        $prevButton.Add_Click({ $script:weekStart = ConvertTo-IsoDay ((ConvertFrom-IsoDay $script:weekStart).AddDays(-7)); $script:weekDay = ''; Update-WeekPage })
        [System.Windows.Controls.DockPanel]::SetDock($prevButton, 'Right'); $head.Children.Add($prevButton) | Out-Null
        $titles = [System.Windows.Controls.StackPanel]::new()
        $title = New-WeekText ('Week ' + (Get-WeekNumber $start)) 30 'Text' 'SemiBold'
        $title.FontFamily = $script:app.FindResource('DisplayFont')
        $titles.Children.Add($title) | Out-Null
        $sub = $start.ToString('d MMM') + ' ' + [char]0x2013 + ' ' + $end.ToString('d MMM yyyy')
        if ($isThisWeek) { $sub += '   ' + [char]0x00B7 + '   this week' }
        $titles.Children.Add((New-WeekText $sub 14 'TextSecondary')) | Out-Null
        $head.Children.Add($titles) | Out-Null
        $panel.Children.Add($head) | Out-Null

        $columns = [System.Windows.Controls.Grid]::new()
        $columns.Margin = [System.Windows.Thickness]::new(0, 16, 0, 0)
        $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(380)
        $c2 = [System.Windows.Controls.ColumnDefinition]::new(); $c2.Width = [System.Windows.GridLength]::new(20)
        $columns.ColumnDefinitions.Add($c1); $columns.ColumnDefinitions.Add($c2); $columns.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
        $left = [System.Windows.Controls.StackPanel]::new()
        $right = [System.Windows.Controls.StackPanel]::new()
        [System.Windows.Controls.Grid]::SetColumn($right, 2)
        $columns.Children.Add($left) | Out-Null
        $columns.Children.Add($right) | Out-Null
        $panel.Children.Add($columns) | Out-Null

        # Words for the week
        $hero = [System.Windows.Controls.Border]::new()
        $hero.CornerRadius = [System.Windows.CornerRadius]::new(16)
        $hero.Padding = [System.Windows.Thickness]::new(18, 16, 18, 14)
        $hero.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'HeroBrush')
        $heroStack = [System.Windows.Controls.StackPanel]::new()
        $heroStack.Children.Add((New-WeekText 'WORDS FOR THIS WEEK' 11.5 'HeroCaption' 'Bold')) | Out-Null
        $wrap = [System.Windows.Controls.WrapPanel]::new()
        $wrap.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
        foreach ($word in $week.words) {
            $chip = [System.Windows.Controls.Button]::new()
            $chip.Style = $script:app.FindResource('HeroButton')
            $chip.Content = [string]$word
            $chip.Tag = [string]$word
            $chip.Margin = [System.Windows.Thickness]::new(0, 0, 6, 6)
            $chip.ToolTip = 'Click to edit or remove'
            $chip.Add_Click({
                param($s, $e)
                $wk = Get-WeekData $script:weekStart $true
                $index = $wk.words.IndexOf($s.Tag)
                $v = Read-WeekText 'Word for this week (clear it to remove)' ([string]$s.Tag)
                if ($index -lt 0) { return }
                if ($v.Trim()) { $wk.words[$index] = $v.Trim() } else { $wk.words.RemoveAt($index) }
                Save-Week $wk; Update-WeekPage
            })
            $wrap.Children.Add($chip) | Out-Null
        }
        $addWord = [System.Windows.Controls.Button]::new()
        $addWord.Style = $script:app.FindResource('HeroButton')
        $addWord.Content = '+ word'
        $addWord.Margin = [System.Windows.Thickness]::new(0, 0, 6, 6)
        $addWord.Add_Click({ $v = Read-WeekText 'A word or phrase for this week, for example "Do hard things"' ''; if ($v.Trim()) { Add-WeekItem 'word' $v.Trim() } })
        $wrap.Children.Add($addWord) | Out-Null
        $heroStack.Children.Add($wrap) | Out-Null
        $hero.Child = $heroStack
        $left.Children.Add($hero) | Out-Null

        # Weekly goals
        $stats = Get-WeekStats $week
        $goalCaption = 'Weekly goals'
        if ($week.goals.Count) { $goalCaption += ('   ' + [char]0x00B7 + '   {0} of {1} done' -f $stats.goalsDone, $week.goals.Count) }
        $left.Children.Add((New-WeekCaption $goalCaption)) | Out-Null
        $goalCard = [System.Windows.Controls.Border]::new()
        $goalCard.Style = $script:app.FindResource('CardStyle')
        $goalCard.Padding = [System.Windows.Thickness]::new(16, 8, 16, 10)
        $goalStack = [System.Windows.Controls.StackPanel]::new()
        for ($i = 0; $i -lt $week.goals.Count; $i++) {
            $goal = $week.goals[$i]
            $row = [System.Windows.Controls.DockPanel]::new()
            $row.Margin = [System.Windows.Thickness]::new(0, 5, 0, 5)
            $number = New-WeekNumber ($i + 1)
            [System.Windows.Controls.DockPanel]::SetDock($number, 'Left'); $row.Children.Add($number) | Out-Null
            $look = Get-WeekStatusLook ([string]$goal.status)
            $pill = New-WeekPill $script:weekStatusLabel[[string]$goal.status] $look[0] $look[1] $look[2] $goal { param($s, $e) Set-WeekGoalStatus $s.Tag } 'Click to change: Done, Partly, Tried, not done, open'
            [System.Windows.Controls.DockPanel]::SetDock($pill, 'Right'); $row.Children.Add($pill) | Out-Null
            $textStack = [System.Windows.Controls.StackPanel]::new()
            $textStack.Margin = [System.Windows.Thickness]::new(10, 0, 8, 0)
            $textStack.Cursor = [System.Windows.Input.Cursors]::Hand
            $textStack.Background = [System.Windows.Media.Brushes]::Transparent
            $textStack.Tag = $goal
            $textStack.ToolTip = 'Click to rename, tag or delete'
            $line = New-WeekText ([string]$goal.text) 14.5 $(if ($goal.status -eq 'done') { 'TextTertiary' } else { 'Text' }) 'SemiBold'
            if ($goal.status -eq 'done') { $line.TextDecorations = [System.Windows.TextDecorations]::Strikethrough }
            $textStack.Children.Add($line) | Out-Null
            $metaParts = @()
            if ($goal.tag) { $metaParts += ([string]$goal.tag).ToUpperInvariant() }
            if ($goal.moved) { $metaParts += 'moved to next week' }
            if ($metaParts.Count) { $textStack.Children.Add((New-WeekText ($metaParts -join ('   ' + [char]0x00B7 + '   ')) 11 'TextTertiary' 'SemiBold')) | Out-Null }
            $textStack.Add_MouseLeftButtonUp({ param($s, $e) Show-WeekGoalMenu $s })
            $row.Children.Add($textStack) | Out-Null
            $goalStack.Children.Add($row) | Out-Null
        }
        $goalStack.Children.Add((New-WeekAddBox 'Add a weekly goal' 'goal')) | Out-Null
        $goalCard.Child = $goalStack
        $left.Children.Add($goalCard) | Out-Null

        # Day strip
        $strip = [System.Windows.Controls.Primitives.UniformGrid]::new()
        $strip.Columns = 7
        for ($i = 0; $i -lt 7; $i++) {
            $d = $start.AddDays($i)
            $iso = ConvertTo-IsoDay $d
            $cell = [System.Windows.Controls.Border]::new()
            $cell.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $cell.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
            $cell.Padding = [System.Windows.Thickness]::new(0, 8, 0, 7)
            $cell.Cursor = [System.Windows.Input.Cursors]::Hand
            $cell.BorderThickness = [System.Windows.Thickness]::new(1)
            $selected = $iso -eq $script:weekDay
            $cell.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($selected) { 'Text' } else { 'Card' }))
            $cell.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $(if ($iso -eq $todayIso -or $selected) { 'Text' } else { 'CardBorder' }))
            $cellStack = [System.Windows.Controls.StackPanel]::new()
            $dayLabel = New-WeekText $script:weekDayNames[$i].Substring(0, 3).ToUpperInvariant() 11 $(if ($selected) { 'Pop' } else { 'TextSecondary' }) 'Bold'
            $dayLabel.HorizontalAlignment = 'Center'
            $num = New-WeekText ([string]$d.Day) 18 $(if ($selected) { 'DialogBg' } else { 'Text' }) 'Bold'
            $num.HorizontalAlignment = 'Center'
            $pips = [System.Windows.Controls.StackPanel]::new(); $pips.Orientation = 'Horizontal'; $pips.HorizontalAlignment = 'Center'; $pips.Height = 7; $pips.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
            if ($week.days[$iso] -is [hashtable]) {
                Initialize-WeekList $week.days[$iso] 'tasks'
                foreach ($t in @($week.days[$iso].tasks | Where-Object { -not $_.carried } | Select-Object -First 6)) {
                    $dot = [System.Windows.Shapes.Ellipse]::new(); $dot.Width = 5; $dot.Height = 5; $dot.Margin = [System.Windows.Thickness]::new(1, 0, 1, 0)
                    $dot.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, $(if ($t.status -eq 'done') { $(if ($selected) { 'Pop' } else { 'Success' }) } else { 'FieldBorder' }))
                    $pips.Children.Add($dot) | Out-Null
                }
            }
            $cellStack.Children.Add($dayLabel) | Out-Null
            $cellStack.Children.Add($num) | Out-Null
            $cellStack.Children.Add($pips) | Out-Null
            $cell.Child = $cellStack
            $cell.Tag = $iso
            $cell.Add_MouseLeftButtonUp({ param($s, $e) $script:weekDay = [string]$s.Tag; Update-WeekPage })
            $strip.Children.Add($cell) | Out-Null
        }
        $right.Children.Add($strip) | Out-Null

        # Selected day
        $dayDate = ConvertFrom-IsoDay $script:weekDay
        $day = Get-WeekDay $week $script:weekDay
        $tasks = $day.tasks
        $visible = @($tasks | Where-Object { -not $_.carried })
        $doneCount = @($visible | Where-Object { $_.status -eq 'done' }).Count
        $dayHead = [System.Windows.Controls.DockPanel]::new()
        $dayHead.Margin = [System.Windows.Thickness]::new(2, 20, 2, 8)
        $count = New-WeekText $(if ($visible.Count) { "$doneCount of $($visible.Count) done" } else { 'No tasks yet' }) 13 'TextSecondary'
        [System.Windows.Controls.DockPanel]::SetDock($count, 'Right'); $count.VerticalAlignment = 'Bottom'
        $dayHead.Children.Add($count) | Out-Null
        $dayTitle = $script:weekDayNames[([int]$dayDate.DayOfWeek + 6) % 7] + ' ' + $dayDate.Day
        if ($script:weekDay -eq $todayIso) { $dayTitle += '   ' + [char]0x00B7 + '   today' }
        $dayHead.Children.Add((New-WeekText $dayTitle 20 'Text' 'Bold')) | Out-Null
        $right.Children.Add($dayHead) | Out-Null

        $carry = Get-CarryCandidates $script:weekDay
        if ($carry.tasks.Count -and [string]$day.carryDismissed -ne $carry.iso) {
            $banner = [System.Windows.Controls.Border]::new()
            $banner.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $banner.Padding = [System.Windows.Thickness]::new(14, 10, 10, 10)
            $banner.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
            $banner.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Pop')
            $bannerDock = [System.Windows.Controls.DockPanel]::new()
            $dismiss = [System.Windows.Controls.Button]::new(); $dismiss.Style = $script:app.FindResource('SubtleButton'); $dismiss.Content = 'Not now'; $dismiss.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
            $dismiss.Foreground = $script:app.FindResource('PopText')
            $dismiss.Tag = $carry.iso
            $dismiss.Add_Click({ param($s, $e) $wk = Get-WeekData $script:weekStart $true; (Get-WeekDay $wk $script:weekDay).carryDismissed = [string]$s.Tag; Save-Week $wk; Update-WeekPage })
            [System.Windows.Controls.DockPanel]::SetDock($dismiss, 'Right'); $bannerDock.Children.Add($dismiss) | Out-Null
            $bring = [System.Windows.Controls.Button]::new(); $bring.Style = $script:app.FindResource('PrimaryButton'); $bring.Content = 'Bring over'
            $bring.Add_Click({
                $wk = Get-WeekData $script:weekStart $true
                $target = (Get-WeekDay $wk $script:weekDay).tasks
                $c = Get-CarryCandidates $script:weekDay
                foreach ($t in $c.tasks) { $target.Add(@{ id = (New-WeekId); text = $t.text; status = ''; goal = $t.goal; from = $c.iso }); $t.carried = $true }
                if ($null -ne $c.week) { $c.week.updatedAt = (Get-Date).ToString('o') }
                Save-Week $wk; Update-WeekPage
            })
            [System.Windows.Controls.DockPanel]::SetDock($bring, 'Right'); $bannerDock.Children.Add($bring) | Out-Null
            $bannerText = [System.Windows.Controls.StackPanel]::new()
            $bannerText.VerticalAlignment = 'Center'
            $prevName = $script:weekDayNames[([int](ConvertFrom-IsoDay $carry.iso).DayOfWeek + 6) % 7]
            $bannerText.Children.Add((New-WeekText ("$($carry.tasks.Count) not finished on $prevName") 14 'PopText' 'Bold')) | Out-Null
            $bannerText.Children.Add((New-WeekText ((@($carry.tasks | ForEach-Object { [char]0x201C + $_.text + [char]0x201D })) -join ', ') 12.5 'PopText')) | Out-Null
            $bannerDock.Children.Add($bannerText) | Out-Null
            $banner.Child = $bannerDock
            $right.Children.Add($banner) | Out-Null
        }

        $taskCard = [System.Windows.Controls.Border]::new()
        $taskCard.Style = $script:app.FindResource('CardStyle')
        $taskCard.Padding = [System.Windows.Thickness]::new(16, 8, 16, 10)
        $taskStack = [System.Windows.Controls.StackPanel]::new()
        foreach ($task in $visible) {
            $row = [System.Windows.Controls.DockPanel]::new()
            $row.Margin = [System.Windows.Thickness]::new(0, 5, 0, 5)
            $status = [string]$task.status
            $box = [System.Windows.Controls.Border]::new()
            $box.Width = 26; $box.Height = 26
            $box.CornerRadius = [System.Windows.CornerRadius]::new(8)
            $box.BorderThickness = [System.Windows.Thickness]::new(2)
            $box.Cursor = [System.Windows.Input.Cursors]::Hand
            $box.VerticalAlignment = 'Center'
            $look = Get-WeekStatusLook $status
            if ($look[0]) { $box.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $look[0]); $box.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $look[0]) }
            else { $box.Background = [System.Windows.Media.Brushes]::Transparent; $box.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $(if ($look[2]) { $look[2] } else { 'FieldBorder' })) }
            $mark = New-WeekText $script:weekBoxMark[$status] 13 $look[1] 'Bold'
            $mark.HorizontalAlignment = 'Center'; $mark.VerticalAlignment = 'Center'
            $box.Child = $mark
            $box.Tag = $task
            $box.ToolTip = 'Click: Done ' + [char]0x2192 + ' Partly ' + [char]0x2192 + ' Tried ' + [char]0x2192 + ' did not happen ' + [char]0x2192 + ' open'
            $box.Add_MouseLeftButtonUp({ param($s, $e) Set-WeekTaskStatus $s.Tag })
            [System.Windows.Controls.DockPanel]::SetDock($box, 'Left'); $row.Children.Add($box) | Out-Null
            if ($task.goal -and [int]$task.goal -le $week.goals.Count) {
                $goalNumber = New-WeekNumber ([int]$task.goal)
                $goalNumber.ToolTip = $week.goals[[int]$task.goal - 1].text
                [System.Windows.Controls.DockPanel]::SetDock($goalNumber, 'Right'); $row.Children.Add($goalNumber) | Out-Null
            }
            $textStack = [System.Windows.Controls.StackPanel]::new()
            $textStack.Margin = [System.Windows.Thickness]::new(12, 0, 8, 0)
            $textStack.Cursor = [System.Windows.Input.Cursors]::Hand
            $textStack.Background = [System.Windows.Media.Brushes]::Transparent
            $textStack.Tag = $task
            $textStack.ToolTip = 'Click to rename, link to a goal, repeat or delete'
            $line = New-WeekText ([string]$task.text) 14.5 $(if ($status -eq 'done') { 'TextTertiary' } else { 'Text' }) 'SemiBold'
            if ($status -eq 'done') { $line.TextDecorations = [System.Windows.TextDecorations]::Strikethrough }
            $textStack.Children.Add($line) | Out-Null
            $meta = @()
            if ($task.habit) {
                $h = @($script:habits | Where-Object { $_.id -eq $task.habit } | Select-Object -First 1)
                $meta += ([string][char]0x21BB + ' ' + $(if ($h.Count -and $h[0].repeat -eq 'weekdays') { 'weekdays' } else { 'every day' }))
            }
            if ($task.from) { $meta += ('from ' + $script:weekDayNames[([int](ConvertFrom-IsoDay ([string]$task.from)).DayOfWeek + 6) % 7].Substring(0, 3)) }
            if ($status -and $status -ne 'done') { $meta += $(if ($status -eq 'no') { 'Did not happen' } else { $script:weekStatusLabel[$status] }) }
            if ($meta.Count) { $textStack.Children.Add((New-WeekText ($meta -join ('   ' + [char]0x00B7 + '   ')) 11.5 'TextTertiary')) | Out-Null }
            $textStack.Add_MouseLeftButtonUp({ param($s, $e) Show-WeekTaskMenu $s })
            $row.Children.Add($textStack) | Out-Null
            $taskStack.Children.Add($row) | Out-Null
        }
        $taskStack.Children.Add((New-WeekAddBox 'Add a task' 'task')) | Out-Null
        $taskCard.Child = $taskStack
        $right.Children.Add($taskCard) | Out-Null

        # Review on Sunday, or for any past week
        if ($dayDate.DayOfWeek -eq 'Sunday' -or $endIso -lt $todayIso) {
            $right.Children.Add((New-WeekCaption ('Week ' + (Get-WeekNumber $start) + ' review'))) | Out-Null
            $review = [System.Windows.Controls.Border]::new()
            $review.Style = $script:app.FindResource('CardStyle')
            $review.Padding = [System.Windows.Thickness]::new(16)
            $reviewStack = [System.Windows.Controls.StackPanel]::new()
            $statGrid = [System.Windows.Controls.Primitives.UniformGrid]::new(); $statGrid.Columns = 3
            foreach ($pair in @(@("$($stats.goalsDone)/$($stats.goals)", 'weekly goals'), @("$($stats.done)/$($stats.total)", 'daily tasks'), @([string]$stats.active, 'days with progress'))) {
                $cellBorder = [System.Windows.Controls.Border]::new()
                $cellBorder.CornerRadius = [System.Windows.CornerRadius]::new(12)
                $cellBorder.Padding = [System.Windows.Thickness]::new(12, 10, 12, 10)
                $cellBorder.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
                $cellBorder.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'CardAlt')
                $cs = [System.Windows.Controls.StackPanel]::new()
                $cs.Children.Add((New-WeekText $pair[0] 24 'Text' 'Bold')) | Out-Null
                $cs.Children.Add((New-WeekText $pair[1] 12 'TextSecondary')) | Out-Null
                $cellBorder.Child = $cs
                $statGrid.Children.Add($cellBorder) | Out-Null
            }
            $reviewStack.Children.Add($statGrid) | Out-Null
            $open = @($week.goals | Where-Object { (Test-WeekStatusOpen ([string]$_.status)) -and -not $_.moved })
            if ($open.Count) {
                $still = New-WeekText 'Still open' 14 'Text' 'Bold'; $still.Margin = [System.Windows.Thickness]::new(0, 14, 0, 2)
                $reviewStack.Children.Add($still) | Out-Null
                $reviewStack.Children.Add((New-WeekText ((@($open | ForEach-Object { $_.text })) -join ('   ' + [char]0x00B7 + '   ')) 13 'TextSecondary')) | Out-Null
                $buttons = [System.Windows.Controls.StackPanel]::new(); $buttons.Orientation = 'Horizontal'; $buttons.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
                $move = [System.Windows.Controls.Button]::new(); $move.Style = $script:app.FindResource('PrimaryButton')
                $move.Content = 'Move to week ' + (Get-WeekNumber ($start.AddDays(7)))
                $move.Add_Click({ Move-WeekOpenGoals })
                $letGo = [System.Windows.Controls.Button]::new(); $letGo.Style = $script:app.FindResource('GhostButton'); $letGo.Content = 'Let them go'; $letGo.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
                $letGo.Add_Click({
                    $wk = Get-WeekData $script:weekStart $true
                    foreach ($g in $wk.goals) { if ((Test-WeekStatusOpen ([string]$g.status)) -and -not $g.moved) { $g.status = 'no' } }
                    Save-Week $wk; Update-WeekPage
                })
                $buttons.Children.Add($move) | Out-Null
                $buttons.Children.Add($letGo) | Out-Null
                $reviewStack.Children.Add($buttons) | Out-Null
            }
            $noteField = [System.Windows.Controls.Border]::new()
            $noteField.Style = $script:app.FindResource('FieldStyle')
            $noteField.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)
            $note = [System.Windows.Controls.TextBox]::new()
            $note.Style = $script:app.FindResource('PlainTextBox')
            $note.AcceptsReturn = $true; $note.TextWrapping = 'Wrap'; $note.MinHeight = 60; $note.FontSize = 14
            $note.Text = [string]$week.review
            $note.ToolTip = 'How did this week go? One line for next Monday' + [char]0x2019 + 's you.'
            $note.Add_TextChanged({ param($s, $e) if (-not $script:weekRendering) { $wk = Get-WeekData $script:weekStart $true; $wk.review = $s.Text; Save-Week $wk } })
            $noteField.Child = $note
            $reviewStack.Children.Add((New-WeekText 'How did this week go?' 13 'TextSecondary' 'SemiBold')) | Out-Null
            $reviewStack.Children[$reviewStack.Children.Count - 1].Margin = [System.Windows.Thickness]::new(0, 14, 0, 0)
            $reviewStack.Children.Add($noteField) | Out-Null
            $review.Child = $reviewStack
            $right.Children.Add($review) | Out-Null
        }
    } finally {
        $script:weekRendering = $false
    }
    if ($null -ne $script:weekFocusBox) {
        # Put the cursor back in the box you were typing in, so you can add the next item straight away.
        $script:weekFocus = ''
        $script:weekFocusBox.Dispatcher.BeginInvoke([action]{ if ($null -ne $script:weekFocusBox) { $script:weekFocusBox.Focus() | Out-Null } }, [System.Windows.Threading.DispatcherPriority]::Input) | Out-Null
    }
}
