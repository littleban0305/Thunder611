# 雷霆611 V1.0

六年十一班專屬互動基地。

## V1.0

- 班級回憶相簿：圖片／影片上傳、文字說明
- 公告管理：管理員可建立與刪除公告
- 完整排行榜：金幣、勝場、聊天、遊戲活動資料
- 狼人殺戰績與勝率
- 頭像上傳
- 公共語音房管理：建立、鎖定、刪除
- 管理員權限與封禁系統
- 聊天室附件：圖片、影片、貼圖、emoji
- 聊天室投票：自訂問題與多個選項
- 通知中心與遊戲邀請
- SQLite 資料庫升級相容

## Windows

```powershell
flutter pub get
flutter analyze
flutter run -d windows
```

第一次開發桌面平台：

```powershell
flutter config --enable-windows-desktop
flutter create --platforms=windows .
```

## Server

```powershell
cd server
npm.cmd install
npm.cmd start
```

伺服器：`http://0.0.0.0:6110`

## 區網測試

伺服器電腦查 IP：

```powershell
ipconfig
```

其他電腦：

```powershell
flutter run -d windows --dart-define=THUNDER611_HOST=192.168.x.x
```

## 管理員

全新資料庫第一次建立帳號時會成為第一位管理員。

舊版資料庫升級時，如果資料庫沒有管理員，系統會把最早建立的帳號設為管理員。

## 媒體限制

聊天室與班級回憶單檔上限 10MB；頭像上限 5MB。
媒體檔案放在 `server/data/uploads/`。

## 注意

這是一個班級私人社群專案。V1.0 已把主要資料與權限移到伺服器，但仍建議只在可信任的班級成員與區網／自有伺服器環境測試。


## 1.0.1 Media & UI hotfix

- 媒體上傳改走 HTTP API，不再把大型檔案塞進 WebSocket 訊息。
- 圖片、影片、頭像與班級回憶支援 5MB/10MB 限制。
- 伺服器 JSON body 上限提高到 20MB。
- `/media/*` 支援 HTTP Range，Windows 端影片可串流播放與拖曳。
- 聊天影片使用 media_kit 顯示；Windows 支援來自 media_kit。
- 聊天輸入區與個人頁重新整理。


## V1.0.2 媒體修正版
- 媒體 URL 統一由 `BackendConfig.mediaUrl()` 建立。
- 伺服器媒體路由會處理 URL 編碼與 query string。
- `/api/upload` 回傳伺服器版本，方便排查仍在使用舊 Node 行程的情況。
- 若 App 顯示『目前連到舊版伺服器』，請關閉舊的 `npm.cmd start` 視窗後重新啟動 `server`。

## V1.0.3 聊天室／語音房更新

- 每個聊天室各自擁有一個獨立語音房入口，不再把所有語音房塞在聊天室頂部。
- 聊天室有人進入語音後，該聊天室上方顯示「有人正在語音房聊天」與進入按鈕。
- 語音房獨立頁：顯示成員頭像、名稱、麥克風狀態與依音量變化的動態聲波。
- 新增公開聊天室：建立、加入、退出。大廳不可退出。
- 聊天室訊息可編輯／刪除；私訊也可編輯／刪除自己的訊息。
- 聊天室支援照片、影片、貼圖與 emoji。
- 語音房與聊天室狀態使用 WebSocket 即時同步。

## V1.0.4 Mobile + Voice UX

- AppShell now switches to NavigationRail on wide screens and NavigationBar on mobile.
- Headings use a handwritten Chinese display font via `google_fonts` while body text stays readable.
- Every chat context has a default voice room, including the lobby. No separate "create voice room" step is required.
- Chat voice room uses `channel:lobby` for the lobby and `channel:<chatRoomId>` for custom chat rooms.
- Run `setup_mobile.ps1` on Windows with Flutter installed to generate the Android/iOS platform folders for this source tree.

### Mobile setup

```powershell
./setup_mobile.ps1
flutter pub get
flutter analyze
flutter run -d android
```
