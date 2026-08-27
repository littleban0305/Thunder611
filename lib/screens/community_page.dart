import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/backend_config.dart';
import '../widgets/section_card.dart';
import 'admin_page.dart';
import 'chat_page.dart';

class CommunityPage extends StatefulWidget {
  final ThunderAppState state;

  const CommunityPage({
    super.key,
    required this.state,
  });

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  ThunderAppState get state => widget.state;

  @override
  void initState() {
    super.initState();

    state.loadCommunityData();
    state.loadMemories();
  }

  Future<void> addMemory() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'mp4',
        'mov',
        'webm',
        'm4v',
      ],
    );

    if (!mounted) return;

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final file = result.files.single;

    if (file.size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('單檔上限 10MB'),
        ),
      );
      return;
    }

    final captionController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('加入回憶'),
          content: TextField(
            controller: captionController,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: '一句話（可留空）',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('上傳'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      captionController.dispose();
      return;
    }

    if (ok != true) {
      captionController.dispose();
      return;
    }

    final ext = (file.extension ?? 'jpg').toLowerCase();

    final kind = <String>[
      'mp4',
      'mov',
      'webm',
      'm4v',
    ].contains(ext)
        ? 'video'
        : 'image';

    state.addMemory(
      kind: kind,
      dataBase64: base64Encode(file.bytes!),
      ext: ext,
      caption: captionController.text.trim(),
    );

    captionController.dispose();
  }

  Future<void> refreshCommunity() async {
    state.loadCommunityData();
    state.loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '社群',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (state.isAdmin)
            IconButton(
              tooltip: '管理員後台',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminPage(
                      state: state,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.admin_panel_settings_outlined,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshCommunity,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            28,
          ),
          children: [
            _buildAnnouncements(),
            const SizedBox(height: 18),
            _buildMemories(),
            const SizedBox(height: 18),
            _buildLeaderboard(),
            const SizedBox(height: 18),
            _buildVoiceRooms(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('班級公告'),
        const SizedBox(height: 10),
        if (state.announcements.isEmpty)
          const SectionCard(
            child: Text(
              '目前沒有公告',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          )
        else
          ...state.announcements.map(
            (announcement) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            announcement.time,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        announcement.body,
                        style: const TextStyle(
                          color: Colors.white60,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMemories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle('班級回憶'),
            ),
            FilledButton.tonalIcon(
              onPressed: state.realtimeConnected ? addMemory : null,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
              ),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (state.memories.isEmpty)
          const SectionCard(
            child: Text(
              '還沒有回憶',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemCount: state.memories.length,
            itemBuilder: (
              context,
              index,
            ) {
              final memory = state.memories[index];

              Widget content;

              if (memory.kind == 'image') {
                content = Image.network(
                  BackendConfig.mediaUrl(memory.url),
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                      ),
                    );
                  },
                );
              } else {
                content = const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    size: 42,
                  ),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: const Color(0xFF111117),
                  child: content,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('完整排行榜'),
        const SizedBox(height: 10),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (state.leaderboard.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    '目前沒有排行榜資料',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                )
              else
                for (var i = 0; i < state.leaderboard.length; i++)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      child: Text(
                        '${i + 1}',
                      ),
                    ),
                    title: Text(
                      '${state.leaderboard[i]['name'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '勝場 ${state.leaderboard[i]['wins'] ?? 0} · '
                      '聊天 ${state.leaderboard[i]['chatCount'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                    trailing: Text(
                      '${state.leaderboard[i]['coins'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onTap: () => _memberActions(
                      context,
                      '${state.leaderboard[i]['name'] ?? ''}',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceRooms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('公共語音房'),
        const SizedBox(height: 10),
        if (state.voiceRooms.isEmpty)
          const SectionCard(
            child: Text(
              '目前沒有語音房',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          )
        else
          ...state.voiceRooms.map(
            (room) {
              final roomId = '${room['id']}';
              final roomName = '${room['name'] ?? roomId}';
              final userCount = '${room['users'] ?? 0}';
              final locked = room['locked'] == true;

              final inThisRoom =
                  state.voice.active && state.voice.roomId == roomId;

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: SectionCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roomName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$userCount 人'
                              '${locked ? ' · 已鎖定' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: locked && !state.isAdmin
                            ? null
                            : () {
                                if (inThisRoom) {
                                  state.stopVoice();
                                } else {
                                  state.joinGlobalVoice(
                                    roomId,
                                  );
                                }
                              },
                        child: Text(
                          inThisRoom ? '離開' : '加入',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        if (state.voice.active)
          SectionCard(
            child: Row(
              children: [
                Icon(
                  state.voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.greenAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已加入 ${state.voice.roomId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: state.toggleVoiceMute,
                  icon: Icon(
                    state.voice.muted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                  ),
                ),
                IconButton(
                  onPressed: state.stopVoice,
                  icon: const Icon(
                    Icons.call_end_rounded,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _memberActions(BuildContext context, String target) {
    if (target.isEmpty || target == state.username) return;
    final isFriend = state.friends.any((friend) => friend.name == target);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
              title: Text(target,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('成員操作'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('私訊'),
              onTap: () {
                Navigator.pop(sheetContext);
                state.openPrivate(target);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ChatPage(state: state, initialPrivate: target)));
              },
            ),
            ListTile(
              leading: Icon(isFriend
                  ? Icons.person_remove_outlined
                  : Icons.person_add_alt_1_rounded),
              title: Text(isFriend ? '刪除好友' : '加好友'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (isFriend) {
                  state.removeFriend(target);
                } else {
                  state.sendFriendRequest(target);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
