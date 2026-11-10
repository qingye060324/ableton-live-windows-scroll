#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut

; Normal scrolling uses 5 Windows wheel SCROLL LINES, not wheel-event multipliers.
; Ctrl/Alt temporarily use 1 line; Shift does not change the line count.
; Windows exposes this as a system-wide runtime value. Restore it whenever the
; foreground app OR the window under the pointer is not Ableton Live 12.
; SPIF_UPDATEINIFILE is deliberately omitted: the user's permanent setting stays intact.

global StateDir := EnvGet("LOCALAPPDATA") "\AbletonLive12WheelLines"
global StateFile := StateDir "\settings.ini"
global NormalLines := 5
global OriginalLines := ReadWheelLines()
global AppliedLines := OriginalLines
global OverrideActive := false
global ForegroundCallback := 0
global ForegroundHook := 0

if A_Args.Length && A_Args[1] = "--self-test" {
    OnError((err, mode) => (FileAppend(err.Message " at line " err.Line "`n", "*"), ExitApp(1)))
    if A_Args.Length < 2
        throw Error("Supply a scratch settings.ini path for --self-test.")
    StateFile := A_Args[2]
    RunSelfTest()
    ExitApp()
}

DirCreate(StateDir)
RecoverInterruptedOverride()
OriginalLines := ReadWheelLines()
InitializeSettings()

OnExit(Cleanup)
; An installer/uninstaller may request a graceful exit using this private message.
OnMessage(0x8001, (*) => ExitApp())
BuildTrayMenu()
CoordMode("Mouse", "Screen")
Persistent()

; React immediately to foreground changes; the timer also covers pointer movement,
; closing windows, taskbar overlays, and applications on other monitors.
ForegroundCallback := CallbackCreate(ForegroundChanged)
ForegroundHook := DllCall("User32\SetWinEventHook", "UInt", 3, "UInt", 3,
    "Ptr", 0, "Ptr", ForegroundCallback, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
SetTimer(SyncContext, 40)
SyncContext()

#HotIf IsLiveForeground()
; Pass modifier events through unchanged. React on both edges, rather than waiting
; for the timer. Explicitly override the changed key: its physical state can still
; reflect the previous state while a keyboard-hook hotkey is being dispatched.
~*LControl::ModifierChanged("LControl", true)
~*RControl::ModifierChanged("RControl", true)
~*LAlt::ModifierChanged("LAlt", true)
~*RAlt::ModifierChanged("RAlt", true)
~*LControl Up::ModifierChanged("LControl", false)
~*RControl Up::ModifierChanged("RControl", false)
~*LAlt Up::ModifierChanged("LAlt", false)
~*RAlt Up::ModifierChanged("RAlt", false)
#HotIf

InitializeSettings() {
    ; Replace the old selectable modes; normal scrolling is now always 5 lines.
    IniWrite(NormalLines, StateFile, "Live", "Lines")
    IniWrite(3, StateFile, "Live", "SchemaVersion")
}

IsScrollModifierHeld(changedKey := "", changedDown := false, readState := GetKeyState) {
    for key in ["LControl", "RControl", "LAlt", "RAlt"] {
        if key = changedKey {
            if changedDown
                return true
        } else if readState(key, "P") {
            return true
        }
    }
    return false
}

ModifierChanged(key, down) {
    ApplyContext(IsLiveContext(), IsScrollModifierHeld(key, down))
}

IsLiveProcessName(name) {
    return RegExMatch(name, "i)^Ableton Live 12 (Suite|Standard|Intro|Lite)\.exe$") != 0
}

IsLiveWindow(hwnd) {
    if !hwnd
        return false
    try return IsLiveProcessName(WinGetProcessName("ahk_id " hwnd))
    catch
        return false
}

IsLiveForeground() {
    return IsLiveWindow(DllCall("User32\GetForegroundWindow", "Ptr"))
}

IsLiveContext() {
    if !IsLiveForeground()
        return false
    MouseGetPos(, , &pointerWindow)
    return IsLiveWindow(pointerWindow)
}

SyncContext(*) {
    ApplyContext(IsLiveContext(), IsScrollModifierHeld())
}

ForegroundChanged(hook, event, hwnd, objectId, childId, threadId, eventTime) {
    SyncContext()
}

ApplyContext(useLive, modifierHeld := false) {
    global OriginalLines, AppliedLines, OverrideActive
    Critical("On")
    try {
        current := ReadWheelLines()
        if useLive {
            targetLines := modifierHeld ? 1 : NormalLines
            entering := !OverrideActive
            if !OverrideActive {
                OriginalLines := current
                IniWrite(OriginalLines, StateFile, "Recovery", "OriginalLines")
                IniWrite(targetLines, StateFile, "Recovery", "AppliedLines")
                IniWrite(1, StateFile, "Recovery", "Pending")
                OverrideActive := true
            } else if current != AppliedLines {
                ; Preserve a genuine outside change rather than overwriting it on exit.
                OriginalLines := current
                IniWrite(OriginalLines, StateFile, "Recovery", "OriginalLines")
            }
            ; Journal before applying, so a later start can recover after a crash.
            if !entering && targetLines != AppliedLines
                IniWrite(targetLines, StateFile, "Recovery", "AppliedLines")
            if current != targetLines
                WriteWheelLines(targetLines)
            AppliedLines := targetLines
        } else if OverrideActive {
            if current = AppliedLines && current != OriginalLines
                WriteWheelLines(OriginalLines)
            OverrideActive := false
            IniWrite(0, StateFile, "Recovery", "Pending")
        } else {
            OriginalLines := current
        }
    } finally {
        Critical("Off")
    }
}

BuildTrayMenu() {
    A_IconTip := "Live 12：普通 5 行，Ctrl/Alt 暂时 1 行，Shift 不变"
    A_TrayMenu.Delete()
    label := "普通 5 行；Ctrl/Alt 按住时 1 行"
    A_TrayMenu.Add(label, (*) => 0)
    A_TrayMenu.Disable(label)
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出并恢复原滚轮设置", (*) => ExitApp())
}

ReadWheelLines() {
    lines := 0
    if !DllCall("User32\SystemParametersInfoW", "UInt", 0x68, "UInt", 0,
        "UInt*", &lines, "UInt", 0, "Int")
        throw OSError()
    return lines
}

WriteWheelLines(lines) {
    ; 0x69 = SPI_SETWHEELSCROLLLINES; 2 = SPIF_SENDCHANGE, without persistence.
    if !DllCall("User32\SystemParametersInfoW", "UInt", 0x69, "UInt", lines,
        "Ptr", 0, "UInt", 2, "Int")
        throw OSError()
}

RecoverInterruptedOverride() {
    if IniRead(StateFile, "Recovery", "Pending", "0") != "1"
        return
    saved := IniRead(StateFile, "Recovery", "OriginalLines", "")
    applied := IniRead(StateFile, "Recovery", "AppliedLines", "")
    ; Do not overwrite a newer mouse setting chosen after a forced termination.
    if IsInteger(saved) && IsInteger(applied) && ReadWheelLines() = Integer(applied)
        WriteWheelLines(Integer(saved))
    IniWrite(0, StateFile, "Recovery", "Pending")
}

Cleanup(*) {
    SetTimer(SyncContext, 0)
    if ForegroundHook
        DllCall("User32\UnhookWinEvent", "Ptr", ForegroundHook)
    if ForegroundCallback
        CallbackFree(ForegroundCallback)
    try ApplyContext(false)
}

RunSelfTest() {
    global OriginalLines, OverrideActive
    baseline := ReadWheelLines()
    try {
        Assert(IsLiveProcessName("Ableton Live 12 Suite.exe"), "Live 12 Suite matching")
        Assert(IsLiveProcessName("Ableton Live 12 Standard.exe"), "Live 12 Standard matching")
        Assert(!IsLiveProcessName("Ableton Live 11 Suite.exe"), "Live 11 excluded")
        Assert(!IsLiveProcessName("notepad.exe"), "other apps excluded")
        Assert(!IsLiveWindow(0), "invalid windows excluded")
        for oldLines in [1, 2, 4, 8] {
            IniWrite(oldLines, StateFile, "Live", "Lines")
            IniWrite(2, StateFile, "Live", "SchemaVersion")
            InitializeSettings()
            Assert(IniRead(StateFile, "Live", "Lines") = "5", "old settings migrate to 5 lines")
        }
        for iteration in [1, 2, 3] {
            ApplyContext(true, false)
            Assert(ReadWheelLines() = 5, "normal mode applies 5 Windows scroll lines")
            Assert(IniRead(StateFile, "Recovery", "Pending") = "1", "recovery journal")
            ApplyContext(true, true)
            Assert(ReadWheelLines() = 1, "modifier temporarily applies 1 line")
            Assert(IniRead(StateFile, "Live", "Lines") = "5", "temporary mode is not persisted")
            ApplyContext(true, false)
            Assert(ReadWheelLines() = 5, "last modifier release restores 5 lines")
            ApplyContext(true, true)
            ApplyContext(false, true)
            Assert(ReadWheelLines() = baseline, "restore after leaving Live")
        }
        ; Test the same detector used by both keyboard events and timer updates.
        held := Map()
        readState := (key, mode) => held.Has(key) && held[key]
        for key in ["LControl", "RControl", "LAlt", "RAlt"] {
            held.Clear()
            Assert(IsScrollModifierHeld(key, true, readState), "key-down handles stale physical state")
            held[key] := true
            Assert(IsScrollModifierHeld("", false, readState), "either side of Ctrl/Alt is detected")
            Assert(!IsScrollModifierHeld(key, false, readState), "key-up handles stale physical state")
        }
        held.Clear()
        held["LShift"] := true
        held["RShift"] := true
        ApplyContext(true, IsScrollModifierHeld("", false, readState))
        Assert(ReadWheelLines() = 5, "Shift alone leaves 5 lines unchanged")
        held["LControl"] := true
        held["RAlt"] := true
        ApplyContext(true, IsScrollModifierHeld("", false, readState))
        Assert(ReadWheelLines() = 1, "Ctrl/Alt still apply 1 line when Shift is held")
        held["LControl"] := false
        ApplyContext(true, IsScrollModifierHeld("LControl", false, readState))
        Assert(ReadWheelLines() = 1, "releasing Ctrl while Alt remains keeps 1 line")
        ApplyContext(true, IsScrollModifierHeld("RAlt", false, readState))
        Assert(ReadWheelLines() = 5, "last Ctrl/Alt release restores 5 even with Shift held")
        ApplyContext(false)
        ApplyContext(true)
        WriteWheelLines(6)
        ApplyContext(false)
        Assert(ReadWheelLines() = 6, "preserve an external settings change")
        WriteWheelLines(baseline)
        ; Simulate a forced termination with a pending override, then recover it.
        OriginalLines := baseline
        ApplyContext(true, true)
        RecoverInterruptedOverride()
        Assert(ReadWheelLines() = baseline, "recover interrupted override")
        OverrideActive := false
        FileAppend("PASS: normal 5 lines, Ctrl/Alt temporary 1 line, Shift unchanged, left/right keys, overlapping modifiers, immediate event-state restoration, app scoping, settings migration, external changes, crash recovery.`n", "*")
    } finally {
        WriteWheelLines(baseline)
        OverrideActive := false
    }
}

Assert(condition, label) {
    if !condition
        throw Error("FAILED: " label)
}
