# 雷霆社群 / Thunder Community 手機版

這個版本已經把 UI 做成手機優先、寬螢幕自動切換的結構：

- 手機：底部 NavigationBar
- 平板／桌面：NavigationRail
- 聊天室：每個聊天室（包含大廳）都自帶一個語音房
- 不需要另外「建立語音房」；聊天室建立時，語音房邏輯同步存在
- 手機上聊天與語音頁會使用更緊湊的卡片、間距與動畫
- 標題與大字使用手寫中文字體風格，內文維持可讀性

Windows 上第一次建立手機平台：

```powershell
./setup_mobile.ps1
flutter pub get
flutter analyze
flutter run -d android
```

iOS：

```bash
flutter pub get
flutter analyze
flutter run -d ios
```

語音房第一次使用時，Android 需要麥克風權限；iOS 會詢問麥克風用途。
