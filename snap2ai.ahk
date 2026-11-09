; Snap2AI — 画面の切り取り画像を AI のチャット欄に貼り付けるツール
; AutoHotkey v2。送信（Enter / 送信ボタン）は絶対に押さない。送信は本人が行う。
; Copyright (C) 2026 Snap2AI contributors. License: GPL-2.0 (LICENSE を参照)
; https://github.com/ryofssmax-a11y/snap2ai
#Requires AutoHotkey v2.0
;@Ahk2Exe-SetName Snap2AI
;@Ahk2Exe-SetDescription Snap2AI - 切り取り画像を AI のチャット欄に貼り付け
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCopyright GPL-2.0 / Snap2AI contributors
;@Ahk2Exe-SetMainIcon snap2ai.ico
#SingleInstance Off
#Warn VarUnset, Off
Persistent
CoordMode "Mouse", "Screen"
CoordMode "Menu", "Screen"

global APP := "Snap2AI"
global APP_VERSION := "1.0.0"
global IniPath := A_ScriptDir "\snap2ai.ini"
global LogPath := A_ScriptDir "\snap2ai.log"
global Targets := []
global HotkeyStr := "^+q"
global HotkeyLast := "^+w"
global ClipTimeoutMs := 60000
global MaxTargets := 20
global ConfigVersion := 4
global CtxKey := "HKCU\Software\Classes\Directory\Background\shell\Snap2AI"
global CtxLabel := "Snap2AIで切り取って送る"
global CapStart := 0, CapSawHost := false, CapHostGoneAt := 0, CapToLast := false
global LastAI := {Idx: 0, Hwnd: 0}, LastFgKey := ""
global NMHost := "com.ryo.snap2ai"
global ChromeExtId := "nigcimkhdbgdmfgmmnkdmmcmgaebileh"
global FirefoxExtId := "snap2ai@ryo.local"

EnsureIni()
MigrateIni()
LoadConfig()

; ---- テスト用コマンドライン（常駐はしない）----
mode := A_Args.Length ? A_Args[1] : ""
; ブラウザ拡張（ネイティブメッセージング）から起動された場合
global IsNativeHost := false
if (InStr(mode, "chrome-extension://") = 1 || RegExMatch(mode, "i)\.json$") || (A_Args.Length >= 2 && A_Args[2] = FirefoxExtId)) {
    IsNativeHost := true
    act := NativeHostRead()
    NativeHostReply('{"ok":true}')
    mode := (act = "capturelast") ? "/capturelast" : "/capture"
    Log("browser request: " act)
}
if (mode = "/testpaste") {          ; クリップボードの画像をペイントに貼る
    t := {Name: "ペイント（テスト）", Exe: "mspaint.exe", Title: "", Url: "", Run: "mspaint.exe", Click: ""}
    ExitApp(SendToTarget(t) ? 0 : 1)
} else if (mode = "/paste") {       ; /paste N : N 番目の送り先に貼る
    ExitApp(SendToTarget(Targets[Integer(A_Args[2])]) ? 0 : 1)
} else if (mode = "/find") {        ; /find N : 窓を探すだけ（前面化しない）
    hwnd := FindTargetWindow(Targets[Integer(A_Args[2])])
    Log("find " A_Args[2] " -> " (hwnd ? WinGetTitle(hwnd) " [" WinGetProcessName(hwnd) "]" : "なし"))
    ExitApp(hwnd ? 0 : 1)
} else if (mode = "/activate") {    ; /activate N : 前面化だけ（貼り付けない）
    hwnd := ActivateTarget(Targets[Integer(A_Args[2])])
    Log("activate " A_Args[2] " -> " (hwnd ? WinGetTitle(hwnd) " active=" (WinActive(hwnd) ? 1 : 0) : "失敗"))
    ExitApp(hwnd && WinActive(hwnd) ? 0 : 1)
} else if (mode = "/register") {    ; 右クリックメニューに追加
    ExitApp(RegisterContextMenu(true) ? 0 : 1)
} else if (mode = "/unregister") {  ; 右クリックメニューから削除
    ExitApp(RegisterContextMenu(false) ? 0 : 1)
} else if (mode = "/startmenu") {   ; スタートメニューに追加
    ExitApp(RegisterStartMenu(true) ? 0 : 1)
} else if (mode = "/unstartmenu") { ; スタートメニューから削除
    ExitApp(RegisterStartMenu(false) ? 0 : 1)
} else if (mode = "/browserreg") {  ; ブラウザ拡張との連携を登録
    ExitApp(RegisterBrowserHost(true) ? 0 : 1)
} else if (mode = "/browserunreg") {
    ExitApp(RegisterBrowserHost(false) ? 0 : 1)
} else if (mode = "/menu") {        ; メニューの見た目確認用
    ShowTargetMenu(true)
    ExitApp
}

; ---- 常駐（二重起動は防止）----
; /capture … 右クリックメニューから。常駐中ならそちらに切り取りを頼み、いなければ自分が常駐して始める
global WM_SNAP2AI_CAPTURE := DllCall("RegisterWindowMessage", "Str", "Snap2AI_Capture", "UInt")
; 常駐中のアプリに頼む内容: 0=切り取り 1=切り取って直前のAIへ 2=(テスト)クリップボードを直前のAIへ 3=(テスト)メニュー表示
SigCodes := Map("/capture", 0, "/capturelast", 1, "/testlast", 2, "/testmenu", 3)
hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Snap2AI_SingleInstance", "Ptr")
if (A_LastError = 183) {
    if SigCodes.Has(mode) {
        if SignalRunningInstance(SigCodes[mode])
            ExitApp(0)
        if !IsNativeHost
            MsgBox("常駐中の Snap2AI に連絡できませんでした。", APP, 0x30)
        ExitApp(1)
    }
    MsgBox("Snap2AI はすでに起動しています（画面右下のアイコン）。", APP, 0x40)
    ExitApp
}
if (mode = "/testlast" || mode = "/testmenu")
    ExitApp(1)   ; テスト用は常駐中のときだけ
if IsNativeHost {
    ; ブラウザから起動された窓口プロセスは常駐せず、別プロセスで常駐を始める
    DllCall("CloseHandle", "Ptr", hMutex)
    try Run('"' A_ScriptFullPath '" ' mode, A_ScriptDir)
    ExitApp(0)
}
OnMessage(WM_SNAP2AI_CAPTURE, OnCaptureRequest)

if !A_IsCompiled && FileExist(A_ScriptDir "\snap2ai.ico")
    try TraySetIcon(A_ScriptDir "\snap2ai.ico")
A_IconTip := APP "（" HotkeyLabel(HotkeyStr) " で切り取り）"
tray := A_TrayMenu
tray.Delete()
tray.Add("切り取りして送る（" HotkeyLabel(HotkeyStr) "）", (*) => StartCapture())
tray.Add("切り取って直前のAIへ（" HotkeyLabel(HotkeyLast) "）", (*) => StartCapture(true))
tray.Add()
tray.Add("設定", (*) => OpenSettings())
tray.Add("右クリックメニューに追加", (*) => (RegisterContextMenu(true) && TrayTip("デスクトップやフォルダーの何もない所を右クリックすると「" CtxLabel "」が出ます。", APP, 0x10)))
tray.Add("右クリックメニューから削除", (*) => (RegisterContextMenu(false) && TrayTip("右クリックメニューから削除しました。", APP, 0x10)))
tray.Add("スタートメニューに追加", (*) => (RegisterStartMenu(true) && TrayTip("スタートメニューの「Snap2AI」フォルダーに追加しました。", APP, 0x10)))
tray.Add("スタートメニューから削除", (*) => (RegisterStartMenu(false) && TrayTip("スタートメニューから削除しました。", APP, 0x10)))
tray.Add("ブラウザ連携を登録", (*) => (RegisterBrowserHost(true) && TrayTip("ブラウザ拡張から Snap2AI を呼べるようにしました。拡張の入れ方は README をご覧ください。", APP, 0x10)))
tray.Add("ブラウザ連携を解除", (*) => (RegisterBrowserHost(false) && TrayTip("ブラウザ連携を解除しました。", APP, 0x10)))
tray.Add("ブラウザ拡張のフォルダーを開く", (*) => Run('explorer.exe "' A_ScriptDir '\browser-ext"'))
tray.Add("設定を再読み込み", (*) => Reload())
tray.Add()
tray.Add("終了", (*) => ExitApp())
tray.Default := "切り取りして送る（" HotkeyLabel(HotkeyStr) "）"

try {
    Hotkey(HotkeyStr, (*) => StartCapture())
} catch {
    MsgBox("ホットキー「" HotkeyStr "」を登録できませんでした。`n設定（snap2ai.ini）の Hotkey を変えてください。", APP, 0x30)
}
if (HotkeyLast != "") {
    try {
        Hotkey(HotkeyLast, (*) => StartCapture(true))
    } catch {
        MsgBox("ホットキー「" HotkeyLast "」を登録できませんでした。`n設定（snap2ai.ini）の HotkeyLast を変えてください。", APP, 0x30)
    }
}
SetTimer(TrackForeground, 400)
TrayTip(HotkeyLabel(HotkeyStr) " で画面を切り取って、AI のチャット欄に貼り付けます。", APP " 起動しました", 0x10)
Log("started hotkey=" HotkeyStr " last=" HotkeyLast " targets=" Targets.Length (mode != "" ? " (" mode ")" : ""))
if (mode = "/capture")
    SetTimer(StartCapture, -500)
else if (mode = "/capturelast")
    SetTimer(StartCaptureLast, -500)
return

OnCaptureRequest(wParam, *) {
    Log("request received: " wParam)
    switch wParam {
        case 1: SetTimer(StartCaptureLast, -50)
        case 2: SetTimer(TestPasteLast, -50)
        case 3: SetTimer(ShowTargetMenuTest, -50)
        default: SetTimer(StartCapture, -50)
    }
    return 1
}
StartCaptureLast() => StartCapture(true)
ShowTargetMenuTest() => ShowTargetMenu(true)
TestPasteLast() {
    if !SendToLast()
        Log("test: no last AI")
}

; ---- 直前のAI: 前面の窓が送り先のどれかに当てはまったら覚えておく ----
TrackForeground() {
    global LastAI, LastFgKey
    hwnd := WinExist("A")
    if !hwnd
        return
    try title := WinGetTitle(hwnd)
    catch
        return
    key := hwnd "|" title
    if (key = LastFgKey)
        return
    LastFgKey := key
    for i, t in Targets {
        if TargetMatches(t, hwnd) {
            if (LastAI.Idx != i || LastAI.Hwnd != hwnd)
                Log("last AI -> " t.Name " : " title)
            LastAI := {Idx: i, Hwnd: hwnd}
            return
        }
    }
}

LastAIName() => (LastAI.Idx && LastAI.Idx <= Targets.Length) ? Targets[LastAI.Idx].Name : ""

; 直前のAIへ貼る。覚えた窓がもう当てはまらない（タブを替えた等）なら、その送り先を探し直す
SendToLast() {
    if !(LastAI.Idx && LastAI.Idx <= Targets.Length)
        return false
    t := Targets[LastAI.Idx]
    prefer := (WinExist(LastAI.Hwnd) && TargetMatches(t, LastAI.Hwnd)) ? LastAI.Hwnd : 0
    return SendToTarget(t, prefer)
}

; 常駐中の Snap2AI（自分以外）の隠し窓に切り取り開始を頼む
SignalRunningInstance(code := 0) {
    DetectHiddenWindows(true)
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        if (hwnd = A_ScriptHwnd)
            continue
        try {
            if (StrLower(WinGetProcessName(hwnd)) != StrLower(A_ScriptName) && !InStr(WinGetTitle(hwnd), "snap2ai"))
                continue
        } catch {
            continue
        }
        if (WinGetPID(hwnd) = DllCall("GetCurrentProcessId"))
            continue
        PostMessage(WM_SNAP2AI_CAPTURE, code, 0, , hwnd)
        Log("capture request sent to running instance")
        return true
    }
    return false
}


; エクスプローラーの右クリックメニュー（デスクトップ・フォルダーの背景、このユーザーだけ）
RegisterContextMenu(add) {
    try {
        if add {
            cmd := A_IsCompiled ? '"' A_ScriptFullPath '" /capture' : '"' A_AhkPath '" "' A_ScriptFullPath '" /capture'
            RegWrite(CtxLabel, "REG_SZ", CtxKey)
            RegWrite(A_IsCompiled ? A_ScriptFullPath ",0" : A_AhkPath ",0", "REG_SZ", CtxKey, "Icon")
            RegWrite(cmd, "REG_SZ", CtxKey "\command")
            Log("context menu registered: " cmd)
        } else {
            try RegDeleteKey(CtxKey)
            Log("context menu removed")
        }
        return true
    } catch as e {
        MsgBox("右クリックメニューの変更に失敗しました。`n" e.Message, APP, 0x10)
        return false
    }
}

; =====================================================================
StartCapture(toLast := false) {
    global CapStart, CapSawHost, CapHostGoneAt, CapToLast
    CapToLast := toLast
    SetTimer(PollClip, 0)
    A_Clipboard := ""
    try {
        Run("ms-screenclip:")
    } catch {
        MsgBox("画面の切り取り（ms-screenclip）を起動できませんでした。", APP, 0x10)
        return
    }
    CapStart := A_TickCount, CapSawHost := false, CapHostGoneAt := 0
    Log("capture started")
    SetTimer(PollClip, 100)
}

PollClip() {
    global CapStart, CapSawHost, CapHostGoneAt
    if ClipHasImage() {
        SetTimer(PollClip, 0)
        Sleep(150)
        if (CapToLast && LastAIName() != "")
            SendToLast()
        else
            ShowTargetMenu()   ; 直前のAIがまだ無いときはメニュー
        return
    }
    ; 切り取り画面を Esc で閉じた場合などは待つのをやめる
    if ProcessExist("ScreenClippingHost.exe") {
        CapSawHost := true, CapHostGoneAt := 0
    } else if CapSawHost {
        if !CapHostGoneAt
            CapHostGoneAt := A_TickCount
        else if (A_TickCount - CapHostGoneAt > 2000) {
            SetTimer(PollClip, 0)
            Log("capture cancelled")
            return
        }
    }
    if (A_TickCount - CapStart > ClipTimeoutMs) {
        SetTimer(PollClip, 0)
        Log("capture timeout")
    }
}

ClipHasImage() {
    return DllCall("IsClipboardFormatAvailable", "UInt", 8)      ; CF_DIB
        || DllCall("IsClipboardFormatAvailable", "UInt", 17)     ; CF_DIBV5
        || DllCall("IsClipboardFormatAvailable", "UInt", 2)      ; CF_BITMAP
}

ShowTargetMenu(testOnly := false) {
    m := Menu()
    last := LastAIName()
    if (last != "") {
        lastItem := "&0  直前のAI（" last "）`tEnter"
        m.Add(lastItem, testOnly ? ((*) => 0) : ((*) => SendToLast()))
        m.Default := lastItem
    } else {
        m.Add("送り先を選んでください", (*) => 0)
        m.Disable("送り先を選んでください")
    }
    m.Add()
    prevBrowser := ""
    for i, t in Targets {
        isBrowser := (t.Url != "")
        if (prevBrowser != "" && isBrowser != prevBrowser)
            m.Add()
        prevBrowser := isBrowser
        key := i <= 9 ? "&" i : (i = 10 ? "&0" : "  ")
        m.Add(key "  " t.Name, testOnly ? ((*) => 0) : MenuPick.Bind(i))
    }
    m.Add()
    m.Add("キャンセル", (*) => 0)
    MouseGetPos(&x, &y)
    if (last != "")
        SetTimer(HighlightFirstMenuItem, -30)   ; 「直前のAI」を選んだ状態にして Enter で決まるように
    m.Show(x, y)
}

; 表示されたメニュー窓にだけ ↓ キーを送る（他の窓にキーが行かないように）
HighlightFirstMenuItem() {
    DetectHiddenWindows(false)
    start := A_TickCount
    while (A_TickCount - start < 1500) {
        if (h := WinExist("ahk_class #32768 ahk_pid " DllCall("GetCurrentProcessId"))) {
            PostMessage(0x100, 0x28, 0, , h)   ; WM_KEYDOWN VK_DOWN
            return
        }
        Sleep(30)
    }
}

MenuPick(i, *) {
    SendToTarget(Targets[i])
}

; 送り先を前面に出して Ctrl+V で貼り付ける（Enter は押さない）
SendToTarget(t, prefer := 0) {
    global LastAI
    if !ClipHasImage() {
        TrayTip("クリップボードに画像がありません。", APP, 0x30)
        return false
    }
    hwnd := ActivateTarget(t, prefer)
    if !hwnd
        return false
    Sleep(350)
    if (t.Click != "") {
        p := StrSplit(t.Click, ",", " ")
        if (p.Length = 2) {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
            Click(Round(wx + ww * p[1]), Round(wy + wh * p[2]))
            Sleep(250)
        }
    }
    if !WinActive(hwnd) {   ; 別の窓に貼らないよう、前面でなければ中止
        TrayTip("「" t.Name "」を前面に出せなかったので、貼り付けを中止しました。", APP, 0x30)
        Log("paste aborted: not active " t.Name)
        return false
    }
    Send("^v")
    for i, x in Targets
        if (x = t)
            LastAI := {Idx: i, Hwnd: hwnd}
    Log("pasted to " t.Name " : " WinGetTitle(hwnd))
    return true
}

ActivateTarget(t, prefer := 0) {
    hwnd := prefer ? prefer : FindTargetWindow(t)
    if !hwnd {
        launch := t.Url != "" ? t.Url : ExpandEnv(t.Run)
        if (launch = "") {
            TrayTip("「" t.Name "」の窓が見つかりません。", APP, 0x30)
            return 0
        }
        try {
            Run(launch)
        } catch {
            TrayTip("「" t.Name "」を開けませんでした。", APP, 0x30)
            return 0
        }
        start := A_TickCount
        while (!hwnd && A_TickCount - start < 30000) {
            Sleep(300)
            hwnd := FindTargetWindow(t)
        }
        if !hwnd {
            TrayTip("「" t.Name "」の画面が開くのを待ちましたが見つかりませんでした。", APP, 0x30)
            return 0
        }
        Sleep(t.Url != "" ? 3000 : 1500)   ; 読み込み待ち
    }
    try {
        if (WinGetMinMax(hwnd) = -1)
            WinRestore(hwnd)
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 3)
    }
    return hwnd
}

; 上（手前）の窓から順に、プロセス名とタイトル（正規表現）で探す
FindTargetWindow(t) {
    for hwnd in WinGetList()
        if TargetMatches(t, hwnd)
            return hwnd
    return 0
}

; この窓が送り先 t に当てはまるか（プロセス名とタイトル）
TargetMatches(t, hwnd) {
    try {
        title := WinGetTitle(hwnd)
        exe := StrLower(WinGetProcessName(hwnd))
        ex := WinGetExStyle(hwnd)
    } catch {
        return false
    }
    if (title = "" || (ex & 0x80))           ; 無題・ツール窓は除外
        return false
    if (t.Exe != "") {
        hit := false
        for e in StrSplit(StrLower(t.Exe), "|", " ")
            if (e = exe)
                hit := true
        if !hit
            return false
    }
    if (t.Title != "" && !RegExMatch(title, t.Title))
        return false
    return true
}

; =====================================================================
EnsureIni() {
    if FileExist(IniPath)
        return
    FileAppend(IniHeader() GeneralText("^+q", "^+w") SectionsText(DefaultTargets()), IniPath, "UTF-16")
}

GeneralText(hk, hkLast) {
    return "`n[General]`nHotkey=" hk "`nHotkeyLast=" hkLast "`nConfigVersion=" ConfigVersion "`n"
}

; Grok Bot デスクトップアプリの場所（見つからなければ既定の場所）
GrokBotPath() {
    for p in [EnvGet("LOCALAPPDATA") "\Programs\Grok Bot\Grok Bot.exe", EnvGet("ProgramFiles") "\Grok Bot\Grok Bot.exe"]
        if FileExist(p)
            return StrReplace(p, EnvGet("LOCALAPPDATA"), "%LOCALAPPDATA%")
    return "%LOCALAPPDATA%\Programs\Grok Bot\Grok Bot.exe"
}

BrowserExes() => "chrome.exe|msedge.exe|firefox.exe|brave.exe|opera.exe|vivaldi.exe"

; アプリ版（Microsoft Store 版）。インストールされているものだけ既定の送り先に入れる
AppTargets(onlyInstalled := true) {
    all := [{Name: "ChatGPT（アプリ）", Exe: "ChatGPT.exe", Title: "", Url: "", Run: "explorer.exe shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App", Click: "", Pkg: "OpenAI.Codex_"},
        {Name: "Claude（アプリ）", Exe: "claude.exe", Title: "", Url: "", Run: "explorer.exe shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude", Click: "", Pkg: "Claude_"},
        {Name: "Copilot（アプリ）", Exe: "copilotapp.exe", Title: "", Url: "", Run: "explorer.exe shell:AppsFolder\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe!Microsoft.MicrosoftOfficeHub", Click: "", Pkg: "Microsoft.MicrosoftOfficeHub_"}]
    if !onlyInstalled
        return all
    list := []
    for t in all
        if PackageInstalled(t.Pkg)
            list.Push(t)
    return list
}

; このユーザーに Store アプリ（パッケージ名の先頭が prefix）が入っているか
PackageInstalled(prefix) {
    root := "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
    try {
        Loop Reg, root, "K"
            if (InStr(A_LoopRegName, prefix) = 1)
                return true
    }
    return false
}

DefaultTargets() {
    br := BrowserExes()
    list := [{Name: "Grok Botアプリ", Exe: "Grok Bot.exe", Title: "", Url: "", Run: GrokBotPath(), Click: ""}]
    for t in AppTargets()
        list.Push(t)
    list.Push({Name: "Grok（ブラウザ）", Exe: br, Title: "i)(^|[-|—–] )Grok( [-|—–]|$)", Url: "https://grok.com", Run: "", Click: ""})
    list.Push({Name: "ChatGPT（ブラウザ）", Exe: br, Title: "i)(^|[-|—–] )ChatGPT( [-|—–]|$)", Url: "https://chatgpt.com", Run: "", Click: ""})
    list.Push({Name: "Claude（ブラウザ）", Exe: br, Title: "i)(^|[-|—–] )Claude( [-|—–]|$)", Url: "https://claude.ai", Run: "", Click: ""})
    list.Push(MuseTarget())
    return list
}

MuseTarget() {   ; Meta の AI エージェント Muse（ブラウザ版のみ）
    return {Name: "Muse（ブラウザ）", Exe: BrowserExes(), Title: "i)(^|[-|—–] )Muse( [-|—–]|$)", Url: "https://muse.ai/", Run: "", Click: ""}
}

IniHeader() {
    return "
(
; Snap2AI 設定ファイル（保存したら、トレイのアイコン右クリック →「設定を再読み込み」）
;
; [General] Hotkey … 切り取りを始めるキー。^=Ctrl  +=Shift  !=Alt  #=Win
;   例: ^+q = Ctrl+Shift+Q   #+a = Win+Shift+A
; [General] HotkeyLast … 切り取って「直前のAI」（最後に前面にあった送り先）へメニュー無しで貼るキー。空にすると無効
;   ※ 既定の Ctrl+Shift+W は、ブラウザの「ウィンドウを閉じる」と同じキーです（Snap2AI が先に受け取ります）
;
; [Target1]～[Target20] … 送り先（メニューに出る順。番号を詰める必要はありません）。Name を空にすると無効。
;   Name  = メニューに出る名前
;   Exe   = 窓のプロセス名（| で区切って複数可）。空ならどのプロセスでも
;   Title = 窓タイトルの正規表現（i) で大文字小文字を無視）。空ならタイトルは見ない
;   Url   = 窓が見つからない時に既定のブラウザで開くアドレス（ブラウザ版の目印にもなります）
;   Run   = 窓が見つからない時に起動するアプリ（Url が空の時）
;   Click = 貼り付け前に入力欄をクリックする位置（窓の幅,高さに対する割合 例 0.5,0.9）。空ならクリックしない
;   ※ Enter や送信ボタンは押しません。送信はご自身で。
;
; アプリを追加する例（タスクマネージャーの「詳細」タブでプロセス名を確認）:
;   [Target12]
;   Name=○○（アプリ）
;   Exe=○○.exe
;   Run=C:\…\○○.exe
)"
}

SectionsText(list) {
    out := ""
    for i, t in list
        out .= "`n[Target" i "]`nName=" t.Name "`nExe=" t.Exe "`nTitle=" t.Title "`nUrl=" t.Url "`nRun=" t.Run "`nClick=" t.Click "`n"
    return out
}

ReadTargets() {
    list := []
    Loop MaxTargets {
        sec := "Target" A_Index
        name := Trim(IniRead(IniPath, sec, "Name", ""))
        if (name = "")
            continue
        list.Push({Name: name, Exe: Trim(IniRead(IniPath, sec, "Exe", "")), Title: Trim(IniRead(IniPath, sec, "Title", "")),
            Url: Trim(IniRead(IniPath, sec, "Url", "")), Run: Trim(IniRead(IniPath, sec, "Run", "")), Click: Trim(IniRead(IniPath, sec, "Click", ""))})
    }
    return list
}

; 古い設定に新しい送り先・項目を足す（v2: アプリ版、v3: Muse、v4: HotkeyLast）。ユーザーが書いた値はそのまま残す
MigrateIni() {
    ver := Integer("0" Trim(IniRead(IniPath, "General", "ConfigVersion", "1")))
    if (ver >= ConfigVersion)
        return
    old := ReadTargets()
    hk := Trim(IniRead(IniPath, "General", "Hotkey", "^+q"))
    haveExe := Map(), haveUrl := false
    for t in old {
        haveExe[StrLower(t.Exe)] := true
        if InStr(t.Url, "muse.ai")
            haveUrl := true
    }
    apps := [], browsers := []
    for t in old {
        if (t.Url != "")
            browsers.Push(t)
        else
            apps.Push(t)
    }
    if (ver < 2)
        for t in AppTargets()
            if !haveExe.Has(StrLower(t.Exe))
                apps.Push(t)
    if (ver < 3 && !haveUrl)
        browsers.Push(MuseTarget())
    merged := []
    for t in apps
        merged.Push(t)
    for t in browsers
        merged.Push(t)
    FileCopy(IniPath, IniPath ".bak", true)
    hkLast := Trim(IniRead(IniPath, "General", "HotkeyLast", "^+w"))
    FileDelete(IniPath)
    FileAppend(IniHeader() GeneralText(hk, hkLast) SectionsText(merged), IniPath, "UTF-16")
    Log("ini migrated v" ver " -> v" ConfigVersion " (" merged.Length " targets, backup: snap2ai.ini.bak)")
}

LoadConfig() {
    global HotkeyStr, Targets
    global HotkeyLast
    HotkeyStr := Trim(IniRead(IniPath, "General", "Hotkey", "^+q"))
    if (HotkeyStr = "")
        HotkeyStr := "^+q"
    HotkeyLast := Trim(IniRead(IniPath, "General", "HotkeyLast", "^+w"))
    Targets := ReadTargets()
}

OpenSettings() {
    EnsureIni()
    Run('notepad.exe "' IniPath '"')
}

ExpandEnv(s) {
    if (s = "")
        return ""
    buf := Buffer(4096 * 2)
    DllCall("ExpandEnvironmentStrings", "Str", s, "Ptr", buf, "UInt", 4096)
    return StrGet(buf)
}

HotkeyLabel(h) {
    out := ""
    mods := Map("^", "Ctrl+", "+", "Shift+", "!", "Alt+", "#", "Win+")
    i := 1
    while (i <= StrLen(h) && mods.Has(SubStr(h, i, 1))) {
        out .= mods[SubStr(h, i, 1)]
        i++
    }
    return out StrUpper(SubStr(h, i))
}

Log(msg) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " msg "`n", LogPath, "UTF-8")
}

; スタートメニュー（このユーザーだけ）: Programs\Snap2AI\ にショートカットを作る
RegisterStartMenu(add) {
    dir := A_Programs "\Snap2AI"
    try {
        if add {
            DirCreate(dir)
            exe := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
            pre := A_IsCompiled ? "" : '"' A_ScriptFullPath '" '
            FileCreateShortcut(exe, dir "\" CtxLabel ".lnk", A_ScriptDir, pre "/capture", "画面を切り取って AI のチャット欄に貼り付けます", exe)
            FileCreateShortcut(exe, dir "\Snap2AI.lnk", A_ScriptDir, Trim(pre), "Snap2AI を起動します（タスクトレイに常駐）", exe)
            Log("start menu shortcuts created: " dir)
        } else {
            if DirExist(dir)
                DirDelete(dir, true)
            Log("start menu shortcuts removed")
        }
        return true
    } catch as e {
        MsgBox("スタートメニューの変更に失敗しました。`n" e.Message, APP, 0x10)
        return false
    }
}

; ---- ブラウザ拡張との連携（ネイティブメッセージング）----
; ブラウザから 4 バイトの長さ + JSON が届く。{"action":"capture"} か {"action":"capturelast"}
NativeHostRead() {
    try {
        f := FileOpen("*", "r")
        b := Buffer(4, 0)
        if (f.RawRead(b, 4) < 4)
            return "capture"
        n := NumGet(b, 0, "UInt")
        if (n < 1 || n > 65536)
            return "capture"
        m := Buffer(n, 0)
        f.RawRead(m, n)
        return InStr(StrGet(m, n, "UTF-8"), "capturelast") ? "capturelast" : "capture"
    }
    return "capture"
}

NativeHostReply(json) {
    try {
        n := StrPut(json, "UTF-8") - 1
        b := Buffer(4 + n + 1, 0)
        NumPut("UInt", n, b)
        StrPut(json, b.Ptr + 4, n + 1, "UTF-8")
        f := FileOpen("*", "w")
        f.RawWrite(b, 4 + n)
        f.Close()
    }
}

RegisterBrowserHost(add) {
    dir := A_ScriptDir "\browser-ext"
    keys := ["HKCU\Software\Google\Chrome\NativeMessagingHosts\" NMHost
           , "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\" NMHost
           , "HKCU\Software\Mozilla\NativeMessagingHosts\" NMHost]
    try {
        if add {
            DirCreate(dir)
            exe := StrReplace(A_ScriptFullPath, "\", "\\")
            chromeJson := '{"name": "' NMHost '", "description": "Snap2AI", "path": "' exe '", "type": "stdio", "allowed_origins": ["chrome-extension://' ChromeExtId '/"]}'
            ffJson := '{"name": "' NMHost '", "description": "Snap2AI", "path": "' exe '", "type": "stdio", "allowed_extensions": ["' FirefoxExtId '"]}'
            for name, txt in Map("host-chrome.json", chromeJson, "host-firefox.json", ffJson) {
                try FileDelete(dir "\" name)
                FileAppend(txt, dir "\" name, "UTF-8-RAW")
            }
            RegWrite(dir "\host-chrome.json", "REG_SZ", keys[1])
            RegWrite(dir "\host-chrome.json", "REG_SZ", keys[2])
            RegWrite(dir "\host-firefox.json", "REG_SZ", keys[3])
            Log("browser host registered")
        } else {
            for k in keys
                try RegDeleteKey(k)
            Log("browser host removed")
        }
        return true
    } catch as e {
        MsgBox("ブラウザ連携の登録に失敗しました。`n" e.Message, APP, 0x10)
        return false
    }
}
