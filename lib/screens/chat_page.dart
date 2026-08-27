import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app_state.dart';
import '../services/backend_config.dart';
import 'voice_room_page.dart';

class ChatPage extends StatefulWidget {
  final ThunderAppState state;

  const ChatPage({super.key, required this.state});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  String? selectedPrivate;

  ThunderAppState get state => widget.state;

  String? get activeRoomId => selectedPrivate == null ? state.activeChatRoomId : null;

  List<ChatMessage> get activeMessages {
    if (selectedPrivate != null) {
      return state.privateMessages[selectedPrivate!] ?? const [];
    }
    if (activeRoomId != null) {
      return state.chatMessagesForRoom(activeRoomId!);
    }
    return state.chatMessages;
  }

  String get activeTitle {
    if (selectedPrivate != null) return selectedPrivate!;
    if (activeRoomId != null) {
      final room = state.chatRooms.firstWhere(
        (item) => '${item['id']}' == activeRoomId,
        orElse: () => <String, dynamic>{'name': '聊天室'},
      );
      return '${room['name'] ?? '聊天室'}';
    }
    return '大廳';
  }

  String get activeScope {
    if (selectedPrivate != null) return 'private';
    if (activeRoomId != null) return 'room';
    return 'lobby';
  }

  void send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (selectedPrivate != null) {
      state.sendPrivate(selectedPrivate!, text);
    } else if (activeRoomId != null) {
      state.sendChatRoom(activeRoomId!, text);
    } else {
      state.sendLobby(text);
    }
    controller.clear();
  }

  Future<void> pickMedia() async {
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
    if (!mounted || result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      _show('檔案太大，單檔上限 10MB');
      return;
    }
    final ext = (file.extension ?? 'bin').toLowerCase();
    final isVideo = ['mp4', 'mov', 'webm', 'm4v'].contains(ext);
    _show('正在上傳 ${file.name}…');
    await state.sendMedia(
      kind: isVideo ? 'video' : 'image',
      target: selectedPrivate,
      roomId: activeRoomId,
      dataBase64: base64Encode(file.bytes!),
      ext: ext,
      caption: file.name,
    );
    if (!mounted) return;
    final error = state.lastActionError;
    _show(error ?? '已送出 ${isVideo ? '影片' : '圖片'}');
  }

  void showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151A),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 390,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                controller.text += emoji.emoji;
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
                Navigator.pop(sheetContext);
              },
              config: const Config(
                height: 390,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 30,
                  backgroundColor: Color(0xFF10151A),
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: Color(0xFF0D1115),
                  buttonColor: Color(0xFF1B272C),
                  buttonIconColor: Colors.white70,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: Color(0xFF10151A),
                  buttonIconColor: Colors.white70,
                  hintText: '搜尋 Emoji',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showGifPicker() async {
    final key = const String.fromEnvironment('THUNDER611_GIPHY_KEY');
    final searchController = TextEditingController();
    List<Map<String, String>> gifs = [];
    bool loading = true;
    bool requested = false;
    String query = '';

    Future<void> loadGifs(StateSetter setDialog) async {
      if (key.isEmpty) {
        setDialog(() => loading = false);
        return;
      }
      setDialog(() => loading = true);
      final endpoint = query.trim().isEmpty
          ? Uri.parse('https://api.giphy.com/v1/gifs/trending?api_key=$key&limit=24&rating=pg')
          : Uri.parse('https://api.giphy.com/v1/gifs/search?api_key=$key&q=${Uri.encodeQueryComponent(query.trim())}&limit=24&rating=pg&lang=zh-TW');
      try {
        final response = await http.get(endpoint).timeout(const Duration(seconds: 12));
        final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
        final data = body is Map && body['data'] is List ? body['data'] as List : const [];
        gifs = [];
        for (final item in data) {
          if (item is! Map) continue;
          final images = item['images'];
          if (images is! Map) continue;
          final fixed = images['fixed_width'] ?? images['original'];
          final preview = images['fixed_width_small'] ?? fixed;
          if (fixed is Map && preview is Map) {
            final url = '${fixed['url'] ?? ''}';
            final previewUrl = '${preview['url'] ?? url}';
            if (url.isNotEmpty) gifs.add({'url': url, 'preview': previewUrl});
          }
        }
      } catch (_) {
        gifs = [];
      }
      setDialog(() => loading = false);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151A),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialog) {
            if (loading && gifs.isEmpty && key.isNotEmpty && !requested) {
              requested = true;
              loadGifs(setDialog);
            }
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('GIF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      TextField(
                        controller: searchController,
                        onSubmitted: (value) {
                          query = value;
                          requested = true;
                          loadGifs(setDialog);
                        },
                        decoration: InputDecoration(
                          hintText: key.isEmpty ? '需要設定 GIPHY API Key' : '搜尋 GIF，例如：笑、驚訝、開心',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            onPressed: key.isEmpty
                                ? null
                                : () {
                                    query = searchController.text;
                                    requested = true;
                                    loadGifs(setDialog);
                                  },
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: key.isEmpty
                            ? const Center(
                                child: Text(
                                  '尚未設定 GIPHY API Key\n請用 --dart-define=THUNDER611_GIPHY_KEY=你的Key 啟動',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : loading
                                ? const Center(child: CircularProgressIndicator())
                                : gifs.isEmpty
                                    ? const Center(child: Text('找不到 GIF', style: TextStyle(color: Colors.white54)))
                                    : GridView.builder(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                        itemCount: gifs.length,
                                        itemBuilder: (_, index) {
                                          final gif = gifs[index];
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: () {
                                              state.sendGif(
                                                gif['url']!,
                                                target: selectedPrivate,
                                                roomId: activeRoomId,
                                              );
                                              Navigator.pop(sheetContext);
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: Image.network(gif['preview']!, fit: BoxFit.cover),
                                            ),
                                          );
                                        },
                                      ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Powered by GIPHY', style: TextStyle(fontSize: 10, color: Colors.white30)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  void pickSticker() {
    const stickers = [
      '😂',
      '😭',
      '💀',
      '🔥',
      '👍',
      '❤️',
      '🤡',
      '😎',
      '🗿',
      '🙏',
      '🥹',
      '🐛',
      '🤣',
      '😡',
      '😱',
      '🎉',
      '✨',
      '❤️‍🔥',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stickers
                .map(
                  (sticker) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      state.sendSticker(
                        sticker,
                        target: selectedPrivate,
                      );
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        sticker,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void createPoll() {
    if (activeScope != 'lobby') {
      _show('投票目前只能在大廳發起');
      return;
    }

    final q = TextEditingController();
    final options = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: const Text('發起投票'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: q,
                    decoration: const InputDecoration(labelText: '問題'),
                  ),
                  const SizedBox(height: 10),
                  ...options.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '選項 ${entry.key + 1}',
                            ),
                          ),
                        ),
                      ),
                  TextButton.icon(
                    onPressed: options.length >= 8
                        ? null
                        : () => setDialog(
                              () => options.add(TextEditingController()),
                            ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('增加選項'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final question = q.text.trim();
                  final values = options
                      .map((item) => item.text.trim())
                      .where((value) => value.isNotEmpty)
                      .toList();
                  if (question.isEmpty || values.length < 2) return;
                  state.createPoll(question, values);
                  Navigator.pop(context);
                },
                child: const Text('發布'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateRoomDialog() {
    final roomController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新增聊天室'),
          content: TextField(
            controller: roomController,
            maxLength: 30,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '聊天室名稱',
              hintText: '例如：剪片研究所',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = roomController.text.trim();
                if (name.isEmpty) return;
                state.createChatRoom(name);
                Navigator.pop(dialogContext);
              },
              child: const Text('建立'),
            ),
          ],
        );
      },
    ).whenComplete(roomController.dispose);
  }

  void _showRoomPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F0F15),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '聊天室',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...state.chatRooms.map((room) {
                  final id = '${room['id'] ?? ''}';
                  final name = '${room['name'] ?? id}';
                  final joined = room['joined'] == true;
                  final current = id == activeRoomId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      child: Icon(
                        current
                            ? Icons.forum_rounded
                            : Icons.chat_bubble_outline_rounded,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text('${room['members'] ?? 0} 人'),
                    trailing: FilledButton.tonal(
                      onPressed: joined
                          ? () {
                              state.selectChatRoom(id);
                              Navigator.pop(sheetContext);
                              setState(() => selectedPrivate = null);
                            }
                          : () {
                              state.joinChatRoom(id);
                              setState(() => selectedPrivate = null);
                              Navigator.pop(sheetContext);
                            },
                      child: Text(joined ? '進入' : '加入'),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showCreateRoomDialog();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新增聊天室'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessage(ChatMessage message) {
    final id = (message.payload['id'] as num?)?.toInt();
    if (id == null) return;
    final editController = TextEditingController(text: message.text);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('編輯訊息'),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLength: 500,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                state.editMessage(
                  scope: activeScope,
                  messageId: id,
                  text: editController.text,
                  roomId: activeRoomId,
                  target: selectedPrivate,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    ).whenComplete(editController.dispose);
  }

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final id = (message.payload['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除訊息？'),
          content: const Text('刪除後無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    state.deleteMessage(
      scope: activeScope,
      messageId: id,
      roomId: activeRoomId,
      target: selectedPrivate,
    );
  }

  void _showMessageMenu(ChatMessage message) {
    if (message.sender != state.username) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('編輯'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('刪除'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoom = activeRoomId != null;
    final isChatContext = selectedPrivate == null;
    final voiceRoomId = activeRoomId ?? 'lobby';
    final voiceUsers = isChatContext
        ? state.voiceUsersForRoom(voiceRoomId)
        : const <Map<String, dynamic>>[];
    final inVoice = isChatContext &&
        state.voice.active &&
        state.voice.roomType == 'channel' &&
        state.voice.roomId == voiceRoomId;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      selectedPrivate != null
                          ? '私訊'
                          : isRoom
                              ? '聊天室 · ${voiceUsers.length} 人語音'
                              : '訊息 · 媒體 · 投票',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              if (isRoom)
                IconButton(
                  tooltip: '退出聊天室',
                  onPressed: () async {
                    await state.leaveChatRoom(activeRoomId!);
                    if (!mounted) return;
                    setState(() => selectedPrivate = null);
                  },
                  icon: const Icon(Icons.logout_rounded),
                ),
              IconButton(
                tooltip: '聊天室',
                onPressed: _showRoomPicker,
                icon: const Icon(Icons.forum_outlined),
              ),
              IconButton(
                tooltip: '私訊成員',
                onPressed: () => _pickMember(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: [
              _ModeChip(
                label: '大廳',
                active: selectedPrivate == null && activeRoomId == null,
                onTap: () {
                  state.selectLobbyChat();
                  setState(() => selectedPrivate = null);
                },
              ),
              ...state.chatRooms.where((room) => room['joined'] == true).map(
                    (room) {
                      final id = '${room['id'] ?? ''}';
                      final active = selectedPrivate == null && activeRoomId == id;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ModeChip(
                          label: '${room['name'] ?? id}',
                          active: active,
                          onTap: () {
                            state.selectChatRoom(id);
                            setState(() => selectedPrivate = null);
                          },
                          onClose: () => state.leaveChatRoom(id),
                        ),
                      );
                    },
                  ),
              ...state.privateMessages.keys.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ModeChip(
                        label: name,
                        active: selectedPrivate == name,
                        onTap: () {
                          state.openPrivate(name);
                          setState(() => selectedPrivate = name);
                        },
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton.filledTonal(
                  tooltip: '新增聊天室',
                  onPressed: _showRoomPicker,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
        if (isChatContext)
          _ChannelVoiceBanner(
            state: state,
            roomId: voiceRoomId,
            title: activeTitle,
            users: voiceUsers,
            joined: inVoice,
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            itemCount: activeMessages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (_, i) {
              final message = activeMessages[i];
              final mine = message.sender == state.username;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: _MessageCard(
                  state: state,
                  message: message,
                  mine: mine,
                  onMenu: mine ? () => _showMessageMenu(message) : null,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;

              final actions = [
                IconButton(
                  onPressed: pickMedia,
                  tooltip: '照片／影片',
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                IconButton(
                  onPressed: showEmojiPicker,
                  tooltip: 'Emoji',
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                IconButton(
                  onPressed: showGifPicker,
                  tooltip: 'GIF',
                  icon: const Icon(Icons.gif_box_rounded),
                ),
                IconButton(
                  onPressed: pickSticker,
                  tooltip: '貼圖',
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
                IconButton(
                  onPressed: createPoll,
                  tooltip: '投票',
                  icon: const Icon(Icons.poll_outlined),
                ),
              ];

              final field = TextField(
                controller: controller,
                minLines: 1,
                maxLines: compact ? 4 : 3,
                onSubmitted: (_) => send(),
                decoration: InputDecoration(
                  hintText: selectedPrivate == null
                      ? '發送訊息'
                      : '傳訊給 $selectedPrivate',
                ),
              );

              final sendButton = IconButton.filled(
                onPressed: send,
                tooltip: '發送',
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                ),
              );

              final shell = Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 24,
                      spreadRadius: -12,
                      offset: Offset(0, 10),
                      color: Colors.black54,
                    ),
                  ],
                ),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: field),
                              const SizedBox(width: 6),
                              sendButton,
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 44,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...actions,
                                  const SizedBox(width: 2),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ...actions,
                          Expanded(child: field),
                          const SizedBox(width: 8),
                          sendButton,
                        ],
                      ),
              );

              return shell;
            },
          ),
        ),
      ],
    );
  }

  void _pickMember(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '私訊',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            ...state.members.map(
              (member) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.name.isEmpty ? '?' : member.name.substring(0, 1),
                  ),
                ),
                title: Text(member.name),
                subtitle: Text(member.status),
                onTap: () {
                  Navigator.pop(context);
                  state.openPrivate(member.name);
                  setState(() => selectedPrivate = member.name);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _ChannelVoiceBanner extends StatelessWidget {
  final ThunderAppState state;
  final String roomId;
  final String title;
  final List<Map<String, dynamic>> users;
  final bool joined;

  const _ChannelVoiceBanner({
    required this.state,
    required this.roomId,
    required this.title,
    required this.users,
    required this.joined,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isBusy = users.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isBusy
                ? [
                    primary.withValues(alpha: 0.17),
                    primary.withValues(alpha: 0.05),
                  ]
                : [
                    const Color(0xFF111117),
                    const Color(0xFF0D0D12),
                  ],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: isBusy
                ? primary.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isBusy ? primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isBusy ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                color: isBusy ? primary : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBusy ? '${users.length} 人正在語音房聊天' : '語音房 · 目前沒有人',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    joined ? '已加入 · 點擊查看房內成員' : '每個聊天室都有自己的語音房',
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: users.isEmpty ? 0 : 74,
              child: users.isEmpty
                  ? null
                  : SizedBox(
                      height: 30,
                      child: Stack(
                        children: [
                          for (var i = 0; i < users.take(4).length; i++)
                            Positioned(
                              left: i * 16.0,
                              top: 1,
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor: const Color(0xFF24222D),
                                backgroundImage: '${users[i]['avatarUrl'] ?? ''}'.isEmpty
                                    ? null
                                    : NetworkImage(BackendConfig.mediaUrl('${users[i]['avatarUrl']}')),
                                child: '${users[i]['avatarUrl'] ?? ''}'.isEmpty
                                    ? Text(
                                        '${users[i]['name'] ?? '?'}'.substring(0, 1),
                                        style: const TextStyle(fontSize: 10),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 260),
                    reverseTransitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, animation, __) => FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      child: VoiceRoomPage(
                        state: state,
                        roomType: 'channel',
                        roomId: roomId,
                        title: title,
                      ),
                    ),
                  ),
                );
              },
              child: Text(joined ? '查看' : '進入'),
            ),
          ],
        ),
      ),
    );
  }

}

class _MessageCard extends StatelessWidget {
  final ThunderAppState state;
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onMenu;

  const _MessageCard({
    required this.state,
    required this.message,
    required this.mine,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final payload = message.payload;

    Widget content = switch (message.kind) {
      'image' => _NetworkMedia(
          url: '${payload['url'] ?? ''}',
          width: 280,
          height: 210,
        ),
      'video' => _NetworkVideo(url: '${payload['url'] ?? ''}'),
      'gif' => _NetworkMedia(url: '${payload['url'] ?? ''}', width: 300, height: 220),
      'sticker' => Text(
          '${payload['sticker'] ?? '😂'}',
          style: const TextStyle(fontSize: 54),
        ),
      'poll' => _PollCard(state: state, message: message),
      _ => Text(
          message.text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
    };

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: mine
            ? primary.withValues(alpha: 0.16)
            : const Color(0xFF111117),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.sender,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: mine ? primary : Colors.white54,
                  ),
                ),
              ),
              Text(
                message.time,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white24,
                ),
              ),
              if (mine && onMenu != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onMenu,
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          content,
          if ((message.kind == 'image' || message.kind == 'video') &&
              message.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
          if (message.payload['edited'] == true) ...[
            const SizedBox(height: 4),
            const Text(
              '已編輯',
              style: TextStyle(fontSize: 9, color: Colors.white24),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onLongPress: onMenu,
      child: card,
    );
  }
}

class _NetworkMedia extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _NetworkMedia({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = BackendConfig.mediaUrl(url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        color: Colors.black26,
        child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, size: 34),
                    SizedBox(height: 8),
                    Text(
                      '媒體載入失敗',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NetworkVideo extends StatefulWidget {
  final String url;

  const _NetworkVideo({required this.url});

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;

  String get _fullUrl => BackendConfig.mediaUrl(widget.url);

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }

  Future<void> _open() async {
    try {
      await _player.open(Media(_fullUrl), play: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        height: 190,
        color: Colors.black,
        child: _error != null
            ? const Center(
                child: Icon(Icons.broken_image_outlined, size: 36),
              )
            : Video(controller: _controller),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final ThunderAppState state;
  final ChatMessage message;

  const _PollCard({required this.state, required this.message});

  @override
  Widget build(BuildContext context) {
    final question = '${message.payload['question'] ?? message.text}';
    final options = (message.payload['options'] is List)
        ? List<String>.from(
            (message.payload['options'] as List).map((e) => '$e'),
          )
        : const <String>[];

    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: OutlinedButton(
                onPressed: () {
                  final id = (message.payload['id'] as num?)?.toInt();
                  if (id != null) state.votePoll(id, i);
                },
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(40),
                ),
                child: Text(options[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
          : const Color(0xFF111117),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 5),
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded, size: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
