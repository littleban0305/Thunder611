# 雷霆611 V0.8 Server

V0.8 是目前的完整多人社群開發版：SQLite + WebSocket + Token 登入 + 好友 + 金幣互動 + 純文字狼人殺。

## 啟動

需要 Node.js 18+。

```powershell
cd server
npm.cmd install
npm.cmd start
```

伺服器：
- HTTP：`http://127.0.0.1:6110`
- WebSocket：`ws://127.0.0.1:6110`
- SQLite：`server/data/thunder611.sqlite`

第一次啟動會建立 SQLite 資料庫。如果舊版存在 `server/data/users.json`，V0.8 仍會嘗試匯入。

## V0.8 功能

### 社群
- Token 驗證的 WebSocket 登入
- 在線成員同步
- 好友邀請／接受／拒絕／刪除
- 好友邀請通知持久化
- 狼人殺房間邀請

### 金幣
- 聊天 +2 金幣
- 私訊 +1 金幣
- 每日簽到 +10 金幣
- 真心話大冒險固定 +100 金幣
- 每日小遊戲固定 +50 金幣
- 狼人殺勝者 +500、其他參與者 +100
- 金幣轉帳
- 偷金幣卡：消耗道具、隨機偷取 5%～15%，單次最多 2000
- 防盜護盾：被偷時自動擋一次

### 道具
- 偷金幣卡：`steal`
- 防盜護盾：`shield`
- 身份探測器：`scan`
- 幸運骰子：`dice`
- 金幣磁鐵：`magnet`
- 神秘箱：`box`
- 商店價格由伺服器端固定，不能由客戶端改價
- 背包數量由 SQLite 保存

### 狼人殺
- 純文字社交推理
- 4～10 人
- 房主開房／邀請／開始
- 狼人、預言家、守衛、村民
- 夜晚行動、白天發言、投票、出局、勝負
- 角色資訊只回傳給本人，遊戲結束才公開全部身份
- 身份探測器可以在狼人殺房間內使用

## 區網測試

伺服器電腦：

```powershell
ipconfig
```

其他電腦：

```powershell
flutter run -d windows --dart-define=THUNDER611_HOST=192.168.1.20
```

請確認 Windows 防火牆允許 TCP 6110。

## 開發注意

這仍然是開發版，不建議直接暴露到公網。正式部署前應加入 HTTPS/WSS、反向代理、正式 session/JWT 管理、限流、內容審核、備份與更嚴格的權限控管。


V0.8：加入真心話房間、房內語音轉送、通知中心事件。
