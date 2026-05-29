# 通用 AI 编码工具红绿灯 — 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 构建一个桌面悬浮红绿灯，通过通用状态文件协议实时显示 AI 编码工具（OpenCode、Cursor 等）的运行状态

**架构：** 各工具通过 hook 适配器写入共享状态文件（JSON），PowerShell WinForms 悬浮窗轮询读取并显示红/黄/绿灯状态

**技术栈：** PowerShell 5.1+ (WinForms)、TypeScript (OpenCode Plugin)、JSON

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `status_writer.ps1` | 通用状态写入脚本，被各工具 hook 调用 |
| `traffic_light.ps1` | 红绿灯 WinForms 悬浮窗 UI |
| `hooks/opencode-plugin.ts` | OpenCode 插件，监听事件并调用状态写入 |
| `config.json` | 红绿灯配置（状态文件路径、音效、窗口位置） |
| `启动红绿灯.bat` | 一键启动红绿灯的批处理脚本 |
| `README.md` | 使用说明文档 |

---

### 任务 1：创建配置文件 (`config.json`)

**文件：**
- 创建：`config.json`

- [ ] **步骤 1：创建配置文件**

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
  "tools": ["opencode"]
}
```

- [ ] **步骤 2：验证 JSON 格式**

运行：`powershell -Command "Get-Content config.json | ConvertFrom-Json | Out-Null; Write-Host 'OK'"`
预期：`OK`

---

### 任务 2：创建通用状态写入脚本 (`status_writer.ps1`)

**文件：**
- 创建：`status_writer.ps1`

- [ ] **步骤 1：创建状态写入脚本**

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("running", "waiting", "stopped")]
    [string]$State,

    [Parameter(Mandatory=$true)]
    [string]$Tool,

    [string]$StatusFile = ""
)

if ($StatusFile -eq "") {
    $StatusFile = "$env:USERPROFILE\.traffic-light\status.json"
}

# 展开 ~ 路径
if ($StatusFile.StartsWith("~")) {
    $StatusFile = $StatusFile.Replace("~", $env:USERPROFILE)
}

$dir = Split-Path $StatusFile -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$data = @{
    state = $State
    tool = $Tool
    timestamp = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds
}

$data | ConvertTo-Json -Compress | Set-Content $StatusFile -Encoding UTF8
```

- [ ] **步骤 2：测试状态写入**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State running -Tool test`
验证：`powershell -Command "Get-Content $env:USERPROFILE\.traffic-light\status.json | ConvertFrom-Json | Select-Object state,tool"`
预期：输出 `state: running` 和 `tool: test`

- [ ] **步骤 3：测试三种状态**

```powershell
powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State waiting -Tool test
powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State stopped -Tool test
```

验证每次写入后状态文件内容正确更新。

---

### 任务 3：创建红绿灯 UI (`traffic_light.ps1`)

**文件：**
- 创建：`traffic_light.ps1`

- [ ] **步骤 1：创建 WinForms 悬浮窗基础框架**

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$statusFile = "$env:USERPROFILE\.traffic-light\status.json"
$configFile = Join-Path $PSScriptRoot "config.json"
$width = 64
$height = 168

$colors = @{
    running = @{ fill = "#e74c3c"; glow = "#ff6b6b" }
    waiting = @{ fill = "#f1c40f"; glow = "#ffe066" }
    stopped = @{ fill = "#2ecc71"; glow = "#5eff8a" }
}

$soundFiles = @{
    running = "C:\Windows\Media\Windows Hardware Fail.wav"
    waiting = "C:\Windows\Media\Windows Message Nudge.wav"
    stopped = "C:\Windows\Media\Windows Balloon.wav"
}

$dark = "#3a3a3a"
$bg = "#2d2d2d"
$stateOrder = @("running", "waiting", "stopped")
$currentState = "stopped"
$soundEnabled = $true
```

- [ ] **步骤 2：添加配置加载逻辑**

在基础框架之后添加：

```powershell
function Load-Config {
    try {
        if (Test-Path $script:configFile) {
            $cfg = Get-Content $script:configFile -Raw | ConvertFrom-Json
            if ($cfg.statusFile) {
                $script:statusFile = $cfg.statusFile.Replace("~", $env:USERPROFILE)
            }
            if ($cfg.sound) {
                if ($null -ne $cfg.sound.enabled) {
                    $script:soundEnabled = $cfg.sound.enabled
                }
                if ($cfg.sound.files) {
                    if ($cfg.sound.files.running) { $script:soundFiles.running = $cfg.sound.files.running }
                    if ($cfg.sound.files.waiting) { $script:soundFiles.waiting = $cfg.sound.files.waiting }
                    if ($cfg.sound.files.stopped) { $script:soundFiles.stopped = $cfg.sound.files.stopped }
                }
            }
        }
    } catch {}
}

Load-Config
```

- [ ] **步骤 3：添加状态读取函数**

```powershell
function Read-Status {
    try {
        if (Test-Path $script:statusFile) {
            $json = Get-Content $script:statusFile -Raw | ConvertFrom-Json
            return $json.state
        }
    } catch {}
    return "stopped"
}
```

- [ ] **步骤 4：创建窗口和拖动支持**

```powershell
$form = New-Object System.Windows.Forms.Form
$targetSize = New-Object System.Drawing.Size($width, $height)
$form.ClientSize = $targetSize
$form.MinimumSize = $targetSize
$form.MaximumSize = $targetSize
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point(100, 100)
$form.FormBorderStyle = "None"
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml($bg)

$dragging = $false
$dragOffset = $null

$form.Add_MouseDown({
    if ($_.Button -eq "Left") {
        $script:dragging = $true
        $cursorPos = [System.Windows.Forms.Cursor]::Position
        $script:dragOffset = New-Object System.Drawing.Point(
            ($cursorPos.X - $form.Location.X),
            ($cursorPos.Y - $form.Location.Y)
        )
    }
})
$form.Add_MouseMove({
    if ($script:dragging) {
        $cursorPos = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(
            ($cursorPos.X - $script:dragOffset.X),
            ($cursorPos.Y - $script:dragOffset.Y)
        )
    }
})
$form.Add_MouseUp({
    if ($_.Button -eq "Left") { $script:dragging = $false }
})
```

- [ ] **步骤 5：添加右键上下文菜单**

```powershell
Add-Type -Namespace Win32 -Name Sound -MemberDefinition @'
[DllImport("winmm.dll", CharSet = CharSet.Auto)]
public static extern bool PlaySound(string sound, System.IntPtr hmod, int flags);
'@
$SND_ASYNC = 1
$SND_FILENAME = 0x20000

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$muteItem = New-Object System.Windows.Forms.ToolStripMenuItem
$muteItem.Text = "Mute sounds"
$muteItem.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $muteItem.Text = if ($script:soundEnabled) { "Mute sounds" } else { "Unmute sounds" }
})
$menu.Items.Add($muteItem) | Out-Null
$menu.Items.Add("-") | Out-Null
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"
$exitItem.Add_Click({ $form.Close() })
$menu.Items.Add($exitItem) | Out-Null
$form.ContextMenuStrip = $menu
```

- [ ] **步骤 6：添加绘制逻辑**

```powershell
$form.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = "AntiAlias"

    $centers = @(
        @{x=32; y=28},
        @{x=32; y=84},
        @{x=32; y=140}
    )

    for ($i = 0; $i -lt $stateOrder.Count; $i++) {
        $state = $stateOrder[$i]
        $c = $centers[$i]
        $r = 14
        $active = ($state -eq $script:currentState)

        if ($active) {
            $color = $colors[$state]
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color.glow))
            $g.FillEllipse($glowBrush, $c.x - $r - 2, $c.y - $r - 2, ($r+2)*2, ($r+2)*2)
            $glowBrush.Dispose()
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color.fill))
            $g.FillEllipse($brush, $c.x - $r, $c.y - $r, $r*2, $r*2)
            $brush.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($dark))
            $g.FillEllipse($brush, $c.x - $r, $c.y - $r, $r*2, $r*2)
            $brush.Dispose()
        }
    }
})
```

- [ ] **步骤 7：添加音效播放和定时器**

```powershell
function Play-Sound($state) {
    try {
        if (-not $script:soundEnabled) { return }
        $path = $script:soundFiles[$state]
        if ($path) {
            $flags = $SND_ASYNC -bor $SND_FILENAME
            [Win32.Sound]::PlaySound($path, [IntPtr]::Zero, $flags)
        }
    } catch {}
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    $newState = Read-Status
    if ($newState -ne $script:currentState) {
        $script:currentState = $newState
        $form.Invalidate()
        Play-Sound $newState
    }
})
$timer.Start()

$form.ShowDialog()
```

- [ ] **步骤 8：手动测试红绿灯**

运行：`powershell -ExecutionPolicy Bypass -File traffic_light.ps1`
预期：显示悬浮红绿灯窗口，默认绿灯

在另一个终端切换状态测试：
```powershell
powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State running -Tool test
```
预期：红绿灯切换到红灯

---

### 任务 4：创建启动批处理 (`启动红绿灯.bat`)

**文件：**
- 创建：`启动红绿灯.bat`

- [ ] **步骤 1：创建批处理文件**

```bat
@echo off
echo Starting Traffic Light...
powershell -ExecutionPolicy Bypass -File "%~dp0traffic_light.ps1"
```

- [ ] **步骤 2：测试双击启动**

双击 `启动红绿灯.bat`，确认红绿灯窗口正常显示。

---

### 任务 5：创建 OpenCode 插件 (`hooks/opencode-plugin.ts`)

**文件：**
- 创建：`hooks/opencode-plugin.ts`

- [ ] **步骤 1：创建 OpenCode 插件**

```typescript
import type { Plugin } from "@opencode-ai/plugin"
import { execFile } from "node:child_process"
import { join } from "node:path"
import { readFileSync } from "node:fs"

const STATUS_WRITER = join(import.meta.dirname, "..", "status_writer.ps1")

function getConfigPath(): string {
  return join(import.meta.dirname, "..", "config.json")
}

function getStatusFile(): string {
  try {
    const cfg = JSON.parse(readFileSync(getConfigPath(), "utf-8"))
    if (cfg.statusFile) {
      return cfg.statusFile.replace("~", process.env.USERPROFILE || "")
    }
  } catch {}
  return join(process.env.USERPROFILE || "", ".traffic-light", "status.json")
}

function writeStatus(state: string) {
  try {
    execFile("powershell", [
      "-ExecutionPolicy", "Bypass",
      "-File", STATUS_WRITER,
      "-State", state,
      "-Tool", "opencode",
      "-StatusFile", getStatusFile()
    ], { timeout: 5000 })
  } catch {}
}

export default (async () => {
  return {
    "tool.execute.before": async () => {
      writeStatus("running")
    },
    "tool.execute.after": async () => {
      writeStatus("stopped")
    },
    "permission.ask": async () => {
      writeStatus("waiting")
    },
    "event": async (input: any) => {
      if (input?.type === "session.end" || input?.type === "session.stop") {
        writeStatus("stopped")
      }
    }
  }
}) satisfies Plugin
```

- [ ] **步骤 2：验证 TypeScript 语法**

运行：`npx tsc --noEmit hooks/opencode-plugin.ts --esModuleInterop --moduleResolution node --target es2022 --module es2022`
预期：无错误（或仅缺少 `@opencode-ai/plugin` 类型的错误，这是正常的因为类型在运行时提供）

---

### 任务 6：创建 README 文档 (`README.md`)

**文件：**
- 创建：`README.md`

- [ ] **步骤 1：编写使用说明**

内容包含：
- 项目简介
- 状态说明表格
- 安装步骤（配置 hooks、启动红绿灯、重启工具）
- 文件说明
- 扩展新工具的方法
- 依赖说明

---

### 任务 7：集成测试

- [ ] **步骤 1：启动红绿灯**

运行：`powershell -ExecutionPolicy Bypass -File traffic_light.ps1`
预期：显示绿灯

- [ ] **步骤 2：模拟 OpenCode 工作状态**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State running -Tool opencode`
预期：红灯亮起，播放音效

- [ ] **步骤 3：模拟等待用户状态**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State waiting -Tool opencode`
预期：黄灯亮起

- [ ] **步骤 4：模拟空闲状态**

运行：`powershell -ExecutionPolicy Bypass -File status_writer.ps1 -State stopped -Tool opencode`
预期：绿灯亮起

- [ ] **步骤 5：测试静音功能**

右键红绿灯 → Mute sounds → 切换状态 → 确认无音效

- [ ] **步骤 6：测试拖动功能**

左键按住红绿灯拖动 → 确认窗口跟随移动

- [ ] **步骤 7：测试退出功能**

右键 → Exit → 确认窗口关闭

---

## 自检

1. **规格覆盖度**: 所有规格中的组件（status_writer、traffic_light、opencode-plugin、config、bat、README）均有对应任务。
2. **占位符扫描**: 无 TODO、待定等占位符。所有步骤包含完整代码。
3. **类型一致性**: 状态值统一为 `running` | `waiting` | `stopped`，工具标识统一使用小写字符串。
