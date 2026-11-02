# Verse highlighting (same 12 colours as Selah for Android), the Highlights page,
# and the book list that opens to show each book's chapter numbers.

$script:highlights = [ordered]@{}
$script:highlightFilter = ''
$script:bookChapterCounts = @(50,40,27,36,34,24,21,4,31,24,22,25,29,36,10,13,10,42,150,31,12,8,66,52,5,48,12,14,3,9,1,4,7,3,3,3,2,14,4,28,16,24,21,28,16,16,13,6,6,4,4,5,3,6,4,3,1,13,5,5,3,5,1,1,1,22)
$script:highlightPalette = @(
    [pscustomobject]@{ key = 'honey';      name = 'Honey';      fill = '#FCE7A1'; strong = '#D9A400' }
    [pscustomobject]@{ key = 'apricot';    name = 'Apricot';    fill = '#FFD3B0'; strong = '#E8813A' }
    [pscustomobject]@{ key = 'coral';      name = 'Coral';      fill = '#FFC2B8'; strong = '#E5594A' }
    [pscustomobject]@{ key = 'blush';      name = 'Blush';      fill = '#FFCFE0'; strong = '#D9578C' }
    [pscustomobject]@{ key = 'orchid';     name = 'Orchid';     fill = '#F3C8F0'; strong = '#B44AAE' }
    [pscustomobject]@{ key = 'lilac';      name = 'Lilac';      fill = '#DDD0FF'; strong = '#7A5AE0' }
    [pscustomobject]@{ key = 'periwinkle'; name = 'Periwinkle'; fill = '#C9D3FF'; strong = '#4C64D9' }
    [pscustomobject]@{ key = 'sky';        name = 'Sky';        fill = '#C6E6FF'; strong = '#2490E0' }
    [pscustomobject]@{ key = 'aqua';       name = 'Aqua';       fill = '#BDF0EC'; strong = '#14A396' }
    [pscustomobject]@{ key = 'mint';       name = 'Mint';       fill = '#CDF1CF'; strong = '#3AA24C' }
    [pscustomobject]@{ key = 'sage';       name = 'Sage';       fill = '#DCE5C4'; strong = '#7E9440' }
    [pscustomobject]@{ key = 'sand';       name = 'Sand';       fill = '#EADCC8'; strong = '#A27C4E' }
)

function Get-PaletteEntry([string]$key) {
    foreach ($p in $script:highlightPalette) { if ($p.key -eq $key) { return $p } }
    return $null
}

function Get-HighlightBrush([string]$key, [bool]$strong = $false) {
    $p = Get-PaletteEntry $key
    if ($null -eq $p) { return [System.Windows.Media.Brushes]::Transparent }
    $hex = if ($strong) { $p.strong } else { $p.fill }
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    if (-not $strong -and $script:theme -eq 'Dark') {
        $s = [System.Windows.Media.ColorConverter]::ConvertFromString($p.strong)
        $color = [System.Windows.Media.Color]::FromArgb(80, $s.R, $s.G, $s.B)
    }
    $brush = [System.Windows.Media.SolidColorBrush]::new($color)
    $brush.Freeze()
    return $brush
}

function Get-Highlight([string]$key) {
    if ($script:highlights.Contains($key)) { return [string]$script:highlights[$key].color }
    return ''
}

function Set-Highlight([string]$key, [string]$color) {
    if ($color) { $script:highlights[$key] = [pscustomobject]@{ color = $color; at = (Get-Date).ToString('o') } }
    elseif ($script:highlights.Contains($key)) { $script:highlights.Remove($key) }
    Save-State
}

function Read-Highlights($raw) {
    $script:highlights = [ordered]@{}
    if ($null -eq $raw) { return }
    foreach ($prop in $raw.PSObject.Properties) {
        if ($prop.Value -and $prop.Value.color -and (Get-PaletteEntry ([string]$prop.Value.color))) { $script:highlights[$prop.Name] = $prop.Value }
    }
}

function Get-HighlightsForSave {
    $o = [ordered]@{}
    foreach ($k in $script:highlights.Keys) { $o[$k] = $script:highlights[$k] }
    return [pscustomobject]$o
}

function Paint-VerseRow($button) {
    # Shade the verse text with its highlight colour.
    $key = [string]$button.Tag
    $text = $button.Content.Children[1]
    $color = Get-Highlight $key
    if ($color) {
        $text.Background = Get-HighlightBrush $color
        $text.Padding = [System.Windows.Thickness]::new(6,1,6,2)
    } else {
        $text.Background = [System.Windows.Media.Brushes]::Transparent
        $text.Padding = [System.Windows.Thickness]::new(0)
    }
}

function Update-HighlightSwatches([string]$key) {
    $panel = $script:ui.HighlightSwatchPanel
    $panel.Children.Clear()
    if (-not $key) { $panel.Visibility = 'Collapsed'; return }
    $panel.Visibility = 'Visible'
    $current = Get-Highlight $key
    foreach ($p in $script:highlightPalette) {
        $b = [System.Windows.Controls.Button]::new()
        $b.Style = $script:app.FindResource('SwatchButton')
        $b.Background = Get-HighlightBrush $p.key
        $b.BorderBrush = Get-HighlightBrush $p.key $true
        $b.ToolTip = $p.name
        $b.Tag = if ($current -eq $p.key) { 'Selected' } else { $null }
        $b.DataContext = $p.key
        $b.Add_Click({
            $chosen = [string]$this.DataContext
            $newColor = if ((Get-Highlight $script:bibleVerseKey) -eq $chosen) { '' } else { $chosen }
            Set-Highlight $script:bibleVerseKey $newColor
            Update-HighlightSwatches $script:bibleVerseKey
            foreach ($row in $script:ui.BibleVersesPanel.Children) { if ([string]$row.Tag -eq $script:bibleVerseKey) { Paint-VerseRow $row } }
            $script:ui.BibleNoteSavedLabel.Text = if ($newColor) { "Highlighted $((Get-PaletteEntry $newColor).name) ✓" } else { 'Highlight removed' }
        })
        $panel.Children.Add($b) | Out-Null
    }
    $clear = [System.Windows.Controls.Button]::new()
    $clear.Style = $script:app.FindResource('SubtleButton')
    $clear.Content = 'Clear'
    $clear.Padding = [System.Windows.Thickness]::new(6,2,6,2)
    $clear.VerticalAlignment = 'Top'
    $clear.Margin = [System.Windows.Thickness]::new(0,0,0,8)
    $clear.IsEnabled = [bool]$current
    $clear.Add_Click({
        Set-Highlight $script:bibleVerseKey ''
        Update-HighlightSwatches $script:bibleVerseKey
        foreach ($row in $script:ui.BibleVersesPanel.Children) { if ([string]$row.Tag -eq $script:bibleVerseKey) { Paint-VerseRow $row } }
        $script:ui.BibleNoteSavedLabel.Text = 'Highlight removed'
    })
    $panel.Children.Add($clear) | Out-Null
}

function Update-HighlightsPage {
    $filters = $script:ui.HighlightFilterPanel
    $list = $script:ui.HighlightListPanel
    $filters.Children.Clear()
    $list.Children.Clear()
    $keys = @($script:highlights.Keys | Sort-Object { [string]$script:highlights[$_].at } -Descending)
    $counts = @{}
    foreach ($k in $keys) { $c = [string]$script:highlights[$k].color; $counts[$c] = 1 + [int]$counts[$c] }
    $all = [System.Windows.Controls.Button]::new()
    $all.Style = $script:app.FindResource('TabButton')
    $all.Content = "All  ·  $($keys.Count)"
    $all.Tag = if (-not $script:highlightFilter) { 'Selected' } else { $null }
    $all.Margin = [System.Windows.Thickness]::new(0,0,6,6)
    $all.Add_Click({ $script:highlightFilter = ''; Update-HighlightsPage })
    $filters.Children.Add($all) | Out-Null
    foreach ($p in $script:highlightPalette) {
        if (-not $counts[$p.key]) { continue }
        $chip = [System.Windows.Controls.Button]::new()
        $chip.Style = $script:app.FindResource('RefChip')
        $chip.Background = if ($script:highlightFilter -eq $p.key) { Get-HighlightBrush $p.key $true } else { Get-HighlightBrush $p.key }
        if ($script:highlightFilter -eq $p.key) { $chip.Foreground = [System.Windows.Media.Brushes]::White } else { $chip.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, 'Text') }
        $chip.Content = "$($p.name)  ·  $($counts[$p.key])"
        $chip.Padding = [System.Windows.Thickness]::new(4)
        $chip.Margin = [System.Windows.Thickness]::new(0,4,6,6)
        $chip.DataContext = $p.key
        $chip.Add_Click({ $script:highlightFilter = [string]$this.DataContext; Update-HighlightsPage })
        $filters.Children.Add($chip) | Out-Null
    }
    if (-not $keys.Count) {
        $empty = [System.Windows.Controls.TextBlock]::new()
        $empty.Text = 'No highlights yet. In the Bible, click any verse and pick a colour.'
        $empty.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $empty.Margin = [System.Windows.Thickness]::new(4,16,0,0)
        $list.Children.Add($empty) | Out-Null
        return
    }
    foreach ($k in $keys) {
        $color = [string]$script:highlights[$k].color
        if ($script:highlightFilter -and $color -ne $script:highlightFilter) { continue }
        $parts = $k -split '\|'
        if ($parts.Count -ne 3) { continue }
        $chapterData = Get-BibleChapter $parts[0] ([int]$parts[1])
        $verseText = ''
        if ($null -ne $chapterData) { $hit = @($chapterData.verses | Where-Object { $_.verse -eq $parts[2] }); if ($hit.Count) { $verseText = [string]$hit[0].text } }
        $card = [System.Windows.Controls.Button]::new()
        $card.Style = $script:app.FindResource('TileButton')
        $card.Margin = [System.Windows.Thickness]::new(0,0,0,10)
        $card.Tag = $k
        $grid = [System.Windows.Controls.DockPanel]::new()
        $bar = [System.Windows.Controls.Border]::new()
        $bar.Width = 5
        $bar.CornerRadius = [System.Windows.CornerRadius]::new(3)
        $bar.Background = Get-HighlightBrush $color $true
        $bar.Margin = [System.Windows.Thickness]::new(0,0,14,0)
        [System.Windows.Controls.DockPanel]::SetDock($bar, 'Left')
        $grid.Children.Add($bar) | Out-Null
        $stack = [System.Windows.Controls.StackPanel]::new()
        $ref = [System.Windows.Controls.TextBlock]::new()
        $ref.Text = "$(Get-DisplayBookName $parts[0]) $($parts[1]):$($parts[2])   ·   $((Get-PaletteEntry $color).name)"
        $ref.FontWeight = [System.Windows.FontWeights]::SemiBold
        $ref.FontSize = 15
        $body = [System.Windows.Controls.TextBlock]::new()
        $body.Text = $verseText
        $body.TextWrapping = 'Wrap'
        $body.FontSize = 14
        $body.Margin = [System.Windows.Thickness]::new(0,5,0,0)
        $body.Padding = [System.Windows.Thickness]::new(6,2,6,3)
        $body.Background = Get-HighlightBrush $color
        $stack.Children.Add($ref) | Out-Null
        $stack.Children.Add($body) | Out-Null
        $grid.Children.Add($stack) | Out-Null
        $card.Content = $grid
        $card.Add_Click({
            $p2 = ([string]$this.Tag) -split '\|'
            Show-Page 'Bible'
            Set-BibleChapter $p2[0] ([int]$p2[1])
            Open-BibleVerse ([string]$this.Tag)
        })
        $list.Children.Add($card) | Out-Null
    }
}

# ---------------------------------------------------------------- book list with chapters

$script:bookRows = @{}
$script:openBook = ''

function Initialize-BookList {
    $panel = $script:ui.BibleBookPanel
    $panel.Children.Clear()
    $script:bookRows = @{}
    for ($i = 0; $i -lt $script:allBibleBookNames.Count; $i++) {
        $book = [string]$script:allBibleBookNames[$i]
        if ($i -eq 0 -or $i -eq 39) {
            $heading = [System.Windows.Controls.TextBlock]::new()
            $heading.Text = if ($i -eq 0) { 'OLD TESTAMENT' } else { 'NEW TESTAMENT' }
            $heading.Style = $script:app.FindResource('Caption')
            $heading.FontSize = 11
            $heading.Margin = [System.Windows.Thickness]::new(8, $(if ($i -eq 0) { 2 } else { 14 }), 0, 4)
            $panel.Children.Add($heading) | Out-Null
        }
        $header = [System.Windows.Controls.Button]::new()
        $header.Style = $script:app.FindResource('BookRowButton')
        $dock = [System.Windows.Controls.DockPanel]::new()
        $chev = [System.Windows.Controls.TextBlock]::new()
        $chev.Text = [string][char]0xE70D
        $chev.Style = $script:app.FindResource('Icon')
        $chev.FontSize = 10
        $chev.Margin = [System.Windows.Thickness]::new(6,0,0,0)
        $chev.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'TextTertiary')
        [System.Windows.Controls.DockPanel]::SetDock($chev, 'Right')
        $count = [System.Windows.Controls.TextBlock]::new()
        $count.Text = [string]$script:bookChapterCounts[$i]
        $count.FontSize = 11
        $count.VerticalAlignment = 'Center'
        $count.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'TextTertiary')
        [System.Windows.Controls.DockPanel]::SetDock($count, 'Right')
        $name = [System.Windows.Controls.TextBlock]::new()
        $name.Text = $book
        $name.TextTrimming = 'CharacterEllipsis'
        $dock.Children.Add($chev) | Out-Null
        $dock.Children.Add($count) | Out-Null
        $dock.Children.Add($name) | Out-Null
        $header.Content = $dock
        $header.DataContext = $book
        $header.ToolTip = "$book  ·  $($script:bookChapterCounts[$i]) chapters"
        $header.Add_Click({ Toggle-BookRow ([string]$this.DataContext) })
        $grid = [System.Windows.Controls.Primitives.UniformGrid]::new()
        $grid.Columns = 5
        $grid.Visibility = 'Collapsed'
        $grid.Margin = [System.Windows.Thickness]::new(2,4,2,10)
        $panel.Children.Add($header) | Out-Null
        $panel.Children.Add($grid) | Out-Null
        $script:bookRows[$book] = [pscustomobject]@{ header = $header; chevron = $chev; grid = $grid; count = [int]$script:bookChapterCounts[$i]; built = $false }
    }
}

function Build-ChapterGrid($row, [string]$book) {
    if ($row.built) { return }
    for ($c = 1; $c -le $row.count; $c++) {
        $b = [System.Windows.Controls.Button]::new()
        $b.Style = $script:app.FindResource('ChapterButton')
        $b.Content = [string]$c
        $b.DataContext = "$book|$c"
        $b.Add_Click({ $p = ([string]$this.DataContext) -split '\|'; Set-BibleChapter $p[0] ([int]$p[1]) })
        $row.grid.Children.Add($b) | Out-Null
    }
    $row.built = $true
}

function Toggle-BookRow([string]$book) {
    $row = $script:bookRows[$book]
    if ($null -eq $row) { return }
    $opening = $row.grid.Visibility -ne 'Visible'
    if ($script:openBook -and $script:openBook -ne $book -and $script:bookRows[$script:openBook]) {
        $script:bookRows[$script:openBook].grid.Visibility = 'Collapsed'
        $script:bookRows[$script:openBook].chevron.Text = [string][char]0xE70D
    }
    if ($opening) {
        Build-ChapterGrid $row $book
        $row.grid.Visibility = 'Visible'
        $row.chevron.Text = [string][char]0xE70E
        $script:openBook = $book
        $row.header.BringIntoView()
    } else {
        $row.grid.Visibility = 'Collapsed'
        $row.chevron.Text = [string][char]0xE70D
        $script:openBook = ''
    }
}

function Sync-BookList([string]$book, [int]$chapter) {
    if (-not $script:bookRows.Count) { return }
    foreach ($name in $script:bookRows.Keys) { $script:bookRows[$name].header.Tag = if ($name -eq $book) { 'Selected' } else { $null } }
    $row = $script:bookRows[$book]
    if ($null -eq $row) { return }
    if ($row.grid.Visibility -ne 'Visible') { Toggle-BookRow $book }
    $i = 1
    foreach ($b in $row.grid.Children) { $b.Tag = if ($i -eq $chapter) { 'Selected' } else { $null }; $i++ }
    foreach ($name in $script:bookRows.Keys) {
        if ($name -ne $book -and $script:bookRows[$name].built) { foreach ($b in $script:bookRows[$name].grid.Children) { $b.Tag = $null } }
    }
}
