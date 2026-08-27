class BackendConfig {
  // 啟動 Flutter 時可用：
  // flutter run -d windows --dart-define=THUNDER611_HOST=192.168.1.10
  static const String host = String.fromEnvironment(
    'THUNDER611_HOST',
    defaultValue: '192.168.50.21',
  );
  static const int port = int.fromEnvironment(
    'THUNDER611_PORT',
    defaultValue: 6110,
  );

  static String get httpBaseUrl => 'http://$host:$port';
  static String get wsUrl => 'ws://$host:$port';

  static String mediaUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$httpBaseUrl$raw';
    return '$httpBaseUrl/$raw';
  }
}
