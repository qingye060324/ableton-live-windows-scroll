# Ableton Live Windows Scroll

一个简单的ahk脚本，让你在Windows端操作ableton和Mac端一样好用

Windows 鼠标设置中的“每次滚动的行数”也会影响 Ableton Live 内的滚动行为，包括滚动距离，以及部分视图中配合修饰键使用滚轮时的缩放步幅。行数较大时，普通浏览更快，但细调可能一下跳得太远。

这个脚本在 Live 内自动切换行数，让普通滚动和精细操作各用合适的步幅。

## 使用效果

| 操作 | 每格滚动行数 |
| --- | --- |
| 普通滚动 | 5 行 |
| 按住 Ctrl 或 Alt | 临时 1 行 |
| 松开所有 Ctrl、Alt | 立即恢复 5 行 |
| 仅按住 Shift | 保持 5 行 |

只在 **Ableton Live 12 位于前台且鼠标在其窗口内**时应用；切换到其他应用、移出 Live 窗口或正常退出脚本后，会恢复原来的 Windows 滚轮行数。支持左右 Ctrl／Alt，不占用 F 区快捷键。

## 安装

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/) 的 64 位版本。
2. 下载本仓库，双击 `AbletonLive12-WheelLines.ahk` 即可运行。
3. 需要登录后自动启动时，右键 `Install-AbletonWheelLines.ps1`，选择“使用 PowerShell 运行”。安装脚本适用于 AutoHotkey 的默认安装路径。

自动启动安装会把脚本复制到 `%LOCALAPPDATA%\AbletonLive12WheelLines`，并在当前用户的启动文件夹创建快捷方式；随后立即运行脚本。

右键通知区域的脚本图标，选择“退出并恢复原滚轮设置”即可停止。取消自动启动时，在资源管理器地址栏输入 `shell:startup`，删除 `Ableton Live 12 Wheel Lines.lnk`。

Windows 的行数是系统参数，脚本会临时切换并自动恢复，不会改写永久滚轮设置。实际移动距离由 Live 各视图决定，“1 行”不等于“1 条音轨”。
