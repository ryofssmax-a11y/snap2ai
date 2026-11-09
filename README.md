# Snap2AI（スナップ・ツー・エーアイ）

画面の一部を切り取って、その画像を **AI のチャット欄に貼り付ける** Windows 10 / 11 用の小さな常駐ツールです。
Grok Bot アプリ、ChatGPT・Claude・Copilot のアプリ版、ブラウザの Grok / ChatGPT / Claude / Muse に対応しています。

> **安全のために：Snap2AI は送信ボタンも Enter も絶対に押しません。** 貼り付けるところまでです。
> 文章を足して、ご自身で送信してください。また、送り先の窓を前面に出せなかったときは貼り付けを中止します（別の窓に貼らないため）。

## ダウンロード
[Releases](https://github.com/ryofssmax-a11y/snap2ai/releases) から `snap2ai-v1.0.0.zip` をダウンロードして、好きなフォルダーに展開します（例：`ドキュメント\snap2ai`）。
インストールは不要です。`snap2ai.exe` をダブルクリックすると、画面右下（タスクトレイ）にアイコンが出ます。

### 「Windows によって PC が保護されました」と出たら
署名していない exe のため、初回に SmartScreen の青い画面が出ることがあります。
「**詳細情報**」を押してから「**実行**」を押すと起動できます。心配な方は、下の「自分でビルドする」の手順で、ソースから exe を作れます。

## 使い方
| キー | 動き |
|---|---|
| **Ctrl+Shift+Q** | 画面が暗くなるので範囲を囲む → マウスの位置にメニュー → 送り先を選ぶ → 貼り付け |
| **Ctrl+Shift+W** | 範囲を囲む → メニューなしで「直前のAI」へそのまま貼り付け |

- **直前のAI** … 送り先のどれかが最後に前面に来た窓を覚えています。Ctrl+Shift+Q のメニューでも、いちばん上に選ばれた状態で出るので **Enter** だけで送れます。まだ AI の窓を使っていないときは、Ctrl+Shift+W でもメニューが出ます。
- ※ Ctrl+Shift+W は、ブラウザでは「ウィンドウを閉じる」のキーですが、Snap2AI が起動中はこちらが優先されます。変えたいときは設定の `HotkeyLast` を書き換えてください（空にすると無効）。
- 切り取り中に **Esc** を押すとキャンセルです。
- アプリ版の AI はプロセス名で、ブラウザ版は表示中のタブのタイトルで探します。見つからなければ、アプリを起動するか、既定のブラウザで新しく開きます。

## トレイアイコンの右クリックメニュー
- 切り取りして送る / 切り取って直前のAIへ
- 設定（`snap2ai.ini` をメモ帳で開く）/ 設定を再読み込み
- 右クリックメニューに追加 / 右クリックメニューから削除
- スタートメニューに追加 / スタートメニューから削除
- ブラウザ連携を登録 / ブラウザ連携を解除 / ブラウザ拡張のフォルダーを開く
- 終了

右クリックメニュー・スタートメニュー・ブラウザ連携は、**このメニューで選んだときだけ**登録されます（このユーザーだけの設定で、管理者権限は不要）。exe を別のフォルダーに移したときは、もう一度「追加／登録」を押してください。

## 設定（snap2ai.ini）
初回起動時に exe と同じフォルダーに作られます。中に日本語の説明があります。
- `Hotkey` … 切り取りのキー（既定 `^+q`）。`^`=Ctrl `+`=Shift `!`=Alt `#`=Win
- `HotkeyLast` … 直前のAIへ送るキー（既定 `^+w`）
- `[Target1]`～`[Target20]` … 送り先。`Name`（表示名）、`Exe`（プロセス名）、`Title`（窓タイトルの正規表現）、`Url`（無いとき開く URL）、`Run`（無いとき起動するアプリ）、`Click`（貼り付け前に入力欄をクリックする位置。窓に対する割合で `0.5,0.9` など）
- ChatGPT / Claude / Copilot のアプリ版は、初回起動時に入っているものだけ追加されます。

## デスクトップ・フォルダーの右クリックから使う
トレイ →「右クリックメニューに追加」を押すと、デスクトップやフォルダーの何もない所を右クリックしたときに「**Snap2AIで切り取って送る**」が出ます。

## スタートメニューから使う
トレイ →「スタートメニューに追加」を押すと、スタート →「Snap2AI」フォルダーに「Snap2AIで切り取って送る」「Snap2AI」が入ります。

## ブラウザの右クリックから使う
ページを右クリックすると「Snap2AIで切り取って送る」「Snap2AIで切り取って直前のAIへ送る」が出るようになります。
まずトレイ →「**ブラウザ連携を登録**」を押してから、拡張機能を入れてください。

### Chrome
1. アドレス欄に `chrome://extensions` と入力して Enter
2. 右上の「**デベロッパー モード**」をオン
3. 「**パッケージ化されていない拡張機能を読み込む**」を押す
4. 展開したフォルダーの中の `browser-ext\chrome` を選ぶ
- 起動時に「デベロッパー モードの拡張機能を無効にする」と出ることがありますが、× で閉じればそのまま使えます。

### Edge
`edge://extensions` →「開発者モード」をオン →「展開して読み込み」→ `browser-ext\chrome` を選ぶ

### Firefox
- 署名済みの `.xpi` が [Releases](https://github.com/ryofssmax-a11y/snap2ai/releases) にある場合は、それを Firefox の窓にドラッグ＆ドロップして「追加」を押します。
- 無い場合は一時的な読み込みのみです（Firefox を閉じると消えます）：`about:debugging#/runtime/this-firefox` →「一時的なアドオンを読み込む…」→ `browser-ext\firefox\manifest.json`

## アンインストール
1. トレイアイコンの右クリック →「右クリックメニューから削除」「スタートメニューから削除」を押す
2. ブラウザ連携を登録した場合は、トレイ →「ブラウザ連携を解除」を押し、ブラウザの拡張機能も削除
3. トレイ →「終了」
4. フォルダーごと削除

## 自分でビルドする
Windows の PowerShell で:
```
powershell -ExecutionPolicy Bypass -File build.ps1
```
公式の AutoHotkey v2 と Ahk2Exe（どちらもインストール不要の zip）を `tools\` に取得し、`dist\snap2ai.exe` と `dist\snap2ai-v1.0.0.zip` を作ります。

コマンドライン引数：`/capture`（切り取り開始。起動中ならそちらに依頼）、`/capturelast`、`/register` `/unregister`（右クリックメニュー）、`/startmenu` `/unstartmenu`、`/browserreg` `/browserunreg`

## ライセンス
GPL-2.0（[LICENSE](LICENSE)）。
exe には [AutoHotkey v2](https://github.com/AutoHotkey/AutoHotkey)（GPL-2.0）が含まれます。AutoHotkey のソースは公式リポジトリで公開されています。ビルドには [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe)（WTFPL）を使っています。

---

## English (short)
Snap2AI is a small Windows tray tool: press **Ctrl+Shift+Q**, drag a region, pick a target (Grok Bot app, ChatGPT/Claude/Copilot desktop apps, or Grok/ChatGPT/Claude/Muse in the browser), and the image is pasted into that chat box. **Ctrl+Shift+W** pastes straight into the AI window you used last. It **never presses Enter or Send** — you send it yourself. Optional Explorer right-click, Start menu and browser context-menu integration (Chrome/Edge via load-unpacked, Firefox via a signed .xpi or temporary load). Portable; settings in `snap2ai.ini` next to the exe. Licensed under GPL-2.0 (bundles AutoHotkey v2, GPL-2.0).
