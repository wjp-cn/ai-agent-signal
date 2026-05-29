# 19 种灯语扩展 — 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将红绿灯从简单三态扩展为 19 种可编程灯语，UI 从 WinForms 重写为 WPF

**架构：** WPF 红绿灯 UI 通过 DispatcherTimer 以 60fps 驱动动画，每个灯语是一个返回红绿亮度值的函数，OpenCode 插件根据事件映射到灯语编号

**技术栈：** PowerShell 5.1+ (WPF)、TypeScript (OpenCode Plugin)、JSON

---

## 文件结构

| 文件 | 职责 | 操作 |
|------|------|------|
| `status_writer.ps1` | 状态写入，接受 `-Pattern` 和 `-Yellow` 参数 | 修改 |
| `patterns.ps1` | 19 种灯语函数定义 | 创建 |
| `traffic_light.ps1` | WPF 红绿灯 UI | 重写 |
| `hooks/opencode-plugin.ts` | OpenCode 插件，事件→灯语映射 | 修改 |
| `config.json` | 配置文件 | 修改 |
| `README.md` | 使用说明 | 修改 |

---

### 任务 1：更新 status_writer.ps1

**文件：**
- 修改：`status_writer.ps1`

- [ ] **步骤 1：重写 status_writer.ps1**

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(0, 18)]
    [int]$Pattern,

    [Parameter(Mandatory=$true)]
    [string]$Tool,

    [switch]$Yellow,

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

# 读取现有状态以保留 yellow 字段
$existingYellow = $false
try {
    if (Test-Path $StatusFile) {
        $existing = Get-Content $StatusFile -Raw | ConvertFrom-Json
        if ($null -ne $existing.yellow) { $existingYellow = $existing.yellow }
    }
} catch {}

# 如果指定了 -Yellow 参数，使用它；否则保留现有值
$yellowState = if ($Yellow) { $true } else { $existingYellow }

$data = @{
    pattern = $Pattern
    tool = $Tool
    timestamp = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds
    yellow = $yellowState
}

$data | ConvertTo-Json -Compress | Set-Content $StatusFile -Encoding UTF8
```

- [ ] **步骤 2：测试写入**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -Pattern 4 -Tool test`
验证：`powershell -Command "Get-Content $env:USERPROFILE\.traffic-light\status.json"`
预期：`{"pattern":4,"tool":"test","timestamp":...,"yellow":false}`

- [ ] **步骤 3：测试黄灯**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -Pattern 4 -Tool test -Yellow`
验证：`powershell -Command "(Get-Content $env:USERPROFILE\.traffic-light\status.json | ConvertFrom-Json).yellow"`
预期：`True`

---

### 任务 2：创建灯语引擎 (patterns.ps1)

**文件：**
- 创建：`patterns.ps1`

- [ ] **步骤 1：创建辅助函数和前 10 种灯语 (0-9)**

```powershell
# === 灯语引擎 ===
# 每个灯语函数接收 $t (毫秒)，返回 @{ Red = 0.0~1.0; Green = 0.0~1.0 }

function Square-Wave([double]$t, [double]$period, [double]$duty) {
    $phase = ($t % $period) / $period
    if ($phase -lt $duty) { return 1.0 } else { return 0.0 }
}

function Pulse([double]$t, [double]$period, [double]$duration) {
    if (($t % $period) -lt $duration) { return 1.0 } else { return 0.0 }
}

# 0: 全灭
function Pattern-0([double]$t) {
    return @{ Red = 0.0; Green = 0.0 }
}

# 1: 同闪
function Pattern-1([double]$t) {
    $v = Square-Wave $t 500 0.5
    return @{ Red = $v; Green = $v }
}

# 2: 绿灯闪
function Pattern-2([double]$t) {
    return @{ Red = 0.0; Green = (Square-Wave $t 500 0.5) }
}

# 3: 红灯闪
function Pattern-3([double]$t) {
    return @{ Red = (Square-Wave $t 500 0.5); Green = 0.0 }
}

# 4: 绿灯常亮
function Pattern-4([double]$t) {
    return @{ Red = 0.0; Green = 1.0 }
}

# 5: 红灯常亮
function Pattern-5([double]$t) {
    return @{ Red = 1.0; Green = 0.0 }
}

# 6: 双灯常亮
function Pattern-6([double]$t) {
    return @{ Red = 1.0; Green = 1.0 }
}

# 7: 红绿警车交替快闪
function Pattern-7([double]$t) {
    return @{ Red = (Square-Wave $t 300 0.5); Green = (Square-Wave ($t + 150) 300 0.5) }
}

# 8: 科技感心跳双闪
function Pattern-8([double]$t) {
    $pulse = [Math]::Abs([Math]::Sin([Math]::PI * $t / 800.0))
    $pulse = [Math]::Pow($pulse, 3)
    return @{ Red = $pulse; Green = $pulse }
}

# 9: SOS 国际求救信号
function Pattern-9([double]$t) {
    # SOS: ··· --- ···
    # 短=150ms, 长=450ms, 符号间隔=100ms, 字母间隔=300ms
    # 序列: 150 100 150 100 150 300 450 100 450 100 450 300 150 100 150 100 150
    # 总时长: 3500ms
    $sosPattern = @(
        @{ start=0; end=150 },      # 短
        @{ start=250; end=400 },    # 短
        @{ start=500; end=650 },    # 短
        @{ start=950; end=1400 },   # 长
        @{ start=1500; end=1950 },  # 长
        @{ start=2050; end=2500 },  # 长
        @{ start=2800; end=2950 },  # 短
        @{ start=3050; end=3200 },  # 短
        @{ start=3300; end=3450 }   # 短
    )
    $tt = $t % 3500
    $v = 0.0
    foreach ($p in $sosPattern) {
        if ($tt -ge $p.start -and $tt -lt $p.end) { $v = 1.0; break }
    }
    return @{ Red = $v; Green = $v }
}

# 辅助：获取灯语结果
function Get-PatternResult([int]$pattern, [double]$t) {
    switch ($pattern) {
        0 { return (Pattern-0 $t) }
        1 { return (Pattern-1 $t) }
        2 { return (Pattern-2 $t) }
        3 { return (Pattern-3 $t) }
        4 { return (Pattern-4 $t) }
        5 { return (Pattern-5 $t) }
        6 { return (Pattern-6 $t) }
        7 { return (Pattern-7 $t) }
        8 { return (Pattern-8 $t) }
        9 { return (Pattern-9 $t) }
        default { return @{ Red = 0.0; Green = 0.0 } }
    }
}
```

- [ ] **步骤 2：测试前 10 种灯语**

运行：`powershell -ExecutionPolicy Bypass -Command ". .\patterns.ps1; for($i=0;$i -lt 10;$i++){ $r = Get-PatternResult $i 100; Write-Host \"Pattern $i : R=$($r.Red) G=$($r.Green)\" }"`
预期：每个灯语输出正确的红绿亮度值

---

### 任务 3：添加后 9 种灯语 (10-18)

**文件：**
- 修改：`patterns.ps1`

- [ ] **步骤 1：添加灯语 10-18**

在 `Get-PatternResult` 函数之前添加：

```powershell
# 10: 交替柔和呼吸灯
function Pattern-10([double]$t) {
    $r = [Math]::Pow([Math]::Sin([Math]::PI * $t / 4000.0), 2)
    $g = [Math]::Pow([Math]::Cos([Math]::PI * $t / 4000.0), 2)
    return @{ Red = $r; Green = $g }
}

# 11: 双萤火虫混沌呼吸
function Pattern-11([double]$t) {
    $r = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $t / 1700.0 + 1.2)
    $g = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $t / 2300.0 + 2.8)
    return @{ Red = $r; Green = $g }
}

# 12: 医疗监护心电波模拟
function Pattern-12([double]$t) {
    $tt = $t % 1000
    # ECG 波形
    $ecg = 0.1  # 基线
    if ($tt -ge 100 -and $tt -lt 200) { $ecg = 0.1 + 0.2 * [Math]::Sin([Math]::PI * ($tt - 100) / 100.0) }  # P波
    elseif ($tt -ge 250 -and $tt -lt 300) { $ecg = 0.1 + 0.9 * [Math]::Sin([Math]::PI * ($tt - 250) / 50.0) }  # QRS峰上升
    elseif ($tt -ge 300 -and $tt -lt 350) { $ecg = 0.1 + 0.9 * [Math]::Sin([Math]::PI * ($tt - 250) / 50.0) }  # QRS峰下降
    elseif ($tt -ge 400 -and $tt -lt 550) { $ecg = 0.1 + 0.3 * [Math]::Sin([Math]::PI * ($tt - 400) / 150.0) } # T波
    # 绿灯脉搏同步
    $green = if ($tt -ge 250 -and $tt -lt 350) { 1.0 } else { 0.0 }
    return @{ Red = $ecg; Green = $green }
}

# 13: 安全守护摆钟滴答
function Pattern-13([double]$t) {
    $tick = Pulse $t 1000 50
    return @{ Red = $tick; Green = 1.0 }
}

# 14: 正余弦相位交错跑马
function Pattern-14([double]$t) {
    $r = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $t / 3000.0)
    $g = 0.5 + 0.5 * [Math]::Cos(2 * [Math]::PI * $t / 3000.0)
    return @{ Red = $r; Green = $g }
}

# 15: 急救爆闪追击爆裂灯语
function Pattern-15([double]$t) {
    $tt = $t % 1800
    $r = 0.0; $g = 0.0
    if ($tt -lt 600) {
        # 绿灯爆闪3下
        $g = Square-Wave $tt 200 0.5
    } elseif ($tt -ge 900 -and $tt -lt 1500) {
        # 红灯爆闪3下
        $r = Square-Wave ($tt - 900) 200 0.5
    }
    return @{ Red = $r; Green = $g }
}

# 16: 太极阴阳双鱼呼吸
function Pattern-16([double]$t) {
    $r = [Math]::Pow([Math]::Sin([Math]::PI * $t / 6000.0), 3)
    $g = [Math]::Pow([Math]::Cos([Math]::PI * $t / 6000.0), 3)
    return @{ Red = [Math]::Abs($r); Green = [Math]::Abs($g) }
}

# 17: "HELLO" 极客电码广播
function Pattern-17([double]$t) {
    # H=···· E=· L=·−·· L=·−·· O=−−−
    # 点=80ms 划=240ms 符号间隔=80ms 字母间隔=240ms
    $helloPattern = @(
        # H: ····
        @{ start=0; end=80 }, @{ start=160; end=240 }, @{ start=320; end=400 }, @{ start=480; end=560 },
        # 间隔
        # E: ·
        @{ start=800; end=880 },
        # 间隔
        # L: ·−··
        @{ start=1120; end=1200 }, @{ start=1280; end=1520 }, @{ start=1600; end=1680 }, @{ start=1760; end=1840 },
        # 间隔
        # L: ·−··
        @{ start=2080; end=2160 }, @{ start=2240; end=2480 }, @{ start=2560; end=2640 }, @{ start=2720; end=2800 },
        # 间隔
        # O: −−−
        @{ start=3040; end=3280 }, @{ start=3360; end=3600 }, @{ start=3680; end=3920 }
    )
    $tt = $t % 4160
    $v = 0.0
    foreach ($p in $helloPattern) {
        if ($tt -ge $p.start -and $tt -lt $p.end) { $v = 1.0; break }
    }
    return @{ Red = $v; Green = $v }
}

# 18: 科幻雷达扫描与锁定警告
function Pattern-18([double]$t) {
    $tt = $t % 4500
    $r = 0.0; $g = 0.0
    if ($tt -lt 3000) {
        # 绿灯雷达扫描
        $g = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $tt / 3000.0)
    } elseif ($tt -lt 4000) {
        # 红灯高频暴闪
        $r = Square-Wave ($tt - 3000) 50 0.5
    } else {
        # 双灯全亮锁定
        $r = 1.0; $g = 1.0
    }
    return @{ Red = $r; Green = $g }
}
```

- [ ] **步骤 2：更新 Get-PatternResult 函数**

将 `Get-PatternResult` 函数更新为包含所有 19 种灯语：

```powershell
function Get-PatternResult([int]$pattern, [double]$t) {
    switch ($pattern) {
        0 { return (Pattern-0 $t) }
        1 { return (Pattern-1 $t) }
        2 { return (Pattern-2 $t) }
        3 { return (Pattern-3 $t) }
        4 { return (Pattern-4 $t) }
        5 { return (Pattern-5 $t) }
        6 { return (Pattern-6 $t) }
        7 { return (Pattern-7 $t) }
        8 { return (Pattern-8 $t) }
        9 { return (Pattern-9 $t) }
        10 { return (Pattern-10 $t) }
        11 { return (Pattern-11 $t) }
        12 { return (Pattern-12 $t) }
        13 { return (Pattern-13 $t) }
        14 { return (Pattern-14 $t) }
        15 { return (Pattern-15 $t) }
        16 { return (Pattern-16 $t) }
        17 { return (Pattern-17 $t) }
        18 { return (Pattern-18 $t) }
        default { return @{ Red = 0.0; Green = 0.0 } }
    }
}
```

- [ ] **步骤 3：测试所有 19 种灯语**

运行：`powershell -ExecutionPolicy Bypass -Command ". .\patterns.ps1; for($i=0;$i -lt 19;$i++){ $r = Get-PatternResult $i 1000; Write-Host \"Pattern $i : R=$($r.Red) G=$($r.Green)\" }"`
预期：所有 19 种灯语输出有效值（0.0~1.0）

---

### 任务 4：重写 traffic_light.ps1 (WPF)

**文件：**
- 重写：`traffic_light.ps1`

- [ ] **步骤 1：创建 WPF 红绿灯基础框架**

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$statusFile = "$env:USERPROFILE\.traffic-light\status.json"
$configFile = Join-Path $PSScriptRoot "config.json"
$patternsFile = Join-Path $PSScriptRoot "patterns.ps1"

# 加载灯语引擎
. $patternsFile

# 配置加载
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

# 启动时重置为绿灯
try {
    $resetDir = Split-Path $script:statusFile -Parent
    if (-not (Test-Path $resetDir)) { New-Item -ItemType Directory -Path $resetDir -Force | Out-Null }
    @{ pattern = 4; tool = "init"; timestamp = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds; yellow = $false } | ConvertTo-Json -Compress | Set-Content $script:statusFile -Encoding UTF8
} catch {}

# 状态读取
$currentPattern = 4
$yellowOn = $false
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
```

- [ ] **步骤 2：添加音效播放**

在配置加载之后添加：

```powershell
Add-Type -Namespace Win32 -Name Sound -MemberDefinition @'
[DllImport("winmm.dll", CharSet = CharSet.Auto)]
public static extern bool PlaySound(string sound, System.IntPtr hmod, int flags);
'@
$SND_ASYNC = 1; $SND_FILENAME = 0x20000

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
```

- [ ] **步骤 3：创建 WPF 窗口**

```powershell
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
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
        <Ellipse x:Name="YellowLed" Width="32" Height="32" Margin="0,0,0,0" VerticalAlignment="Center">
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

# 初始状态
$redLed.Opacity = 0.15
$yellowLed.Opacity = 0.15
$greenLed.Opacity = 1.0
```

- [ ] **步骤 4：添加拖动和右键菜单**

```powershell
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
```

- [ ] **步骤 5：添加动画定时器**

```powershell
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
        if ($status.yellow -ne $script:yellowOn) {
            $script:yellowOn = [bool]$status.yellow
        }
    }

    $result = Get-PatternResult $script:currentPattern $script:patternTime
    $redLed.Opacity = [Math]::Max(0.15, [double]$result.Red)
    $greenLed.Opacity = [Math]::Max(0.15, [double]$result.Green)
    $yellowLed.Opacity = if ($script:yellowOn) { 1.0 } else { 0.15 }
})
$timer.Start()

$window.ShowDialog()
```

- [ ] **步骤 6：手动测试**

运行：`powershell -ExecutionPolicy Bypass -File traffic_light.ps1`
预期：显示 WPF 红绿灯窗口，默认绿灯常亮

在另一个终端测试灯语切换：
```powershell
powershell -ExecutionPolicy Bypass -File status_writer.ps1 -Pattern 8 -Tool test
```
预期：红绿灯显示心跳灯语

---

### 任务 5：更新 OpenCode 插件

**文件：**
- 修改：`hooks/opencode-plugin.ts`

- [ ] **步骤 1：重写插件**

```typescript
import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"
import { join } from "node:path"
import { readFileSync } from "node:fs"

const STATUS_WRITER = join(import.meta.dirname, "..", "status_writer.ps1")

let currentPattern = 4
let idleCooldown: ReturnType<typeof setTimeout> | null = null

function getConfigPath(): string {
  return join(import.meta.dirname, "..", "config.json")
}

function getStatusFile(): string {
  try {
    const cfg = JSON.parse(readFileSync(getConfigPath(), "utf-8"))
    if (cfg.statusFile) {
      return cfg.statusFile.replace("~", process.env.USERPROFILE || "")
    }
  } catch {
    // config file missing or invalid
  }
  return join(process.env.USERPROFILE || "", ".traffic-light", "status.json")
}

function writePattern(pattern: number, yellow = false) {
  try {
    const args = [
      "-ExecutionPolicy", "Bypass",
      "-File", STATUS_WRITER,
      "-Pattern", String(pattern),
      "-Tool", "opencode",
      "-StatusFile", getStatusFile()
    ]
    if (yellow) args.push("-Yellow")
    execFileSync("powershell", args, { timeout: 5000, stdio: "ignore" })
    currentPattern = pattern
  } catch {
    // status write failed
  }
}

function setPattern(pattern: number) {
  if (idleCooldown) return
  if (currentPattern !== pattern) {
    writePattern(pattern)
  }
}

function setIdle() {
  writePattern(4)
  if (idleCooldown) clearTimeout(idleCooldown)
  idleCooldown = setTimeout(() => { idleCooldown = null }, 1000)
}

export default (async () => {
  writePattern(4)

  return {
    "tool.execute.before": async () => {
      setPattern(1)
    },
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        setIdle()
      }
      if (event.type === "permission.asked") {
        if (idleCooldown) {
          clearTimeout(idleCooldown)
          idleCooldown = null
        }
        writePattern(currentPattern, true)
      }
      if (event.type === "permission.replied") {
        writePattern(currentPattern, false)
      }
      if (event.type === "tui.prompt.append") {
        if (idleCooldown) {
          clearTimeout(idleCooldown)
          idleCooldown = null
        }
        writePattern(3)
      }
      if (event.type === "message.updated") {
        setPattern(5)
      }
    }
  }
}) satisfies Plugin
```

---

### 任务 6：更新配置和文档

**文件：**
- 修改：`config.json`
- 修改：`README.md`

- [ ] **步骤 1：更新 config.json**

```json
{
  "$schema": null,
  "statusFile": "~/.traffic-light/status.json",
  "sound": {
    "enabled": true,
    "files": {
      "running": "C:\\Windows\\Media\\Windows Hardware Fail.wav",
      "waiting": "C:\\Windows\\Media\\Windows Message Nudge.wav",
      "stopped": "C:\\Windows\\Media\\Windows Balloon.wav"
    }
  },
  "window": {
    "x": 100,
    "y": 100
  },
  "tools": ["opencode"],
  "patternMap": {
    "init": 4,
    "prompt": 3,
    "generating": 5,
    "tool": 1,
    "idle": 4
  }
}
```

- [ ] **步骤 2：更新 README.md**

更新 README 反映新的灯语系统、status.json 格式变更、19 种灯语说明。

---

### 任务 7：集成测试

- [ ] **步骤 1：启动红绿灯**

运行：`powershell -ExecutionPolicy Bypass -File traffic_light.ps1`
预期：显示 WPF 红绿灯，默认绿灯常亮 (灯语 4)

- [ ] **步骤 2：测试每种灯语**

在另一个终端依次测试：
```powershell
for ($i=0; $i -lt 19; $i++) {
    powershell -ExecutionPolicy Bypass -File status_writer.ps1 -Pattern $i -Tool test
    Start-Sleep -Seconds 2
}
```
预期：每种灯语正确显示对应的动画效果

- [ ] **步骤 3：测试黄灯**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -Pattern 4 -Tool test -Yellow`
预期：绿灯常亮 + 黄灯亮

- [ ] **步骤 4：测试 OpenCode 集成**

重启 OpenCode，执行操作，验证灯语自动切换。

---

## 自检

1. **规格覆盖度**：19 种灯语、WPF UI、状态协议、事件映射、黄灯独立控制均有对应任务。
2. **占位符扫描**：无 TODO、待定。所有灯语有完整实现代码。
3. **类型一致性**：`pattern` 字段统一为 0-18 整数，`yellow` 统一为布尔值。
