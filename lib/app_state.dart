import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'services/backend_config.dart';
import 'services/local_store.dart';
import 'services/realtime_service.dart';
import 'services/voice_service.dart';

class Member {
  final String name;
  final String displayName;
  final bool online;
  final String status;
  final int coins;

  const Member({
    required this.name,
    this.displayName = '',
    required this.online,
    required this.status,
    required this.coins,
  });
}

class ChatMessage {
  final String sender;
  final String text;
  final String time;
  final String? clientId;
  final String kind;
  final Map<String, dynamic> payload;

  const ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    this.clientId,
    this.kind = 'text',
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'time': time,
        'kind': kind,
        'payload': payload,
        if (clientId != null) 'clientId': clientId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        sender: '${json['sender'] ?? ''}',
        text: '${json['text'] ?? ''}',
        time: '${json['time'] ?? ''}',
        clientId: json['clientId']?.toString(),
        kind: '${json['kind'] ?? 'text'}',
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
      );
}

class MemoryItem {
  final int id;
  final String uploader;
  final String kind;
  final String url;
  final String caption;
  final String time;
  const MemoryItem(
      {required this.id,
      required this.uploader,
      required this.kind,
      required this.url,
      required this.caption,
      required this.time});
  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        uploader: '${json['uploader'] ?? ''}',
        kind: '${json['kind'] ?? 'image'}',
        url: '${json['url'] ?? ''}',
        caption: '${json['caption'] ?? ''}',
        time: '${json['time'] ?? ''}',
      );
}

class ShopItem {
  final String id;
  final String name;
  final String icon;
  final String effect;
  final int cost;

  const ShopItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.effect,
    required this.cost,
  });
}

class TransactionItem {
  final String kind;
  final int amount;
  final int balance;
  final String time;

  const TransactionItem({
    required this.kind,
    required this.amount,
    required this.balance,
    required this.time,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        kind: '${json['kind'] ?? ''}',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        time: '${json['time'] ?? ''}',
      );
}

class GameHistoryItem {
  final String gameId;
  final String result;
  final int reward;
  final String time;
  const GameHistoryItem(
      {required this.gameId,
      required this.result,
      required this.reward,
      required this.time});
  factory GameHistoryItem.fromJson(Map<String, dynamic> json) =>
      GameHistoryItem(
        gameId: '${json['gameId'] ?? ''}',
        result: '${json['result'] ?? ''}',
        reward: (json['reward'] as num?)?.toInt() ?? 0,
        time: '${json['time'] ?? ''}',
      );
}

class AnnouncementItem {
  final int id;
  final String title;
  final String body;
  final String time;
  const AnnouncementItem(
      {required this.id,
      required this.title,
      required this.body,
      required this.time});
  factory AnnouncementItem.fromJson(Map<String, dynamic> json) =>
      AnnouncementItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        time: '${json['time'] ?? ''}',
      );
}

class FriendInfo {
  final String name;
  final int coins;
  final int wins;
  final bool online;

  const FriendInfo(
      {required this.name,
      required this.coins,
      required this.wins,
      required this.online});

  factory FriendInfo.fromJson(Map<String, dynamic> json) => FriendInfo(
        name: '${json['name'] ?? ''}',
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        online: json['online'] == true,
      );
}

class FriendRequest {
  final int id;
  final String sender;
  final String target;
  final String status;
  final String time;

  const FriendRequest(
      {required this.id,
      required this.sender,
      required this.target,
      required this.status,
      required this.time});

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: (json['id'] as num?)?.toInt() ?? 0,
        sender: '${json['sender'] ?? ''}',
        target: '${json['target'] ?? ''}',
        status: '${json['status'] ?? 'pending'}',
        time: '${json['time'] ?? ''}',
      );
}

class SocialNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final bool read;
  final String time;

  const SocialNotification(
      {required this.id,
      required this.type,
      required this.payload,
      required this.read,
      required this.time});

  factory SocialNotification.fromJson(Map<String, dynamic> json) =>
      SocialNotification(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: '${json['type'] ?? ''}',
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : <String, dynamic>{},
        read: json['read'] == true,
        time: '${json['time'] ?? ''}',
      );
}

class WerewolfPlayer {
  final String name;
  final bool alive;
  final bool connected;
  final String? role;
  final bool bot;

  const WerewolfPlayer({
    required this.name,
    required this.alive,
    required this.connected,
    this.role,
    this.bot = false,
  });

  factory WerewolfPlayer.fromJson(Map<String, dynamic> json) => WerewolfPlayer(
        name: '${json['name'] ?? ''}',
        alive: json['alive'] == true,
        connected: json['connected'] == true,
        role: json['role']?.toString(),
        bot: json['bot'] == true,
      );
}

class WerewolfRoomMessage {
  final String sender;
  final String text;
  final String time;

  const WerewolfRoomMessage({
    required this.sender,
    required this.text,
    required this.time,
  });

  factory WerewolfRoomMessage.fromJson(Map<String, dynamic> json) =>
      WerewolfRoomMessage(
        sender: '${json['sender'] ?? ''}',
        text: '${json['text'] ?? ''}',
        time: '${json['time'] ?? ''}',
      );
}

class WerewolfRoomState {
  final String roomId;
  final String host;
  final String phase;
  final String? nightStep;
  final DateTime? phaseEndsAt;
  final int? phaseDurationSeconds;
  final String? speaker;
  final bool myTurn;
  final int round;
  final int maxPlayers;
  final List<WerewolfPlayer> players;
  final String? myRole;
  final bool myAlive;
  final List<WerewolfRoomMessage> messages;
  final Map<String, int>? voteCounts;
  final String? myVote;
  final String? witchVictim;
  final bool witchHasAntidote;
  final bool witchHasPoison;
  final String? winner;

  const WerewolfRoomState({
    required this.roomId,
    required this.host,
    required this.phase,
    required this.nightStep,
    required this.phaseEndsAt,
    required this.phaseDurationSeconds,
    required this.speaker,
    required this.myTurn,
    required this.round,
    required this.maxPlayers,
    required this.players,
    required this.myRole,
    required this.myAlive,
    required this.messages,
    required this.voteCounts,
    required this.myVote,
    required this.witchVictim,
    required this.witchHasAntidote,
    required this.witchHasPoison,
    required this.winner,
  });

  factory WerewolfRoomState.fromJson(Map<String, dynamic> json) =>
      WerewolfRoomState(
        roomId: '${json['roomId'] ?? ''}',
        host: '${json['host'] ?? ''}',
        phase: '${json['phase'] ?? 'lobby'}',
        nightStep: json['nightStep']?.toString(),
        phaseEndsAt: json['phaseEndsAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['phaseEndsAt'] as num).toInt())
            : DateTime.tryParse('${json['phaseEndsAt'] ?? ''}'),
        phaseDurationSeconds: (json['phaseDurationSeconds'] as num?)?.toInt(),
        speaker: json['speaker']?.toString(),
        myTurn: json['myTurn'] == true,
        round: (json['round'] as num?)?.toInt() ?? 0,
        maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 8,
        players: (json['players'] is List)
            ? (json['players'] as List)
                .whereType<Map>()
                .map((e) =>
                    WerewolfPlayer.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        myRole: json['myRole']?.toString(),
        myAlive: json['myAlive'] == true,
        messages: (json['messages'] is List)
            ? (json['messages'] as List)
                .whereType<Map>()
                .map((e) =>
                    WerewolfRoomMessage.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        voteCounts: json['voteCounts'] is Map
            ? Map<String, int>.fromEntries(
                (json['voteCounts'] as Map).entries.map(
                      (entry) => MapEntry(
                        '${entry.key}',
                        (entry.value as num?)?.toInt() ?? 0,
                      ),
                    ),
              )
            : null,
        myVote: json['myVote']?.toString(),
        witchVictim: json['witchVictim']?.toString(),
        witchHasAntidote: json['witchHasAntidote'] == true,
        witchHasPoison: json['witchHasPoison'] == true,
        winner: json['winner']?.toString(),
      );
}

class TruthRoomPlayer {
  final String name;
  final bool connected;
  final bool selected;

  const TruthRoomPlayer({
    required this.name,
    required this.connected,
    required this.selected,
  });

  factory TruthRoomPlayer.fromJson(Map<String, dynamic> json) =>
      TruthRoomPlayer(
        name: '${json['name'] ?? ''}',
        connected: json['connected'] == true,
        selected: json['selected'] == true,
      );
}

class TruthRoomMessage {
  final String sender;
  final String text;
  final String time;

  const TruthRoomMessage({
    required this.sender,
    required this.text,
    required this.time,
  });

  factory TruthRoomMessage.fromJson(Map<String, dynamic> json) =>
      TruthRoomMessage(
        sender: '${json['sender'] ?? ''}',
        text: '${json['text'] ?? ''}',
        time: '${json['time'] ?? ''}',
      );
}

class TruthRoomState {
  final String roomId;
  final String host;
  final String phase;
  final int maxPlayers;
  final List<TruthRoomPlayer> players;
  final String? selected;
  final String? choice;
  final String? prompt;
  final List<TruthRoomMessage> messages;

  const TruthRoomState({
    required this.roomId,
    required this.host,
    required this.phase,
    required this.maxPlayers,
    required this.players,
    required this.selected,
    required this.choice,
    required this.prompt,
    required this.messages,
  });

  factory TruthRoomState.fromJson(Map<String, dynamic> json) => TruthRoomState(
        roomId: '${json['roomId'] ?? ''}',
        host: '${json['host'] ?? ''}',
        phase: '${json['phase'] ?? 'lobby'}',
        maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 8,
        players: (json['players'] is List)
            ? (json['players'] as List)
                .whereType<Map>()
                .map((e) =>
                    TruthRoomPlayer.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        selected: json['selected']?.toString(),
        choice: json['choice']?.toString(),
        prompt: json['prompt']?.toString(),
        messages: (json['messages'] is List)
            ? (json['messages'] as List)
                .whereType<Map>()
                .map((e) =>
                    TruthRoomMessage.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

class ThunderAppState extends ChangeNotifier {
  ThunderAppState({required this.username, LocalStore? store})
      : store = store ?? LocalStore() {
    final now = DateTime.now();
    chatMessages = [
      ChatMessage(
        sender: '阿偉',
        text: '有人晚上要玩嗎？',
        time: _time(now.subtract(const Duration(minutes: 2))),
      ),
      ChatMessage(
        sender: '小明',
        text: '我八點在',
        time: _time(now.subtract(const Duration(minutes: 1))),
      ),
      ChatMessage(sender: username, text: '狼人殺我可以', time: _time(now)),
    ];
    privateMessages = {};
    _restore();
  }

  final String username;
  final LocalStore store;
  final RealtimeService realtime = RealtimeService();
  final VoiceService voice = VoiceService();
  final Random _random = Random();

  int coins = 1250;
  int wins = 0;
  bool checkedIn = false;
  bool restoring = true;
  bool realtimeConnected = false;

  final Map<String, int> inventory = {};
  late List<ChatMessage> chatMessages;
  late Map<String, List<ChatMessage>> privateMessages;
  List<TransactionItem> transactionsList = const [];
  List<GameHistoryItem> gameHistory = const [];
  List<AnnouncementItem> announcements = const [];
  List<Map<String, dynamic>> leaderboard = const [];
  List<Map<String, dynamic>> voiceRooms = const [];
  List<Map<String, dynamic>> chatRooms = const [];
  final Map<String, List<ChatMessage>> channelMessages = {};
  final Map<String, List<Map<String, dynamic>>> channelVoiceUsers = {};
  String? _activeChatRoomId;
  String selectedTitle = '新手';
  String selectedFrame = 'default';
  List<FriendInfo> friends = const [];
  List<FriendRequest> friendRequests = const [];
  List<SocialNotification> notifications = const [];
  String? lastNotificationText;
  WerewolfRoomState? werewolfRoom;
  List<Map<String, dynamic>> werewolfRooms = const [];
  String? werewolfInspectTarget;
  bool? werewolfInspectIsWolf;
  bool werewolfHunterAvailable = false;
  List<String> werewolfHunterTargets = const [];
  String? lastActionError;
  final Set<String> itemBusy = <String>{};
  bool werewolfBusy = false;
  bool werewolfVotePending = false;
  TruthRoomState? truthRoom;
  List<Map<String, dynamic>> truthRooms = const [];
  bool truthBusy = false;
  Map<String, dynamic> voiceUsers = const {};
  String? voiceError;
  String avatarUrl = '';
  String displayName = '';
  String bio = '';
  bool isAdmin = false;
  Map<String, dynamic> werewolfStats = const {'total': 0, 'wins': 0, 'rate': 0};
  int chatCount = 0;
  List<MemoryItem> memories = const [];
  List<Map<String, dynamic>> adminUsers = const [];

  List<Member> members = const [];

  final shopItems = const [
    ShopItem(
        id: 'steal', name: '偷金幣卡', icon: '🕵️', effect: '偷取 5%～15%', cost: 800),
    ShopItem(
        id: 'shield', name: '防盜護盾', icon: '🛡️', effect: '擋 1 次偷取', cost: 700),
    ShopItem(
        id: 'scan', name: '身份探測器', icon: '🔍', effect: '獲得模糊提示', cost: 1500),
    ShopItem(id: 'dice', name: '幸運骰子', icon: '🎲', effect: '隨機金幣', cost: 600),
    ShopItem(
        id: 'magnet', name: '金幣磁鐵', icon: '🧲', effect: '獎勵 +30%', cost: 1000),
    ShopItem(id: 'box', name: '神秘箱', icon: '🎁', effect: '隨機道具', cost: 500),
  ];

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _clientId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(100000)}';

  int get onlineCount => members.where((m) => m.online).length + 1;
  int get inventoryCount => inventory.values.fold<int>(0, (a, b) => a + b);

  Future<void> _restore() async {
    final profile = await store.loadProfile(username);
    if (profile.isNotEmpty) {
      coins = (profile['coins'] as num?)?.toInt() ?? coins;
      wins = (profile['wins'] as num?)?.toInt() ?? wins;
      final checkedInDate = profile['checkedInDate']?.toString();
      checkedIn = checkedInDate == _todayKey();
      selectedTitle = '${profile['selectedTitle'] ?? '新手'}';
      selectedFrame = '${profile['selectedFrame'] ?? 'default'}';
      avatarUrl = '${profile['avatarUrl'] ?? ''}';
      displayName = '${profile['displayName'] ?? username}';
      bio = '${profile['bio'] ?? ''}';
      final rawInventory = profile['inventory'];
      if (rawInventory is Map) {
        inventory
          ..clear()
          ..addAll(rawInventory.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as num).toInt(),
            ),
          ));
      }
    }

    final chat = await store.loadChat(username);
    if (chat.isNotEmpty) {
      chatMessages = chat.map(ChatMessage.fromJson).toList();
    }
    final private = await store.loadPrivate(username);
    if (private.isNotEmpty) {
      privateMessages = private.map(
        (key, value) => MapEntry(
          key,
          value.map(ChatMessage.fromJson).toList(),
        ),
      );
    }

    restoring = false;
    notifyListeners();
    await _connectRealtime();
  }

  Future<void> _connectRealtime() async {
    final token = await store.currentToken();
    if (token == null || token.isEmpty) {
      realtimeConnected = false;
      itemBusy.clear();
      notifyListeners();
      return;
    }

    try {
      await realtime.connect(
        username: username,
        token: token,
        onEvent: _handleRealtimeEvent,
        onBinary: voice.handleBinary,
        onConnectionChanged: _handleConnectionChanged,
      );
      realtimeConnected = true;
      notifyListeners();
    } catch (_) {
      realtimeConnected = false;
      itemBusy.clear();
      notifyListeners();
    }
  }

  void _handleConnectionChanged(bool connected) {
    realtimeConnected = connected;
    if (!connected) {
      itemBusy.clear();
      werewolfBusy = false;
      truthBusy = false;
    }
    notifyListeners();
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();

    if (type == 'sync.bootstrap') {
      final profile = event['profile'];
      if (profile is Map) {
        _applyProfile(profile);
        coins = (profile['coins'] as num?)?.toInt() ?? coins;
        wins = (profile['wins'] as num?)?.toInt() ?? wins;
        final rawInventory = profile['inventory'];
        if (rawInventory is Map) {
          inventory
            ..clear()
            ..addAll(rawInventory.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toInt(),
              ),
            ));
        }
      }

      final rawChat = event['chat'];
      if (rawChat is List) {
        chatMessages = rawChat
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final rawChatRooms = event['chatRooms'];
      if (rawChatRooms is List) {
        chatRooms = rawChatRooms
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final rawPrivatePeers = event['privatePeers'];
      if (rawPrivatePeers is List) {
        for (final peer in rawPrivatePeers) {
          final name = '$peer'.trim();
          if (name.isNotEmpty && name != username)
            privateMessages.putIfAbsent(name, () => []);
        }
      }

      _applyMembers(event['members']);
      final rawMemories = event['memories'];
      if (rawMemories is List)
        memories = rawMemories
            .whereType<Map>()
            .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      final rawAnnouncements = event['announcements'];
      if (rawAnnouncements is List)
        announcements = rawAnnouncements
            .whereType<Map>()
            .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      final rawLeaderboard = event['leaderboard'];
      if (rawLeaderboard is List)
        leaderboard = rawLeaderboard
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      final rawVoiceRooms = event['voiceRooms'];
      if (rawVoiceRooms is List)
        voiceRooms = rawVoiceRooms
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      _applyTransactions(event['transactions']);
      _applyGameHistory(event['gameHistory']);
      if (event['werewolfStats'] is Map)
        werewolfStats =
            Map<String, dynamic>.from(event['werewolfStats'] as Map);
      chatCount = (event['chatCount'] as num?)?.toInt() ?? chatCount;
      _applySocial(event);
      loadCommunityData();
      _pushProfile();
      notifyListeners();
      return;
    }

    if (type == 'memories') {
      final raw = event['memories'];
      if (raw is List)
        memories = raw
            .whereType<Map>()
            .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      notifyListeners();
      return;
    }
    if (type == 'memory.added') {
      final raw = event['memory'];
      if (raw is Map)
        memories = [
          MemoryItem.fromJson(Map<String, dynamic>.from(raw)),
          ...memories
        ];
      notifyListeners();
      return;
    }
    if (type == 'chat.poll.updated') {
      final id = (event['messageId'] as num?)?.toInt();
      if (id != null) {
        final index = chatMessages
            .indexWhere((m) => (m.payload['id'] as num?)?.toInt() == id);
        if (index >= 0) {
          final old = chatMessages[index];
          final payload = event['payload'] is Map
              ? Map<String, dynamic>.from(event['payload'] as Map)
              : old.payload;
          chatMessages[index] = ChatMessage(
              sender: old.sender,
              text: old.text,
              time: old.time,
              clientId: old.clientId,
              kind: old.kind,
              payload: payload..['id'] = id);
        }
      }
      notifyListeners();
      return;
    }
    if (type == 'chat.rooms') {
      final raw = event['rooms'];
      if (raw is List)
        chatRooms = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      notifyListeners();
      return;
    }

    if (type == 'chat.room.created') {
      final raw = event['room'];
      if (raw is Map) {
        final room = Map<String, dynamic>.from(raw);
        chatRooms = [
          ...chatRooms.where((r) => '${r['id']}' != '${room['id']}'),
          room
        ];
        _activePrivateTarget = null;
        _activeChatRoomId = '${room['id']}';
        channelMessages.putIfAbsent(_activeChatRoomId!, () => []);
      }
      notifyListeners();
      return;
    }

    if (type == 'chat.room.joined') {
      final roomId = '${event['roomId'] ?? ''}';
      final raw = event['messages'];
      if (roomId.isNotEmpty && raw is List) {
        channelMessages[roomId] = raw
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      chatRooms = chatRooms
          .map((room) => room['id']?.toString() == roomId
              ? {...room, 'joined': true}
              : room)
          .toList();
      _activePrivateTarget = null;
      _activeChatRoomId = roomId;
      notifyListeners();
      return;
    }

    if (type == 'chat.room.left') {
      final roomId = '${event['roomId'] ?? ''}';
      channelMessages.remove(roomId);
      channelVoiceUsers.remove(roomId);
      if (_activeChatRoomId == roomId) _activeChatRoomId = null;
      chatRooms = chatRooms
          .map((room) => room['id']?.toString() == roomId
              ? {...room, 'joined': false}
              : room)
          .toList();
      notifyListeners();
      return;
    }

    if (type == 'chat.room.history') {
      final roomId = '${event['roomId'] ?? ''}';
      final raw = event['messages'];
      if (roomId.isNotEmpty && raw is List) {
        channelMessages[roomId] = raw
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      notifyListeners();
      return;
    }

    if (type == 'chat.room.message') {
      final roomId = '${event['roomId'] ?? ''}';
      if (roomId.isEmpty) return;
      final rawPayload = event['payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};
      final id = (event['id'] as num?)?.toInt();
      if (id != null) payload['id'] = id;
      final message = ChatMessage(
          sender: '${event['sender'] ?? ''}',
          text: '${event['text'] ?? ''}',
          time: '${event['time'] ?? ''}',
          clientId: event['clientId']?.toString(),
          kind: '${event['kind'] ?? 'text'}',
          payload: payload);
      final list = channelMessages.putIfAbsent(roomId, () => []);
      if (message.clientId == null ||
          !list.any((m) => m.clientId == message.clientId)) list.add(message);
      notifyListeners();
      return;
    }

    if (type == 'chat.message.updated' ||
        type == 'chat.room.message.updated' ||
        type == 'private.message.updated') {
      final id = (event['id'] as num?)?.toInt();
      if (id == null) return;
      final newText = '${event['text'] ?? ''}';
      final payload = event['payload'] is Map
          ? Map<String, dynamic>.from(event['payload'] as Map)
          : <String, dynamic>{};
      payload['id'] = id;
      payload['edited'] = true;
      ChatMessage replace(ChatMessage old) => ChatMessage(
          sender: old.sender,
          text: newText,
          time: old.time,
          clientId: old.clientId,
          kind: old.kind,
          payload: payload);
      if (type == 'chat.message.updated') {
        final i = chatMessages
            .indexWhere((m) => (m.payload['id'] as num?)?.toInt() == id);
        if (i >= 0) chatMessages[i] = replace(chatMessages[i]);
      } else if (type == 'private.message.updated') {
        for (final key in privateMessages.keys.toList()) {
          final list = privateMessages[key]!;
          final i =
              list.indexWhere((m) => (m.payload['id'] as num?)?.toInt() == id);
          if (i >= 0) list[i] = replace(list[i]);
        }
      } else {
        final roomId = '${event['roomId'] ?? ''}';
        final list = channelMessages[roomId];
        if (list != null) {
          final i =
              list.indexWhere((m) => (m.payload['id'] as num?)?.toInt() == id);
          if (i >= 0) list[i] = replace(list[i]);
        }
      }
      notifyListeners();
      return;
    }

    if (type == 'chat.message.deleted' ||
        type == 'chat.room.message.deleted' ||
        type == 'private.message.deleted') {
      final id = (event['id'] as num?)?.toInt();
      if (id == null) return;
      if (type == 'chat.message.deleted') {
        chatMessages = chatMessages
            .where((m) => (m.payload['id'] as num?)?.toInt() != id)
            .toList();
      } else if (type == 'private.message.deleted') {
        for (final key in privateMessages.keys.toList()) {
          privateMessages[key] = privateMessages[key]!
              .where((m) => (m.payload['id'] as num?)?.toInt() != id)
              .toList();
        }
      } else {
        final roomId = '${event['roomId'] ?? ''}';
        final list = channelMessages[roomId];
        if (list != null)
          channelMessages[roomId] = list
              .where((m) => (m.payload['id'] as num?)?.toInt() != id)
              .toList();
      }
      notifyListeners();
      return;
    }

    if (type == 'voice.channel.state') {
      final roomId = '${event['roomId'] ?? ''}';
      final rawUsers = event['users'];
      if (roomId.isNotEmpty && rawUsers is List) {
        channelVoiceUsers[roomId] = rawUsers
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      notifyListeners();
      return;
    }

    if (type == 'notification') {
      final raw = event['notification'];
      if (raw is Map) {
        final n = SocialNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            type: '${raw['type'] ?? 'notice'}',
            payload: Map<String, dynamic>.from(raw),
            read: false,
            time: _time(DateTime.now()));
        notifications = [n, ...notifications];
        lastNotificationText = _notificationText(n);
      }
      notifyListeners();
      return;
    }
    if (type == 'profile.avatar.result') {
      avatarUrl = '${event['avatarUrl'] ?? avatarUrl}';
      _persist();
      notifyListeners();
      return;
    }
    if (type == 'profile.updated') {
      _applyProfile(event['profile']);
      lastNotificationText = '個人資料已更新';
      _persist();
      notifyListeners();
      return;
    }
    if (type == 'admin.users') {
      final raw = event['users'];
      if (raw is List)
        adminUsers = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      notifyListeners();
      return;
    }
    if (type == 'banned') {
      lastActionError = '${event['reason'] ?? '帳號已被封禁'}';
      realtime.disconnect();
      realtimeConnected = false;
      itemBusy.clear();
      notifyListeners();
      return;
    }
    if (type == 'presence.snapshot') {
      _applyMembers(event['members']);
      notifyListeners();
      return;
    }

    if (type == 'member.balance') {
      final name = '${event['username'] ?? ''}';
      final amount = (event['coins'] as num?)?.toInt();
      if (amount == null) return;
      members = members.map((member) {
        if (member.name != name) return member;
        return Member(
          name: member.name,
          displayName: member.displayName,
          online: member.online,
          status: member.status,
          coins: amount,
        );
      }).toList();
      notifyListeners();
      return;
    }

    if (type == 'chat.message') {
      final rawPayload = event['payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};
      final id = (event['id'] as num?)?.toInt();
      if (id != null) payload['id'] = id;
      final message = ChatMessage(
        sender: '${event['sender'] ?? ''}',
        text: '${event['text'] ?? ''}',
        time: '${event['time'] ?? ''}',
        clientId: event['clientId']?.toString(),
        kind: '${event['kind'] ?? 'text'}',
        payload: payload,
      );
      if (message.clientId != null &&
          chatMessages.any((item) => item.clientId == message.clientId)) {
        return;
      }
      chatMessages.add(message);
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'private.message') {
      final sender = '${event['sender'] ?? ''}';
      final target = '${event['target'] ?? ''}';
      final peer = sender == username ? target : sender;
      if (peer.isEmpty) return;
      final message = ChatMessage(
        sender: sender,
        text: '${event['text'] ?? ''}',
        time: '${event['time'] ?? ''}',
        clientId: event['clientId']?.toString(),
        kind: '${event['kind'] ?? 'text'}',
        payload: event['payload'] is Map
            ? Map<String, dynamic>.from(event['payload'] as Map)
            : const {},
      );
      privateMessages.putIfAbsent(peer, () => []);
      if (message.clientId == null ||
          !privateMessages[peer]!
              .any((item) => item.clientId == message.clientId)) {
        privateMessages[peer]!.add(message);
      }
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'private.history') {
      final target = '${event['target'] ?? ''}';
      final raw = event['messages'];
      if (target.isNotEmpty && raw is List) {
        privateMessages[target] = raw
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _persist();
        notifyListeners();
      }
      return;
    }

    if (type == 'private.started') {
      final peer = '${event['target'] ?? ''}';
      if (peer.isNotEmpty && peer != username) {
        privateMessages.putIfAbsent(peer, () => []);
        lastNotificationText = '$peer 開始了與你的私訊';
        _persist();
        notifyListeners();
      }
      return;
    }

    if (type == 'balance.update') {
      final target = '${event['username'] ?? ''}';
      if (target == username) {
        coins = (event['coins'] as num?)?.toInt() ?? coins;
        _persist();
        notifyListeners();
      }
      return;
    }

    if (type == 'sync.profile') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'daily.result') {
      final claimed = event['claimed'] == true;
      _applyProfile(event['profile']);
      if (claimed) {
        checkedIn = true;
      }
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'shop.result') {
      itemBusy.remove('${event['itemId'] ?? ''}');
      _applyProfile(event['profile']);
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'game.reward.result') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'social.snapshot') {
      _applySocial(event);
      notifyListeners();
      return;
    }

    if (type == 'leaderboard') {
      final raw = event['members'];
      if (raw is List)
        leaderboard = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      notifyListeners();
      return;
    }
    if (type == 'announcements') {
      final raw = event['announcements'];
      if (raw is List)
        announcements = raw
            .whereType<Map>()
            .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      notifyListeners();
      return;
    }
    if (type == 'game.history') {
      _applyGameHistory(event['games']);
      notifyListeners();
      return;
    }
    if (type == 'voice.rooms') {
      final raw = event['rooms'];
      if (raw is List)
        voiceRooms = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      notifyListeners();
      return;
    }

    if (type == 'notification') {
      final notification = event['notification'];
      if (notification is Map) {
        final map = Map<String, dynamic>.from(notification);
        final kind = '${map['type'] ?? ''}';
        if (kind == 'friend.request') {
          lastNotificationText = '收到 ${map['sender'] ?? ''} 的好友邀請';
        } else if (kind == 'friend.accepted') {
          lastNotificationText = '${map['friend'] ?? ''} 接受了好友邀請';
        } else if (kind == 'werewolf.invite') {
          lastNotificationText =
              '${map['host'] ?? ''} 邀請你加入狼人殺房間 ${map['roomId'] ?? ''}';
        } else if (kind == 'truth.invite') {
          lastNotificationText =
              '${map['host'] ?? ''} 邀請你加入真心話大冒險房間 ${map['roomId'] ?? ''}';
        } else if (kind == 'wallet.received') {
          lastNotificationText =
              '${map['sender'] ?? ''} 轉了 ${map['amount'] ?? 0} 金幣給你';
        } else if (kind == 'wallet.stolen') {
          lastNotificationText =
              '${map['attacker'] ?? ''} 偷走了 ${map['stolen'] ?? 0} 金幣';
        } else if (kind == 'wallet.steal_blocked') {
          lastNotificationText = '${map['attacker'] ?? ''} 想偷你，但護盾擋住了';
        } else {
          lastNotificationText = '收到新通知';
        }
        notifyListeners();
      }
      return;
    }

    if (type == 'friend.result' || type == 'invite.sent') {
      _applySocial(event);
      notifyListeners();
      return;
    }

    if (type == 'wallet.transfer.result') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      lastNotificationText =
          '已轉帳 ${event['amount'] ?? 0} 金幣給 ${event['target'] ?? ''}';
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'wallet.received') {
      final amount = (event['amount'] as num?)?.toInt() ?? 0;
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      lastNotificationText = '${event['sender'] ?? ''} 轉了 $amount 金幣給你';
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'wallet.steal.result') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      lastNotificationText = event['blocked'] == true
          ? '偷金幣失敗：對方的防盜護盾擋住了！'
          : '偷到了 ${event['stolen'] ?? 0} 金幣';
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'wallet.stolen') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      lastNotificationText = event['blocked'] == true
          ? '有人想偷你，但被護盾擋住了！'
          : '${event['attacker'] ?? ''} 偷走了 ${event['stolen'] ?? 0} 金幣';
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'item.result') {
      itemBusy.remove('${event['itemId'] ?? ''}');
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      final itemId = '${event['itemId'] ?? ''}';
      if (itemId == 'dice') {
        lastNotificationText = '幸運骰子：+${event['reward'] ?? 0} 金幣';
      } else if (itemId == 'box') {
        lastNotificationText = '神秘箱開出了 ${event['itemGained'] ?? '道具'}';
      } else if (itemId == 'scan') {
        lastNotificationText =
            '${event['target'] ?? ''}：${event['isWolf'] == true ? '狼人' : '不是狼人'}';
      } else if (event['message'] != null) {
        lastNotificationText = '${event['message']}';
      }
      _persist();
      notifyListeners();
      return;
    }

    if (type == 'truth.created' ||
        type == 'truth.joined' ||
        type == 'truth.state') {
      truthBusy = false;
      lastActionError = null;
      truthRoom = TruthRoomState.fromJson(event);
      notifyListeners();
      return;
    }

    if (type == 'truth.rooms') {
      final raw = event['rooms'];
      if (raw is List) {
        truthRooms = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      notifyListeners();
      return;
    }

    if (type == 'truth.round.reward') {
      _applyProfile(event['profile']);
      _applyTransactions(event['transactions']);
      lastNotificationText = '本輪完成，+${event['reward'] ?? 0} 金幣';
      notifyListeners();
      return;
    }

    if (type == 'truth.left') {
      truthBusy = false;
      truthRoom = null;
      notifyListeners();
      return;
    }

    if (type == 'voice.kicked') {
      if (voice.active && voice.roomId == '${event['roomId'] ?? ''}') {
        voice.stop(realtime: realtime);
        voiceUsers = const {};
      }
      notifyListeners();
      return;
    }

    if (type == 'voice.state') {
      final key = '${event['key'] ?? ''}';
      final currentKey =
          voice.active && voice.roomType != null && voice.roomId != null
              ? '${voice.roomType}:${voice.roomId}'
              : '';
      final rawUsers = event['users'];
      final isCurrentWerewolfVoice =
          voice.roomType == 'werewolf' && key.startsWith('$currentKey:');
      if (key.isNotEmpty &&
          (key == currentKey || isCurrentWerewolfVoice) &&
          rawUsers is List) {
        voiceUsers = {
          for (final item in rawUsers.whereType<Map>())
            '${item['name'] ?? ''}': Map<String, dynamic>.from(item),
        };
      }
      notifyListeners();
      return;
    }

    if (type == 'werewolf.created' || type == 'werewolf.joined') {
      werewolfBusy = false;
      lastActionError = null;
      werewolfRoom = WerewolfRoomState.fromJson(event);
      notifyListeners();
      return;
    }

    if (type == 'werewolf.rooms') {
      final raw = event['rooms'];
      if (raw is List) {
        werewolfRooms = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      notifyListeners();
      return;
    }

    if (type == 'werewolf.state' || type == 'werewolf.ended') {
      werewolfRoom = WerewolfRoomState.fromJson(event);
      final room = werewolfRoom!;
      if (voice.active &&
          voice.roomType == 'werewolf' &&
          voice.roomId == room.roomId &&
          room.phase == 'day' &&
          voice.muted == room.myTurn) {
        voice.setMuted(realtime, !room.myTurn);
      }
      if (werewolfRoom!.phase != 'voting' || werewolfRoom!.myVote != null) {
        werewolfVotePending = false;
      }
      if (type == 'werewolf.ended') {
        _applyProfile(event['profile']);
        _applyTransactions(event['transactions']);
        werewolfHunterAvailable = false;
        werewolfHunterTargets = const [];
        notifyListeners();
      } else {
        notifyListeners();
      }
      return;
    }

    if (type == 'werewolf.inspect') {
      werewolfInspectTarget = event['target']?.toString();
      werewolfInspectIsWolf = event['isWolf'] == true;
      notifyListeners();
      return;
    }

    if (type == 'werewolf.hunter.available') {
      final rawTargets = event['targets'];
      werewolfHunterTargets = rawTargets is List
          ? rawTargets.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [];
      werewolfHunterAvailable = werewolfHunterTargets.isNotEmpty;
      notifyListeners();
      return;
    }

    if (type == 'werewolf.left') {
      werewolfBusy = false;
      werewolfVotePending = false;
      lastActionError = null;
      werewolfRoom = null;
      werewolfInspectTarget = null;
      werewolfInspectIsWolf = null;
      werewolfHunterAvailable = false;
      werewolfHunterTargets = const [];
      notifyListeners();
      return;
    }

    if (type == 'action.error') {
      itemBusy.clear();
      lastActionError = '${event['error'] ?? '操作失敗'}';
      lastNotificationText = lastActionError;
      werewolfBusy = false;
      if (event['action'] == 'werewolf.vote') {
        werewolfVotePending = false;
      }
      notifyListeners();
    }

    if (type == 'auth.error') {
      realtimeConnected = false;
      itemBusy.clear();
      notifyListeners();
    }
  }

  void _applySocial(Map<String, dynamic> raw) {
    final rawFriends = raw['friends'];
    if (rawFriends is List) {
      final onlineNames =
          members.where((m) => m.online).map((m) => m.name).toSet();
      friends = rawFriends.whereType<Map>().map((e) {
        final info = FriendInfo.fromJson(Map<String, dynamic>.from(e));
        return FriendInfo(
            name: info.name,
            coins: info.coins,
            wins: info.wins,
            online: onlineNames.contains(info.name));
      }).toList();
    }
    final rawRequests = raw['requests'];
    if (rawRequests is List) {
      friendRequests = rawRequests
          .whereType<Map>()
          .map((e) => FriendRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final rawNotifications = raw['notifications'];
    if (rawNotifications is List) {
      notifications = rawNotifications
          .whereType<Map>()
          .map((e) => SocialNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  void _applyMembers(dynamic raw) {
    if (raw is! List) return;
    members = raw
        .whereType<Map>()
        .map((e) => Member(
              name: '${e['name'] ?? ''}',
              displayName: '${e['displayName'] ?? e['name'] ?? ''}',
              online: e['online'] == true,
              status: '${e['status'] ?? '在線'}',
              coins: (e['coins'] as num?)?.toInt() ?? 0,
            ))
        .where((m) => m.name.isNotEmpty && m.name != username)
        .toList();
    if (friends.isNotEmpty) {
      final memberMap = {for (final m in members) m.name: m};
      friends = friends.map((friend) {
        final member = memberMap[friend.name];
        return FriendInfo(
            name: friend.name,
            coins: member?.coins ?? friend.coins,
            wins: friend.wins,
            online: member?.online ?? false);
      }).toList();
    }
  }

  void _applyProfile(dynamic raw) {
    if (raw is! Map) return;
    coins = (raw['coins'] as num?)?.toInt() ?? coins;
    wins = (raw['wins'] as num?)?.toInt() ?? wins;
    avatarUrl = '${raw['avatarUrl'] ?? avatarUrl}';
    displayName = '${raw['displayName'] ?? displayName}';
    bio = '${raw['bio'] ?? bio}';
    isAdmin = raw['role'] == 'admin' || raw['isAdmin'] == true;
    final rawInventory = raw['inventory'];
    if (rawInventory is Map) {
      inventory
        ..clear()
        ..addAll(rawInventory.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num).toInt(),
          ),
        ));
    }
  }

  void _applyTransactions(dynamic raw) {
    if (raw is List) {
      transactionsList = raw
          .whereType<Map>()
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  void _applyGameHistory(dynamic raw) {
    if (raw is List) {
      gameHistory = raw
          .whereType<Map>()
          .map((e) => GameHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<void> _persist() async {
    await store.saveProfile(username, {
      'coins': coins,
      'wins': wins,
      'checkedIn': checkedIn,
      'checkedInDate': checkedIn ? _todayKey() : '',
      'inventory': inventory,
      'selectedTitle': selectedTitle,
      'selectedFrame': selectedFrame,
      'avatarUrl': avatarUrl,
    });
    await store.saveChat(
      username,
      chatMessages.map((e) => e.toJson()).toList(),
    );
    await store.savePrivate(
      username,
      privateMessages.map(
        (key, value) => MapEntry(
          key,
          value.map((e) => e.toJson()).toList(),
        ),
      ),
    );
  }

  void _pushProfile() {
    // Profile is already sent in sync.bootstrap; this marker keeps local
    // persistence and server state separate.
    _persist();
  }

  void _syncBalanceOffline() {
    notifyListeners();
    _persist();
  }

  void earn(int amount) {
    coins += amount;
    _syncBalanceOffline();
  }

  bool claimDaily() {
    if (realtimeConnected) {
      realtime.send({'type': 'wallet.claim_daily'});
      return true;
    }
    if (checkedIn) return false;
    checkedIn = true;
    coins += 10;
    _syncBalanceOffline();
    return true;
  }

  String? _activePrivateTarget;

  String? get activePrivateTarget => _activePrivateTarget;

  String? get activeChatRoomId => _activeChatRoomId;

  List<ChatMessage> chatMessagesForRoom(String roomId) =>
      channelMessages[roomId] ?? const [];

  List<Map<String, dynamic>> voiceUsersForRoom(String roomId) =>
      channelVoiceUsers[roomId] ?? const [];

  void selectChatRoom(String roomId) {
    final room = chatRooms.firstWhere(
      (r) => '${r['id']}' == roomId,
      orElse: () => <String, dynamic>{},
    );
    if (room.isEmpty || room['joined'] != true) return;
    _activePrivateTarget = null;
    _activeChatRoomId = roomId;
    if (realtimeConnected)
      realtime.send({'type': 'chat.room.history', 'roomId': roomId});
    notifyListeners();
  }

  void createChatRoom(String name, {bool isPublic = true}) {
    if (!realtimeConnected) return;
    realtime.send({
      'type': 'chat.room.create',
      'name': name.trim(),
      'isPublic': isPublic,
      'requestId': _clientId()
    });
  }

  void joinChatRoom(String roomId) {
    if (!realtimeConnected) return;
    realtime.send(
        {'type': 'chat.room.join', 'roomId': roomId, 'requestId': _clientId()});
  }

  Future<void> leaveChatRoom(String roomId) async {
    if (voice.active && voice.roomType == 'channel' && voice.roomId == roomId)
      await stopVoice();
    if (realtimeConnected) {
      realtime.send({'type': 'chat.room.leave', 'roomId': roomId});
    } else {
      chatRooms = chatRooms
          .map((room) => room['id']?.toString() == roomId
              ? {...room, 'joined': false}
              : room)
          .toList();
      channelMessages.remove(roomId);
      if (_activeChatRoomId == roomId) _activeChatRoomId = null;
      notifyListeners();
    }
  }

  void sendChatRoom(String roomId, String text) {
    final trimmed = text.trim();
    if (!realtimeConnected || trimmed.isEmpty) return;
    realtime.send({
      'type': 'chat.room.send',
      'roomId': roomId,
      'text': trimmed,
      'clientId': _clientId()
    });
  }

  void editMessage(
      {required String scope,
      required int messageId,
      required String text,
      String? roomId,
      String? target}) {
    if (!realtimeConnected) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (scope == 'lobby') {
      realtime
          .send({'type': 'chat.edit', 'messageId': messageId, 'text': clean});
    } else if (scope == 'room') {
      realtime.send({
        'type': 'chat.room.edit',
        'roomId': roomId,
        'messageId': messageId,
        'text': clean
      });
    } else if (scope == 'private') {
      realtime.send({
        'type': 'private.edit',
        'target': target,
        'messageId': messageId,
        'text': clean
      });
    }
  }

  void deleteMessage(
      {required String scope,
      required int messageId,
      String? roomId,
      String? target}) {
    if (!realtimeConnected) return;
    if (scope == 'lobby') {
      realtime.send({'type': 'chat.delete', 'messageId': messageId});
    } else if (scope == 'room') {
      realtime.send({
        'type': 'chat.room.delete',
        'roomId': roomId,
        'messageId': messageId
      });
    } else if (scope == 'private') {
      realtime.send(
          {'type': 'private.delete', 'target': target, 'messageId': messageId});
    }
  }

  void selectLobbyChat() {
    _activePrivateTarget = null;
    _activeChatRoomId = null;
    notifyListeners();
  }

  void sendLobby(String text) {
    _activePrivateTarget = null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final clientId = _clientId();
    if (realtimeConnected) {
      realtime.send({
        'type': 'chat.send',
        'text': trimmed,
        'clientId': clientId,
      });
      return;
    }

    chatMessages.add(ChatMessage(
      sender: username,
      text: trimmed,
      time: _time(DateTime.now()),
      clientId: clientId,
    ));
    coins += 2;
    _syncBalanceOffline();
  }

  void openPrivate(String target) {
    _activePrivateTarget = target;
    _activeChatRoomId = null;
    privateMessages.putIfAbsent(target, () => []);
    if (realtimeConnected) {
      realtime.send({'type': 'private.history', 'target': target});
    }
    _persist();
    notifyListeners();
  }

  void sendPrivate(String target, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final clientId = _clientId();

    if (realtimeConnected) {
      realtime.send({
        'type': 'private.send',
        'target': target,
        'text': trimmed,
        'clientId': clientId,
      });
      return;
    }

    privateMessages.putIfAbsent(target, () => []);
    privateMessages[target]!.add(ChatMessage(
      sender: username,
      text: trimmed,
      time: _time(DateTime.now()),
      clientId: clientId,
    ));
    coins += 1;
    _syncBalanceOffline();
  }

  bool buy(ShopItem item) {
    if (itemBusy.contains(item.id)) return false;
    if (realtimeConnected) {
      itemBusy.add(item.id);
      notifyListeners();
      realtime.send({
        'type': 'wallet.shop_buy',
        'itemId': item.id,
        'cost': item.cost,
      });
      return true;
    }

    if (coins < item.cost) return false;
    coins -= item.cost;
    inventory.update(item.id, (value) => value + 1, ifAbsent: () => 1);
    _syncBalanceOffline();
    return true;
  }

  Future<String?> _uploadMedia(
      {required String kind,
      required String dataBase64,
      required String ext}) async {
    lastActionError = null;
    if (!realtimeConnected) {
      lastActionError = '目前沒有連上伺服器';
      notifyListeners();
      return null;
    }
    try {
      final token = await store.currentToken();
      if (token == null || token.isEmpty) throw Exception('登入已失效，請重新登入');
      final response = await http
          .post(
            Uri.parse('${BackendConfig.httpBaseUrl}/api/upload'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'kind': kind,
              'dataBase64': dataBase64,
              'ext': ext,
            }),
          )
          .timeout(const Duration(seconds: 45));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map ||
          decoded['url'] == null) {
        final rawMessage =
            decoded is Map ? '${decoded['error'] ?? '上傳失敗'}' : '上傳失敗';
        final message = rawMessage == 'not_found'
            ? '目前連到舊版伺服器，請先關掉舊的 Node/npm 視窗，再重新執行 npm.cmd start'
            : rawMessage == 'media_not_found'
                ? '伺服器找不到這個媒體檔案，請重新上傳'
                : rawMessage;
        throw Exception(message);
      }
      return '${decoded['url']}';
    } catch (error) {
      lastActionError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> sendMedia({
    required String kind,
    required String dataBase64,
    required String ext,
    String caption = '',
    String? target,
    String? roomId,
  }) async {
    final url = await _uploadMedia(
      kind: kind,
      dataBase64: dataBase64,
      ext: ext,
    );

    if (url == null) {
      return;
    }

    final clientId = _clientId();

    final privateTarget = target ?? _activePrivateTarget;
    final activeRoom = roomId ?? _activeChatRoomId;

    if (privateTarget != null && privateTarget.trim().isNotEmpty) {
      realtime.send({
        'type': 'private.send',
        'target': privateTarget,
        'kind': kind,
        'url': url,
        'text': caption,
        'clientId': clientId,
      });
    } else if (activeRoom != null && activeRoom.trim().isNotEmpty) {
      realtime.send({
        'type': 'chat.room.send',
        'roomId': activeRoom,
        'kind': kind,
        'url': url,
        'text': caption,
        'clientId': clientId,
      });
    } else {
      realtime.send({
        'type': 'chat.send',
        'kind': kind,
        'url': url,
        'text': caption,
        'clientId': clientId,
      });
    }
  }

  void sendSticker(
    String sticker, {
    String? target,
    String? roomId,
  }) {
    if (!realtimeConnected) {
      return;
    }

    final clean = sticker.trim();

    if (clean.isEmpty) {
      return;
    }

    final privateTarget = target ?? _activePrivateTarget;
    final activeRoom = roomId ?? _activeChatRoomId;

    final payload = {
      'kind': 'sticker',
      'sticker': clean,
      'text': '',
      'clientId': _clientId(),
    };

    if (privateTarget != null && privateTarget.trim().isNotEmpty) {
      realtime.send({
        ...payload,
        'type': 'private.send',
        'target': privateTarget,
      });
    } else if (activeRoom != null && activeRoom.trim().isNotEmpty) {
      realtime.send({
        ...payload,
        'type': 'chat.room.send',
        'roomId': activeRoom,
      });
    } else {
      realtime.send({
        ...payload,
        'type': 'chat.send',
      });
    }
  }

  void sendGif(String url, {String? target, String? roomId}) {
    final clean = url.trim();
    if (clean.isEmpty) {
      lastActionError = 'GIF 網址為空';
      notifyListeners();
      return;
    }
    if (!realtimeConnected) {
      lastActionError = '目前未連線到伺服器';
      notifyListeners();
      return;
    }

    final privateTarget = target ?? _activePrivateTarget;
    final activeRoom = roomId ?? _activeChatRoomId;
    final clientId = _clientId();
    final payload = {
      'kind': 'gif',
      'url': clean,
      'text': '',
      'clientId': clientId,
    };

    lastActionError = null;
    if (privateTarget != null && privateTarget.trim().isNotEmpty) {
      realtime.send({
        ...payload,
        'type': 'private.send',
        'target': privateTarget,
      });
    } else if (activeRoom != null && activeRoom.trim().isNotEmpty) {
      realtime.send({
        ...payload,
        'type': 'chat.room.send',
        'roomId': activeRoom,
      });
    } else {
      realtime.send({
        ...payload,
        'type': 'chat.send',
      });
    }
  }

  void createPoll(String question, List<String> options) {
    if (!realtimeConnected) return;
    realtime.send({
      'type': 'chat.send',
      'kind': 'poll',
      'text': question,
      'options': options,
      'clientId': _clientId()
    });
  }

  void votePoll(int messageId, int option) {
    if (!realtimeConnected) return;
    realtime
        .send({'type': 'poll.vote', 'messageId': messageId, 'option': option});
  }

  Future<void> uploadAvatar(
      {required String dataBase64, required String ext}) async {
    final url =
        await _uploadMedia(kind: 'avatar', dataBase64: dataBase64, ext: ext);
    if (url == null || !realtimeConnected) return;
    realtime.send({'type': 'profile.avatar.upload', 'url': url});
  }

  void loadMemories() {
    if (realtimeConnected) realtime.send({'type': 'memory.list'});
  }

  Future<void> addMemory(
      {required String kind,
      required String dataBase64,
      required String ext,
      String caption = ''}) async {
    final url =
        await _uploadMedia(kind: 'memory', dataBase64: dataBase64, ext: ext);
    if (url == null || !realtimeConnected) return;
    realtime.send(
        {'type': 'memory.add', 'kind': kind, 'url': url, 'caption': caption});
  }

  void loadAdminUsers() {
    if (realtimeConnected && isAdmin) realtime.send({'type': 'admin.users'});
  }

  void adminBan(String target) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.ban', 'target': target});
  }

  void adminUnban(String target) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.unban', 'target': target});
  }

  void adminCreateAnnouncement(String title, String body) {
    if (realtimeConnected && isAdmin)
      realtime.send(
          {'type': 'admin.announcement.create', 'title': title, 'body': body});
  }

  void adminDeleteAnnouncement(int id) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.announcement.delete', 'id': id});
  }

  void adminDeleteMemory(int id) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.memory.delete', 'id': id});
  }

  void adminUpsertVoice(String id, String name, bool locked) {
    if (realtimeConnected && isAdmin)
      realtime.send({
        'type': 'admin.voice.upsert',
        'id': id,
        'name': name,
        'locked': locked
      });
  }

  void adminDeleteVoice(String id) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.voice.delete', 'id': id});
  }

  void adminLockVoice(String id, bool locked) {
    if (realtimeConnected && isAdmin)
      realtime.send({'type': 'admin.voice.lock', 'id': id, 'locked': locked});
  }

  String _notificationText(SocialNotification n) {
    final p = n.payload;
    return switch (n.type) {
      'friend.request' => '${p['sender'] ?? ''} 傳來好友邀請',
      'friend.accepted' => '${p['friend'] ?? ''} 接受了好友邀請',
      'werewolf.invite' => '${p['host'] ?? ''} 邀請你玩狼人殺',
      'truth.invite' => '${p['host'] ?? ''} 邀請你玩真心話大冒險',
      _ => '${p['message'] ?? '你有一則新通知'}',
    };
  }

  void setCosmetics({String? title, String? frame}) {
    if (title != null) selectedTitle = title;
    if (frame != null) selectedFrame = frame;
    _persist();
    notifyListeners();
  }

  void updateProfile(String newDisplayName, String newBio) {
    if (!realtimeConnected) {
      lastActionError = '目前沒有連上伺服器';
      notifyListeners();
      return;
    }
    realtime.send({
      'type': 'profile.update',
      'displayName': newDisplayName.trim(),
      'bio': newBio.trim()
    });
  }

  void clearNotification() {
    lastNotificationText = null;
    notifyListeners();
  }

  void refreshSocial() {
    if (realtimeConnected) realtime.send({'type': 'social.refresh'});
  }

  void sendFriendRequest(String target) {
    if (!realtimeConnected) return;
    realtime.send({'type': 'friend.request', 'target': target});
  }

  void respondFriendRequest(int requestId, bool accept) {
    if (!realtimeConnected) return;
    realtime.send(
        {'type': 'friend.respond', 'requestId': requestId, 'accept': accept});
  }

  void removeFriend(String target) {
    if (!realtimeConnected) return;
    realtime.send({'type': 'friend.remove', 'target': target});
  }

  void transferCoins(String target, int amount) {
    if (!realtimeConnected) return;
    realtime
        .send({'type': 'wallet.transfer', 'target': target, 'amount': amount});
  }

  void stealCoins(String target) {
    if (!realtimeConnected) return;
    realtime.send({'type': 'wallet.steal', 'target': target});
  }

  void useItem(String itemId, {String? target}) {
    if (!realtimeConnected) return;
    if (itemBusy.contains(itemId)) return;
    itemBusy.add(itemId);
    notifyListeners();
    realtime.send({
      'type': 'wallet.use_item',
      'itemId': itemId,
      if (target != null) 'target': target
    });
  }

  void inviteToWerewolf(String target) {
    if (!realtimeConnected || werewolfRoom == null) return;
    realtime.send({
      'type': 'werewolf.invite',
      'target': target,
      'roomId': werewolfRoom!.roomId
    });
  }

  void listWerewolfRooms() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'werewolf.list'});
  }

  void createWerewolfRoom({int maxPlayers = 8, int botCount = 0}) {
    if (!realtimeConnected || werewolfBusy) return;
    werewolfBusy = true;
    lastActionError = null;
    notifyListeners();
    realtime.send({
      'type': 'werewolf.create',
      'maxPlayers': maxPlayers,
      'botCount': botCount,
      'requestId': _clientId(),
    });
  }

  void joinWerewolfRoom(String roomId) {
    if (!realtimeConnected || werewolfBusy) return;
    werewolfBusy = true;
    lastActionError = null;
    notifyListeners();
    realtime.send(
        {'type': 'werewolf.join', 'roomId': roomId, 'requestId': _clientId()});
  }

  void leaveWerewolfRoom() {
    if (!realtimeConnected) {
      werewolfRoom = null;
      notifyListeners();
      return;
    }
    realtime.send({'type': 'werewolf.leave'});
  }

  void startWerewolf() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'werewolf.start'});
  }

  void werewolfSpeak(String text) {
    if (!realtimeConnected || text.trim().isEmpty) return;
    realtime.send({'type': 'werewolf.speak', 'text': text.trim()});
  }

  void werewolfSpeakDone() {
    if (!realtimeConnected || werewolfRoom?.myTurn != true) return;
    realtime.send({'type': 'werewolf.speak_done'});
  }

  void werewolfNight(String target) {
    if (!realtimeConnected) return;
    realtime.send({'type': 'werewolf.night', 'target': target});
  }

  void werewolfWitch(String action, {String? target}) {
    if (!realtimeConnected) return;
    realtime.send({
      'type': 'werewolf.witch',
      'action': action,
      if (target != null) 'target': target,
    });
  }

  void werewolfVote(String target) {
    if (!realtimeConnected ||
        werewolfVotePending ||
        werewolfRoom?.myVote != null) return;
    werewolfVotePending = true;
    notifyListeners();
    realtime.send({'type': 'werewolf.vote', 'target': target});
  }

  void werewolfHunter(String target) {
    if (!realtimeConnected || !werewolfHunterAvailable) return;
    realtime.send({'type': 'werewolf.hunter', 'target': target});
    werewolfHunterAvailable = false;
    werewolfHunterTargets = const [];
    notifyListeners();
  }

  void werewolfNextPhase() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'werewolf.day_next'});
  }

  void loadCommunityData() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'leaderboard.list'});
    realtime.send({'type': 'announcements.list'});
    realtime.send({'type': 'game.history'});
    realtime.send({'type': 'voice.rooms'});
  }

  void joinGlobalVoice(String roomId) {
    if (!realtimeConnected) return;
    if (roomId == 'lobby') {
      toggleVoice('channel', 'lobby');
      return;
    }
    toggleVoice('global', roomId);
  }

  void joinChannelVoice(String roomId) {
    if (!realtimeConnected) return;
    toggleVoice('channel', roomId);
  }

  int get unreadNotificationCount => notifications.where((n) => !n.read).length;

  void markNotificationsRead() {
    if (realtimeConnected) realtime.send({'type': 'notifications.read'});
    notifications = notifications
        .map((n) => SocialNotification(
            id: n.id,
            type: n.type,
            payload: n.payload,
            read: true,
            time: n.time))
        .toList();
    notifyListeners();
  }

  void listTruthRooms() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'truth.list'});
  }

  void createTruthRoom({int maxPlayers = 8}) {
    if (!realtimeConnected || truthBusy) return;
    truthBusy = true;
    lastActionError = null;
    notifyListeners();
    realtime.send({
      'type': 'truth.create',
      'maxPlayers': maxPlayers,
      'requestId': _clientId(),
    });
  }

  void joinTruthRoom(String roomId) {
    if (!realtimeConnected || truthBusy) return;
    truthBusy = true;
    lastActionError = null;
    notifyListeners();
    realtime.send({
      'type': 'truth.join',
      'roomId': roomId,
      'requestId': _clientId(),
    });
  }

  void leaveTruthRoom() {
    stopVoice();
    if (!realtimeConnected) {
      truthRoom = null;
      notifyListeners();
      return;
    }
    realtime.send({'type': 'truth.leave'});
  }

  void drawTruthPlayer() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'truth.draw'});
  }

  void chooseTruth(String choice) {
    if (!realtimeConnected) return;
    realtime.send({'type': 'truth.choose', 'choice': choice});
  }

  void finishTruthRound() {
    if (!realtimeConnected) return;
    realtime.send({'type': 'truth.finish'});
  }

  void truthSpeak(String text) {
    if (!realtimeConnected || text.trim().isEmpty) return;
    realtime.send({'type': 'truth.speak', 'text': text.trim()});
  }

  void inviteToTruth(String target) {
    if (!realtimeConnected || truthRoom == null) return;
    realtime.send({
      'type': 'truth.invite',
      'target': target,
      'roomId': truthRoom!.roomId,
    });
  }

  Future<void> toggleVoice(String roomType, String roomId) async {
    if (!realtimeConnected) {
      voiceError = '請先連上伺服器';
      notifyListeners();
      return;
    }
    if (voice.active && voice.roomType == roomType && voice.roomId == roomId) {
      await stopVoice();
      return;
    }
    await voice.start(
      realtime: realtime,
      roomType: roomType,
      roomId: roomId,
      onStateChanged: (active, muted, error) {
        voiceError = error;
        notifyListeners();
      },
    );
    final room = werewolfRoom;
    if (voice.active &&
        roomType == 'werewolf' &&
        room?.roomId == roomId &&
        room?.phase == 'day' &&
        room?.myTurn != true &&
        !voice.muted) {
      voice.setMuted(realtime, true);
    }
    voiceError = voice.error;
    notifyListeners();
  }

  Future<void> stopVoice() async {
    await voice.stop(realtime: realtime);
    voiceUsers = const {};
    voiceError = null;
    notifyListeners();
  }

  void toggleVoiceMute() {
    if (!voice.active) return;
    voice.setMuted(realtime, !voice.muted);
    notifyListeners();
  }

  void playGame(String gameId) {
    final reward = switch (gameId) {
      'werewolf' => 500,
      'truth' => 100,
      _ => 50,
    };

    if (realtimeConnected) {
      realtime.send({
        'type': 'game.reward',
        'gameId': gameId,
        'reward': reward,
        'roomId': _clientId(),
      });
      return;
    }

    coins += reward;
    if (gameId == 'werewolf') wins += 1;
    _syncBalanceOffline();
  }

  @override
  void dispose() {
    voice.dispose();
    realtime.disconnect();
    super.dispose();
  }
}
