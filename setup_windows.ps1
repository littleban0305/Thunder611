# 在專案根目錄執行一次，即可補上 Windows Desktop 專案檔案。
flutter config --enable-windows-desktop
flutter create --platforms=windows .
flutter pub get
flutter analyze
