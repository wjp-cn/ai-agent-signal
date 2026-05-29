# 通用 AI 编码工具桌面悬浮红绿灯

实时显示 AI 编码工具运行状态的桌面悬浮窗，支持 19 种可编程灯语。通过通用状态文件协议，支持 OpenCode、Cursor等多种工具。

## 灯语列表

| 编号 | 名称 | 简要说明 |
|------|------|----------|
| 0 | 全灭 (Both Off) | 静默休眠 |
| 1 | 同闪 (Both Flash) | 基础同频闪烁 |
| 2 | 绿灯闪 (Green Flash) | 单灯提示 |
| 3 | 红灯闪 (Red Flash) | 单红提示 |
| 4 | 绿灯常亮 (Green On) | 安全、空闲状态 |
| 5 | 红灯常亮 (Red On) | 报错、警告状态 |
| 6 | 双灯常亮 (Both On) | 全亮展示 |
| 7 | 红绿警车交替快闪 (Police Alternate) | 强警示灯语 |
| 8 | 科技感心跳双闪 (Heartbeat Pulse) | 心脏律动 |
| 9 | SOS 国际求救信号 (SOS Morse) | 摩尔斯求救 |
| 10 | 交替柔和呼吸灯 (Breathing Alternate) | 无级交替呼吸 |
| 11 | 双萤火虫混沌呼吸 (Firefly Sin) | 非对称正弦浮点 |
| 12 | 医疗监护心电波模拟 (ECG Wave) | ECG 波形 |
| 13 | 安全守护摆钟滴答 (Tick-Tock) | 绿灯长明红灯脉冲 |
| 14 | 正余弦相位交错跑马 (Phase Chase) | 90度相位差 |
| 15 | 急救爆闪追击爆裂灯语 (Strobe Chase) | 交替爆闪 |
| 16 | 太极阴阳双鱼呼吸 (Tai-Chi S-curve) | 三阶正弦 |
| 17 | "HELLO" 极客电码广播 (Hello Morse) | 摩尔斯码打招呼 |
| 18 | 科幻雷达扫描与锁定警告 (Radar Lock) | 雷达扫描锁定 |

## 状态说明

状态文件 `status.json` 格式：

```json
{
  "pattern": 5,
  "tool": "opencode",
  "timestamp": 1716890000000,
  "yellow": false
}
```

- `pattern` — 灯语编号（0-18）
- `tool` — 当前工具名称
- `timestamp` — 状态更新时间戳（毫秒）
- `yellow` — 是否为黄灯等待状态

## 安装步骤

### 1. 配置 hooks（以 OpenCode 为例）

将 `hooks/opencode-plugin.ts` 复制到 OpenCode 的插件目录，或在配置中引用该插件。

### 2. 启动红绿灯

双击 `启动红绿灯.bat`，桌面将显示悬浮红绿灯窗口。

### 3. 重启工具

重启 OpenCode 或其他 AI 编码工具，插件将自动加载并开始写入状态。

## 文件说明

```
traffic_light.ps1          # 红绿灯悬浮窗（PowerShell WinForms）
status_writer.ps1          # 通用状态写入脚本
hooks/opencode-plugin.ts   # OpenCode 插件适配器
config.json                # 配置文件
启动红绿灯.bat             # 一键启动
```

## 扩展新工具

如需为其他 AI 编码工具添加支持，只需创建对应的 hook 适配器，调用 `status_writer.ps1` 写入状态：

```powershell
powershell -ExecutionPolicy Bypass -File "status_writer.ps1" -Status "busy" -Pattern 5 -Tool "cursor"
```

状态值：
- `busy` — 红灯（工具工作中）
- `waiting` — 黄灯（等待用户）
- `idle` — 绿灯（空闲）

灯语映射通过 `config.json` 的 `patternMap` 配置。

## 依赖

- Windows 10/11
- PowerShell 5.1+

## 参考

- 原项目：
  - [claude-code-traffic-light](https://github.com/3379697106-eng/claude-code-traffic-light)
  - [cursor_agent_status_light](https://github.com/JasonLam08/cursor_agent_status_light)
