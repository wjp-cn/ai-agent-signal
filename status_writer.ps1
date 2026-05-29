param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(0, 18)]
    [int]$Pattern,

    [Parameter(Mandatory=$true)]
    [string]$Tool,

    [string]$Yellow = "",
    [string]$YellowFlash = "",

    [string]$StatusFile = ""
)

if ($StatusFile -eq "") {
    $StatusFile = "$env:USERPROFILE\.traffic-light\status.json"
}

if ($StatusFile.StartsWith("~")) {
    $StatusFile = $StatusFile.Replace("~", $env:USERPROFILE)
}

$dir = Split-Path $StatusFile -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# 读取现有状态
$existingYellow = $false
$existingYellowFlash = $false
try {
    if (Test-Path $StatusFile) {
        $existing = Get-Content $StatusFile -Raw | ConvertFrom-Json
        if ($null -ne $existing.yellow) { $existingYellow = $existing.yellow }
        if ($null -ne $existing.yellowFlash) { $existingYellowFlash = $existing.yellowFlash }
    }
} catch {}

# 未传参时保留现有值，传了就用传入的值
if ($Yellow -ne "") {
    $yellowState = [System.Convert]::ToBoolean($Yellow)
} else {
    $yellowState = $existingYellow
}

if ($YellowFlash -ne "") {
    $yellowFlashState = [System.Convert]::ToBoolean($YellowFlash)
} else {
    $yellowFlashState = $existingYellowFlash
}

$data = @{
    pattern = $Pattern
    tool = $Tool
    timestamp = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds
    yellow = $yellowState
    yellowFlash = $yellowFlashState
}

$data | ConvertTo-Json -Compress | Set-Content $StatusFile -Encoding UTF8
