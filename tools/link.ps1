# Links every yancer-* addon folder into the WoW AddOns directory with a
# directory junction, so edits here show up in-game after /reload.
param(
    [string]$WowPath = "D:\World of Warcraft 3.3.5a"
)

$addonsDir = Join-Path $WowPath "Interface\AddOns"
if (-not (Test-Path $addonsDir)) {
    Write-Error "AddOns folder not found: $addonsDir"
    exit 1
}

$root = Split-Path $PSScriptRoot -Parent
Get-ChildItem $root -Directory -Filter "yancer-*" | ForEach-Object {
    $target = Join-Path $addonsDir $_.Name
    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.LinkType -eq "Junction") {
            "ok      $($_.Name) (already linked)"
        }
        else {
            Write-Warning "$target exists and is not a junction - skipped"
        }
        return
    }
    New-Item -ItemType Junction -Path $target -Target $_.FullName | Out-Null
    "linked  $($_.Name) -> $target"
}
