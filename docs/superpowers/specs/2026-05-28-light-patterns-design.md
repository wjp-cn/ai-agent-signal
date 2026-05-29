# 19 种灯语扩展 — 设计规格

## 概述

将红绿灯从简单的三态（红/黄/绿）扩展为 19 种可编程灯语，支持亮度渐变、快速闪烁、复杂时序。UI 从 WinForms 重写为 WPF，利用原生动画能力实现丝滑效果。

## 架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| UI 框架 | WPF | 原生支持 Opacity 动画、DispatcherTimer、Easing 函数 |
| 黄灯 | 独立于灯语系统 | 权限等待时黄灯亮，不中断当前灯语 |
| 状态格式 | `pattern: 0-18` | 全新格式，不兼容旧版 `state` 字段 |
| 灯语触发 | 插件直接映射 | OpenCode 插件根据事件选择灯语编号 |
| 窗口大小 | 64×168 | 与原项目一致，圆灯稍大 (r=18) |

## 文件结构

```
new-traffic/
├── traffic_light.ps1          # WPF 红绿灯 UI（重写）
├── status_writer.ps1          # 状态写入脚本（更新）
├── patterns.ps1               # 19 种灯语函数定义
├── hooks/
│   └── opencode-plugin.ts     # OpenCode 插件（更新）
├── config.json                # 配置文件
├── 启动红绿灯.bat
└── README.md
```

## 状态协议

### status.json 格式

```json
{
  "pattern": 4,
  "tool": "opencode",
  "timestamp": 1716806400,
  "yellow": false
}
```

- `pattern`: 0-18 灯语编号
- `tool`: 工具标识符
- `timestamp`: Unix 时间戳（秒）
- `yellow`: 黄灯状态（true=亮，false=灭），独立于灯语

### status_writer.ps1 接口

```powershell
.\status_writer.ps1 -Pattern <0-18> -Tool <name> [-Yellow] [-StatusFile <path>]
```

- `-Pattern`（必填）: 灯语编号 0-18
- `-Tool`（必填）: 工具名称
- `-Yellow`（可选）: 点亮黄灯
- `-StatusFile`（可选）: 状态文件路径，默认 `~/.traffic-light/status.json`

## WPF 红绿灯 UI

### 窗口结构

- 窗口：64×168，无边框，置顶，不在任务栏，透明背景
- 红灯：椭圆 36×36，中心 (32, 24)，径向渐变 (#ff6b6b → #e74c3c)
- 黄灯：椭圆 32×32，中心 (32, 84)，径向渐变 (#ffe066 → #f1c40f)
- 绿灯：椭圆 36×36，中心 (32, 144)，径向渐变 (#5eff8a → #2ecc71)
- 未亮时：Opacity=0.15（微弱轮廓）

### 动画驱动

```powershell
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(16)  # ~60fps
$timer.Add_Tick({
    $script:patternTime += 16
    $result = Get-PatternResult -Pattern $script:currentPattern -Time $script:patternTime
    $redLed.Opacity = $result.Red
    $greenLed.Opacity = $result.Green
    # 黄灯独立控制
    $yellowLed.Opacity = if ($script:yellowOn) { 1.0 } else { 0.15 }
})
```

### 交互

- 左键拖动
- 右键菜单：Mute sounds / Exit
- 状态切换时播放音效（可配置）

## 灯语引擎 (patterns.ps1)

### 核心接口

每个灯语是一个函数，接收经过时间 `$t`（毫秒），返回哈希表 `@{ Red = 0.0~1.0; Green = 0.0~1.0 }`。

### 19 种灯语

#### 0: 全灭 (Both Off)
```
R=0, G=0
```

#### 1: 同闪 (Both Flash)
```
周期 500ms，亮 250ms / 灭 250ms
R = G = 方波(t, 500, 0.5)
```

#### 2: 绿灯闪 (Green Flash)
```
R=0, G=方波(t, 500, 0.5)
```

#### 3: 红灯闪 (Red Flash)
```
R=方波(t, 500, 0.5), G=0
```

#### 4: 绿灯常亮 (Green On)
```
R=0, G=1
```

#### 5: 红灯常亮 (Red On)
```
R=1, G=0
```

#### 6: 双灯常亮 (Both On)
```
R=1, G=1
```

#### 7: 红绿警车交替快闪 (Police Alternate)
```
周期 300ms
R = 方波(t, 300, 0.5)
G = 方波(t+150, 300, 0.5)
```

#### 8: 科技感心跳双闪 (Heartbeat Pulse)
```
周期 800ms
pulse = abs(sin(π·t/800))³
R = G = pulse
```

#### 9: SOS 国际求救信号 (SOS Morse)
```
序列：··· --- ··· (三短三长三短)
短 = 150ms，长 = 450ms，符号间隔 100ms，字母间隔 300ms
整个序列周期 = 3500ms
R = G = 查表(t mod 3500)
```

#### 10: 交替柔和呼吸灯 (Breathing Alternate)
```
周期 4000ms
R = sin²(π·t/4000)
G = cos²(π·t/4000)
```

#### 11: 双萤火虫混沌呼吸 (Firefly Sin)
```
R = 0.5 + 0.5·sin(2π·t/1700 + 1.2)
G = 0.5 + 0.5·sin(2π·t/2300 + 2.8)
两个独立非对称周期，相位差创造混沌感
```

#### 12: 医疗监护心电波模拟 (ECG Wave)
```
ECG 波形周期 1000ms：
- 0~100ms: 基线 (0.1)
- 100~200ms: P波 (0.3)
- 200~250ms: 基线
- 250~350ms: QRS峰 (1.0)
- 350~400ms: 基线
- 400~550ms: T波 (0.4)
- 550~1000ms: 基线
R = ECG波形(t mod 1000)
G = 脉冲(t mod 1000 在 250~350ms 时 = 1.0, 否则 = 0)
```

#### 13: 安全守护摆钟滴答 (Tick-Tock)
```
G = 1 (常亮)
R = 脉冲(t mod 1000 < 50ms ? 1.0 : 0.0)
```

#### 14: 正余弦相位交错跑马 (Phase Chase)
```
周期 3000ms
R = 0.5 + 0.5·sin(2π·t/3000)
G = 0.5 + 0.5·cos(2π·t/3000)
90度相位差
```

#### 15: 急救爆闪追击爆裂灯语 (Strobe Chase)
```
序列周期 1800ms：
- 0~600ms: 绿灯爆闪3下 (100ms on/off × 3)
- 600~900ms: 停顿
- 900~1500ms: 红灯爆闪3下 (100ms on/off × 3)
- 1500~1800ms: 停顿
```

#### 16: 太极阴阳双鱼呼吸 (Tai-Chi S-curve)
```
周期 6000ms
R = sin³(π·t/6000)
G = cos³(π·t/6000)
三阶正弦，长端强滞留感
```

#### 17: "HELLO" 极客电码广播 (Hello Morse)
```
H = ···· (4短)
E = · (1短)
L = ·−·· (1短1长2短)
L = ·−··
O = −−− (3长)
点 = 80ms，划 = 240ms，符号间隔 80ms，字母间隔 240ms
整个单词周期 ≈ 3200ms
R = G = 查表(t mod 3200)
```

#### 18: 科幻雷达扫描与锁定警告 (Radar Lock)
```
序列周期 4500ms：
- 0~3000ms: 绿灯正弦扫描 (R=0, G=0.5+0.5·sin(2π·t/3000))
- 3000~4000ms: 红灯高频暴闪 (R=方波(t,50ms), G=0)
- 4000~4500ms: 双灯全亮 (R=1, G=1)
```

### 辅助函数

```powershell
function Square-Wave($t, $period, $duty) {
    # 方波：周期内前 duty 比例为 1.0，其余为 0.0
    $phase = ($t % $period) / $period
    return if ($phase -lt $duty) { 1.0 } else { 0.0 }
}

function Pulse($t, $period, $duration) {
    # 脉冲：周期内前 duration 毫秒为 1.0
    return if (($t % $period) -lt $duration) { 1.0 } else { 0.0 }
}
```

## 事件映射

### OpenCode 事件 → 灯语

| 事件 | 灯语 # | 名称 | 说明 |
|------|--------|------|------|
| 初始化 | 4 | 绿灯常亮 | 空闲状态 |
| `tui.prompt.append` | 3 | 红灯闪 | 用户发消息 |
| `message.updated` | 5 | 红灯常亮 | AI 生成中 |
| `tool.execute.before` | 1 | 同闪 | 工具执行中 |
| `session.idle` | 4 | 绿灯常亮 | 完成 |
| `permission.asked` | — | **黄灯亮** | 独立控制 |

### 黄灯控制

- `permission.asked` → `yellow: true`（黄灯亮）
- `permission.replied` → `yellow: false`（黄灯灭）
- 黄灯状态通过 status.json 的 `yellow` 字段传递
- 灯语运行不受黄灯影响

### 防抖逻辑

- `session.idle` 触发后，立即写入绿灯 + 1000ms 冷却期
- 冷却期内 `message.updated` 等事件被忽略
- `tui.prompt.append`（用户主动发消息）绕过冷却期
- `permission.asked` 绕过冷却期

## 配置文件 (config.json)

```json
{
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

`patternMap` 允许用户自定义事件到灯语的映射。

## 依赖

- Windows 10/11
- PowerShell 5.1+（系统自带，需支持 WPF）
- .NET Framework 3.0+（WPF 依赖，系统自带）

## 参考

- 原项目: [claude-code-traffic-light](https://github.com/3379697106-eng/claude-code-traffic-light)
- OpenCode 插件文档: https://opencode.ai/docs/plugins
