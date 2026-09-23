# Lints every yancer-* addon with luacheck (config: .luacheckrc at the repo root).
# Downloads luacheck.exe on first run (it is not committed).
$root = Split-Path $PSScriptRoot -Parent
$luacheck = Join-Path $PSScriptRoot "luacheck.exe"

if (-not (Test-Path $luacheck)) {
    "Downloading luacheck 1.2.0..."
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest "https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe" -OutFile $luacheck
}

Push-Location $root
try {
    $addons = @(Get-ChildItem $root -Directory -Filter "yancer-*" | ForEach-Object { $_.Name })
    & $luacheck @addons
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
