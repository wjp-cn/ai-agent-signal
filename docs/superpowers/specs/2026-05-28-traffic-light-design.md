# 通用 AI 编码工具红绿灯 — 设计规格

## 概述

桌面悬浮红绿灯，实时显示 AI 编码工具的运行状态。通过通用状态文件协议，支持 OpenCode、Cursor、Claude Code 等多种工具。

## 状态协议

### 状态定义

| 状态 | 灯色 | 含义 | 触发时机 |
|------|------|------|----------|
| `running` | 红灯 | 工具工作中 | 启动会话 / 开始执行工具 |
| `waiting` | 黄灯 | 等待用户 | 权限请求 / 询问问题 |
| `stopped` | 绿灯 | 空闲 | 执行完毕 / 会话结束 |

### 状态文件格式

路径可配置，默认 `~/.traffic-light/status.json`。

```json
{
  "state": "running",
  "tool": "opencode",
  "timestamp": 1716806400
}
```

- `state`: `running` | `waiting` | `stopped`
- `tool`: 工具标识符（`opencode` | `cursor` | `claude-code` | 自定义）
- `timestamp`: Unix 时间戳（秒）

### 状态覆盖规则

多个工具可同时写入同一状态文件。规则：后写入的覆盖先写入的。红绿灯只看最新状态。

## 架构

```
┌─────────────┐    写入 status.json    ┌──────────────┐    轮询读取    ┌──────────────┐
│  OpenCode   │ ─────────────────────→ │              │ ←──────────── │  红绿灯 UI   │
│  Plugin     │                        │ status.json  │               │  (WinForms)  │
└─────────────┘                        │              │               └──────────────┘
                                       │  状态协议:   │
┌─────────────┐    写入 status.json    │  {           │
│  Cursor     │ ─────────────────────→ │    state,    │
│  Hook       │                        │    tool,     │
└─────────────┘                        │    timestamp │
                                       │  }           │
┌─────────────┐    写入 status.json    │              │
│  Claude Code│ ─────────────────────→ │              │
│  Hook       │                        │              │
└─────────────┘                        └──────────────┘
```

## 文件结构

```
new-traffic/
├── traffic_light.ps1          # 红绿灯悬浮窗（PowerShell WinForms）
├── status_writer.ps1          # 通用状态写入脚本
├── hooks/
│   └── opencode-plugin.ts     # OpenCode 插件适配器
├── config.json                # 红绿灯配置
├── 启动红绿灯.bat             # 一键启动
└── README.md                  # 使用说明
```

## 组件设计

### 1. 通用状态写入脚本 (`status_writer.ps1`)

**职责**: 接收状态参数，写入 JSON 文件。

**接口**:
```powershell
.\status_writer.ps1 -State <running|waiting|stopped> -Tool <tool-name> [-StatusFile <path>]
```

**行为**:
- 接受 `-State` 参数（必填）: `running` | `waiting` | `stopped`
- 接受 `-Tool` 参数（必填）: 工具名称
- 接受 `-StatusFile` 参数（可选）: 状态文件路径，默认 `$env:USERPROFILE\.traffic-light\status.json`
- 自动创建目录（如果不存在）
- 写入 JSON 格式，包含 `state`、`tool`、`timestamp` 字段
- 使用 UTF-8 无 BOM 编码

### 2. 红绿灯 UI (`traffic_light.ps1`)

**职责**: 桌面悬浮窗，实时显示当前状态。

**UI 规格**:
- 窗口大小: 64×168 像素
- 三个圆形灯: 半径 14px，垂直排列，间距 56px
- 颜色方案:
  - 红灯: 填充 `#e74c3c`，发光 `#ff6b6b`
  - 黄灯: 填充 `#f1c40f`，发光 `#ffe066`
  - 绿灯: 填充 `#2ecc71`，发光 `#5eff8a`
  - 未激活: `#3a3a3a`
  - 背景: `#2d2d2d`
- 置顶显示，不在任务栏显示
- 无边框窗口
- 左键拖动，右键上下文菜单（静音/退出）

**交互**:
- 500ms 轮询状态文件
- 状态切换时重绘界面
- 状态切换时播放音效（可配置，可静音）

**音效配置**:
- 红灯: `C:\Windows\Media\Windows Hardware Fail.wav`
- 黄灯: `C:\Windows\Media\Windows Message Nudge.wav`
- 绿灯: `C:\Windows\Media\Windows Balloon.wav`
- 支持通过 `config.json` 自定义音效路径
- 支持静音（右键菜单切换）

### 3. OpenCode 插件 (`hooks/opencode-plugin.ts`)

**职责**: 作为 OpenCode 插件，监听事件并调用状态写入。

**监听的事件**:

| OpenCode Hook | 映射状态 | 说明 |
|---------------|----------|------|
| `tool.execute.before` | `running` | 工具开始执行 |
| `permission.ask` | `waiting` | 请求用户权限 |
| `tool.execute.after` | `stopped` | 工具执行完毕 |
| `event`（session 相关） | `stopped` | 会话结束 |

**实现要点**:
- 使用 `@opencode-ai/plugin` 类型
- 导出异步函数，返回 hooks 对象
- 通过 child_process 调用 `status_writer.ps1`
- 读取 `config.json` 获取状态文件路径
- 优雅降级：如果状态写入失败不影响工具正常运行

### 4. 配置文件 (`config.json`)

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
  "tools": ["opencode"]
}
```

## 扩展新工具

添加新工具支持的步骤：

1. 创建 hook 适配器脚本/插件
2. 在适配器中调用 `status_writer.ps1`
3. 将工具名加入 `config.json` 的 `tools` 数组
4. 重启红绿灯

### Cursor 适配方案

Cursor 的 hooks 机制待确认，可能的方案：
- **方案 A**: 如果 Cursor 支持类似 Claude Code 的 hooks 配置 → 在 `.cursor/` 下配置 hooks 调用 `status_writer.ps1`
- **方案 B**: 如果 Cursor 有扩展 API → 写一个轻量扩展
- **方案 C**: 备选 → 轮询 Cursor 的活动日志文件

首批实现中，Cursor 适配器标记为 **待实现（v0.2）**，当前版本仅实现 OpenCode 适配器。

## 依赖

- Windows 10/11
- PowerShell 5.1+（系统自带）
- 无需 Python 或第三方库

## 参考

- 原项目: [claude-code-traffic-light](https://github.com/3379697106-eng/claude-code-traffic-light)
- OpenCode 插件文档: `customize-opencode` skill
