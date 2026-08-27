
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mp_audio_stream/mp_audio_stream.dart';
import 'package:record/record.dart';

import 'realtime_service.dart';

typedef VoiceStateChanged = void Function(bool active, bool muted, String? error);

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioStream _player = getAudioStream();

  StreamSubscription<Uint8List>? _captureSubscription;
  VoiceStateChanged? _onStateChanged;

  bool active = false;
  bool muted = false;
  double level = 0;
  String? error;
  DateTime _lastLevelSent = DateTime.fromMillisecondsSinceEpoch(0);
  String? roomType;
  String? roomId;

  Future<void> start({
    required RealtimeService realtime,
    required String roomType,
    required String roomId,
    required VoiceStateChanged onStateChanged,
  }) async {
    await stop(realtime: realtime, notify: false);
    _onStateChanged = onStateChanged;
    this.roomType = roomType;
    this.roomId = roomId;
    error = null;

    try {
      final permitted = await _recorder.hasPermission();
      if (!permitted) {
        throw Exception('無法使用麥克風，請確認 Windows 麥克風權限。');
      }

      _player.init(channels: 1, sampleRate: 44100);
      _player.resume();

      realtime.send({
        'type': 'voice.join',
        'roomType': roomType,
        'roomId': roomId,
      });

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );

      _captureSubscription = stream.listen((chunk) {
        if (!active || chunk.isEmpty) return;
        final now = DateTime.now();
        if (!muted) {
          realtime.sendBinary(chunk);
          if (now.difference(_lastLevelSent).inMilliseconds >= 120) {
            var sum = 0.0;
            final bytes = ByteData.sublistView(chunk);
            final count = chunk.length ~/ 2;
            for (var i = 0; i < count; i++) {
              final sample = bytes.getInt16(i * 2, Endian.little) / 32768.0;
              sum += sample * sample;
            }
            final rms = count == 0 ? 0.0 : (sum / count) * 100;
            level = rms.clamp(0.0, 1.0);
            realtime.send({
              'type': 'voice.level',
              'level': level,
            });
            _lastLevelSent = now;
          }
        } else if (now.difference(_lastLevelSent).inMilliseconds >= 200) {
          level = 0;
          realtime.send({'type': 'voice.level', 'level': 0});
          _lastLevelSent = now;
        }
      });

      active = true;
      muted = false;
      _onStateChanged?.call(active, muted, null);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      active = false;
      try {
        realtime.send({'type': 'voice.leave'});
      } catch (_) {}
      _player.uninit();
      _onStateChanged?.call(false, false, error);
    }
  }

  Future<void> stop({
    required RealtimeService realtime,
    bool notify = true,
  }) async {
    try {
      await _captureSubscription?.cancel();
    } catch (_) {}
    _captureSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    if (realtime.connected) {
      realtime.send({'type': 'voice.leave'});
    }

    try {
      _player.uninit();
    } catch (_) {}

    active = false;
    muted = false;
    level = 0;
    roomType = null;
    roomId = null;

    if (notify) _onStateChanged?.call(false, false, null);
  }

  void setMuted(RealtimeService realtime, bool value) {
    muted = value;
    realtime.send({'type': 'voice.mute', 'muted': value});
    _onStateChanged?.call(active, muted, null);
  }

  void handleBinary(Uint8List data) {
    if (data.length < 4) return;
    final headerLength = ByteData.sublistView(data, 0, 4).getUint32(0);
    if (headerLength <= 0 || data.length < 4 + headerLength) return;

    try {
      final header = jsonDecode(
        utf8.decode(data.sublist(4, 4 + headerLength)),
      );
      if (header is! Map) return;
      final sender = '${header['sender'] ?? ''}';
      if (sender.isEmpty) return;

      final pcm = data.sublist(4 + headerLength);
      if (pcm.length < 2) return;
      final samples = Float32List(pcm.length ~/ 2);
      final bytes = ByteData.sublistView(pcm);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = bytes.getInt16(i * 2, Endian.little) / 32768.0;
      }
      _player.push(samples);
    } catch (_) {}
  }

  void dispose() {
    _captureSubscription?.cancel();
    _recorder.dispose();
    try {
      _player.uninit();
    } catch (_) {}
  }
}
