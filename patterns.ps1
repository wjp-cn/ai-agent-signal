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
    $sosPattern = @(
        @{ start=0; end=150 },
        @{ start=250; end=400 },
        @{ start=500; end=650 },
        @{ start=950; end=1400 },
        @{ start=1500; end=1950 },
        @{ start=2050; end=2500 },
        @{ start=2800; end=2950 },
        @{ start=3050; end=3200 },
        @{ start=3300; end=3450 }
    )
    $tt = $t % 3500
    $v = 0.0
    foreach ($p in $sosPattern) {
        if ($tt -ge $p.start -and $tt -lt $p.end) { $v = 1.0; break }
    }
    return @{ Red = $v; Green = $v }
}

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
    $ecg = 0.1
    if ($tt -ge 100 -and $tt -lt 200) { $ecg = 0.1 + 0.2 * [Math]::Sin([Math]::PI * ($tt - 100) / 100.0) }
    elseif ($tt -ge 250 -and $tt -lt 300) { $ecg = 0.1 + 0.9 * [Math]::Sin([Math]::PI * ($tt - 250) / 50.0) }
    elseif ($tt -ge 300 -and $tt -lt 350) { $ecg = 0.1 + 0.9 * [Math]::Sin([Math]::PI * ($tt - 250) / 50.0) }
    elseif ($tt -ge 400 -and $tt -lt 550) { $ecg = 0.1 + 0.3 * [Math]::Sin([Math]::PI * ($tt - 400) / 150.0) }
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
        $g = Square-Wave $tt 200 0.5
    } elseif ($tt -ge 900 -and $tt -lt 1500) {
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
    $helloPattern = @(
        @{ start=0; end=80 }, @{ start=160; end=240 }, @{ start=320; end=400 }, @{ start=480; end=560 },
        @{ start=800; end=880 },
        @{ start=1120; end=1200 }, @{ start=1280; end=1520 }, @{ start=1600; end=1680 }, @{ start=1760; end=1840 },
        @{ start=2080; end=2160 }, @{ start=2240; end=2480 }, @{ start=2560; end=2640 }, @{ start=2720; end=2800 },
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
        $g = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $tt / 3000.0)
    } elseif ($tt -lt 4000) {
        $r = Square-Wave ($tt - 3000) 50 0.5
    } else {
        $r = 1.0; $g = 1.0
    }
    return @{ Red = $r; Green = $g }
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
