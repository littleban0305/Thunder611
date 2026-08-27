import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/backend_config.dart';

class VoiceRoomPage extends StatelessWidget {
  final ThunderAppState state;
  final String roomType;
  final String roomId;
  final String title;

  const VoiceRoomPage({
    super.key,
    required this.state,
    required this.roomType,
    required this.roomId,
    required this.title,
  });

  List<Map<String, dynamic>> get users {
    if (roomType == 'channel') return state.voiceUsersForRoom(roomId);
    return state.voiceUsers.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool get joined => state.voice.active && state.voice.roomType == roomType && state.voice.roomId == roomId;

  Future<void> toggle() async {
    if (joined) {
      await state.stopVoice();
    } else {
      await state.toggleVoice(roomType, roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = users;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            tooltip: '離開',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111117),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      joined ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          joined ? '你正在語音房裡' : '語音房',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${people.length} 人在線 · ${state.voice.muted ? '已靜音' : joined ? '麥克風開啟' : '尚未加入'}',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: toggle,
                    icon: Icon(joined ? Icons.call_end_rounded : Icons.mic_rounded),
                    label: Text(joined ? '離開' : '加入'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: people.isEmpty
                  ? const Center(
                      child: Text(
                        '還沒有人在這裡。\n成為第一個加入的人吧。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, height: 1.5),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        childAspectRatio: 0.94,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: people.length,
                      itemBuilder: (_, index) {
                        final person = people[index];
                        return _VoicePersonCard(person: person);
                      },
                    ),
            ),
            if (joined)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: state.toggleVoiceMute,
                      icon: Icon(
                        state.voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      ),
                      label: Text(state.voice.muted ? '解除靜音' : '靜音'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.stopVoice,
                      icon: const Icon(Icons.call_end_rounded),
                      label: const Text('離開語音'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _VoicePersonCard extends StatelessWidget {
  final Map<String, dynamic> person;

  const _VoicePersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final name = '${person['name'] ?? '?'}';
    final avatar = '${person['avatarUrl'] ?? ''}';
    final level = ((person['level'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    final muted = person['muted'] == true;
    final talking = level > 0.08 && !muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: talking
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13)
            : const Color(0xFF111117),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: talking
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (talking)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 72 + level * 18,
                    height: 72 + level * 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25 + level * 0.5),
                        width: 4,
                      ),
                    ),
                  ),
                CircleAvatar(
                  radius: 31,
                  backgroundColor: const Color(0xFF262430),
                  backgroundImage: avatar.isEmpty
                      ? null
                      : NetworkImage(BackendConfig.mediaUrl(avatar)),
                  child: avatar.isEmpty
                      ? Text(
                          name.isEmpty ? '?' : name.substring(0, 1),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 15,
                color: muted ? Colors.white30 : Colors.greenAccent,
              ),
              const SizedBox(width: 4),
              Text(
                talking ? '正在說話' : muted ? '已靜音' : '在線',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          if (talking) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 72,
              height: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (index) {
                  final factor = switch (index) {
                    0 => 0.45,
                    1 => 0.8,
                    2 => 1.0,
                    3 => 0.7,
                    _ => 0.5,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 5,
                      height: 5 + level * 13 * factor,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
