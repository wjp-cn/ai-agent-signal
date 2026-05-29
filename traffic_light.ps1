Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type -Namespace Win32 -Name Sound -MemberDefinition @'
[DllImport("winmm.dll", CharSet = CharSet.Auto)]
public static extern bool PlaySound(string sound, System.IntPtr hmod, int flags);
'@
$SND_ASYNC = 1; $SND_FILENAME = 0x20000

$statusFile = "$env:USERPROFILE\.traffic-light\status.json"
$configFile = Join-Path $PSScriptRoot "config.json"
$patternsFile = Join-Path $PSScriptRoot "patterns.ps1"

. $patternsFile

$soundEnabled = $true
$soundFiles = @{
    running = "C:\Windows\Media\Windows Hardware Fail.wav"
    waiting = "C:\Windows\Media\Windows Message Nudge.wav"
    stopped = "C:\Windows\Media\Windows Balloon.wav"
}
$windowX = 100; $windowY = 100

function Load-Config {
    try {
        if (Test-Path $script:configFile) {
            $cfg = Get-Content $script:configFile -Raw | ConvertFrom-Json
            if ($cfg.statusFile) { $script:statusFile = $cfg.statusFile.Replace("~", $env:USERPROFILE) }
            if ($cfg.sound) {
                if ($null -ne $cfg.sound.enabled) { $script:soundEnabled = $cfg.sound.enabled }
                if ($cfg.sound.files) {
                    if ($cfg.sound.files.running) { $script:soundFiles.running = $cfg.sound.files.running }
                    if ($cfg.sound.files.waiting) { $script:soundFiles.waiting = $cfg.sound.files.waiting }
                    if ($cfg.sound.files.stopped) { $script:soundFiles.stopped = $cfg.sound.files.stopped }
                }
            }
            if ($cfg.window) {
                if ($null -ne $cfg.window.x) { $script:windowX = [int]$cfg.window.x }
                if ($null -ne $cfg.window.y) { $script:windowY = [int]$cfg.window.y }
            }
        }
    } catch {}
}
Load-Config

try {
    $resetDir = Split-Path $script:statusFile -Parent
    if (-not (Test-Path $resetDir)) { New-Item -ItemType Directory -Path $resetDir -Force | Out-Null }
    @{ pattern = 4; tool = "init"; timestamp = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds; yellow = $false } | ConvertTo-Json -Compress | Set-Content $script:statusFile -Encoding UTF8
} catch {}

$currentPattern = 4
$yellowOn = $false
$yellowFlash = $false
$patternTime = 0.0
$lastSoundPattern = -1

function Read-Status {
    try {
        if (Test-Path $script:statusFile) {
            $json = Get-Content $script:statusFile -Raw | ConvertFrom-Json
            return $json
        }
    } catch {}
    return $null
}

function Play-Sound($pattern) {
    try {
        if (-not $script:soundEnabled) { return }
        if ($pattern -eq $script:lastSoundPattern) { return }
        $script:lastSoundPattern = $pattern
        $soundMap = @{ 3="running"; 5="running"; 1="running"; 4="stopped"; 2="waiting" }
        $key = if ($soundMap.ContainsKey($pattern)) { $soundMap[$pattern] } else { $null }
        if ($key -and $script:soundFiles[$key]) {
            $flags = $SND_ASYNC -bor $SND_FILENAME
            [Win32.Sound]::PlaySound($script:soundFiles[$key], [IntPtr]::Zero, $flags)
        }
    } catch {}
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="64" Height="168" WindowStyle="None" Topmost="True"
        ShowInTaskbar="False" AllowsTransparency="True" Background="Transparent"
        Left="$windowX" Top="$windowY" ResizeMode="NoResize">
    <Grid Background="#2d2d2d" x:Name="MainGrid">
        <Ellipse x:Name="RedLed" Width="36" Height="36" Margin="0,6,0,0" VerticalAlignment="Top">
            <Ellipse.Fill>
                <RadialGradientBrush>
                    <GradientStop Color="#ff6b6b" Offset="0.3"/>
                    <GradientStop Color="#e74c3c" Offset="1"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
        </Ellipse>
        <Ellipse x:Name="YellowLed" Width="36" Height="36" Margin="0,0,0,0" VerticalAlignment="Center">
            <Ellipse.Fill>
                <RadialGradientBrush>
                    <GradientStop Color="#ffe066" Offset="0.3"/>
                    <GradientStop Color="#f1c40f" Offset="1"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
        </Ellipse>
        <Ellipse x:Name="GreenLed" Width="36" Height="36" Margin="0,0,0,6" VerticalAlignment="Bottom">
            <Ellipse.Fill>
                <RadialGradientBrush>
                    <GradientStop Color="#5eff8a" Offset="0.3"/>
                    <GradientStop Color="#2ecc71" Offset="1"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
        </Ellipse>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$redLed = $window.FindName("RedLed")
$yellowLed = $window.FindName("YellowLed")
$greenLed = $window.FindName("GreenLed")

$redLed.Opacity = 0.15
$yellowLed.Opacity = 0.15
$greenLed.Opacity = 1.0

$window.Add_MouseLeftButtonDown({ $window.DragMove() })

$menu = New-Object System.Windows.Controls.ContextMenu
$muteItem = New-Object System.Windows.Controls.MenuItem
$muteItem.Header = "Mute sounds"
$muteItem.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $muteItem.Header = if ($script:soundEnabled) { "Mute sounds" } else { "Unmute sounds" }
})
$menu.Items.Add($muteItem) | Out-Null
$separator = New-Object System.Windows.Controls.Separator
$menu.Items.Add($separator) | Out-Null
$exitItem = New-Object System.Windows.Controls.MenuItem
$exitItem.Header = "Exit"
$exitItem.Add_Click({ $window.Close() })
$menu.Items.Add($exitItem) | Out-Null
$window.ContextMenu = $menu

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(16)
$timer.Add_Tick({
    $script:patternTime += 16

    $status = Read-Status
    if ($status) {
        $newPattern = [int]$status.pattern
        if ($newPattern -ne $script:currentPattern) {
            $script:currentPattern = $newPattern
            $script:patternTime = 0
            Play-Sound $newPattern
        }
        if ($null -ne $status.yellow -and $status.yellow -ne $script:yellowOn) {
            $script:yellowOn = [bool]$status.yellow
        }
        if ($null -ne $status.yellowFlash) {
            $script:yellowFlash = [bool]$status.yellowFlash
        }
    }

    $result = Get-PatternResult $script:currentPattern $script:patternTime
    $redLed.Opacity = [Math]::Max(0.15, [double]$result.Red)
    $greenLed.Opacity = [Math]::Max(0.15, [double]$result.Green)
    # 黄灯：闪烁模式用方波，常亮模式用固定值
    if ($script:yellowFlash) {
        $yellowLed.Opacity = if (($script:patternTime % 600) -lt 300) { 1.0 } else { 0.15 }
    } elseif ($script:yellowOn) {
        $yellowLed.Opacity = 1.0
    } else {
        $yellowLed.Opacity = 0.15
    }
})
$timer.Start()

$window.ShowDialog()
