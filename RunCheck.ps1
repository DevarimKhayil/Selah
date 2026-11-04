# One-off verification of the new Selah version: runs the self-test and saves preview snapshots.
$here = $PSScriptRoot
$log = Join-Path $here 'check-log.txt'
"Selah check $(Get-Date -Format o)" | Set-Content $log
try {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $here 'Test-Selah.ps1') 2>&1
    "TEST: $($out -join [Environment]::NewLine)" | Add-Content $log
} catch { "TEST ERROR: $($_ | Out-String)" | Add-Content $log }
foreach ($shot in @(@('Home','Light'),@('Home','Dark'),@('Bsf','Light'),@('BsfNotes','Dark'),@('Bible','Light'),@('Settings','Dark'),@('Torah','Light'),@('Library','Dark'))) {
    $dir = Join-Path $here ('.snap-' + [guid]::NewGuid().ToString('N'))
    $env:SELAH_DATA_DIR = $dir
    $png = Join-Path $here ("preview-{0}-{1}.png" -f $shot[0], $shot[1])
    $o = & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $here 'Selah.ps1') -TestMode -SnapshotPath $png -SnapshotPage $shot[0] -SnapshotTheme $shot[1] 2>&1
    "SNAP $($shot -join '/'): $($o -join ' | ')" | Add-Content $log
    if ([System.IO.Directory]::Exists($dir)) { Remove-Item -LiteralPath $dir -Recurse -Force }
}
Remove-Item Env:SELAH_DATA_DIR -ErrorAction SilentlyContinue
"DONE" | Add-Content $log
