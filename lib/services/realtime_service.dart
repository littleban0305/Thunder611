import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_config.dart';

typedef RealtimeEventHandler = void Function(Map<String, dynamic> event);
typedef RealtimeBinaryHandler = void Function(Uint8List data);

class RealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  RealtimeEventHandler? _handler;
  RealtimeBinaryHandler? _binaryHandler;

  bool get connected => _channel != null;

  Future<void> connect({
    required String username,
    required String token,
    required RealtimeEventHandler onEvent,
    RealtimeBinaryHandler? onBinary,
  }) async {
    disconnect();
    _handler = onEvent;
    _binaryHandler = onBinary;
    final channel = WebSocketChannel.connect(Uri.parse(BackendConfig.wsUrl));
    _channel = channel;

    _subscription = channel.stream.listen(
      (raw) {
        if (raw is Uint8List) {
          _binaryHandler?.call(raw);
          return;
        }
        if (raw is List<int>) {
          _binaryHandler?.call(Uint8List.fromList(raw));
          return;
        }
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is Map) {
            _handler?.call(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
      onDone: () => _channel = null,
      onError: (_, __) => _channel = null,
      cancelOnError: true,
    );

    await channel.ready;
    send({
      'type': 'presence.join',
      'username': username,
      'token': token,
    });
  }

  void send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  void sendBinary(Uint8List data) {
    final channel = _channel;
    if (channel == null || data.isEmpty) return;
    channel.sink.add(data);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
