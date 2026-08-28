import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/section_card.dart';

class GamesPage extends StatefulWidget {
  final ThunderAppState state;
  const GamesPage({super.key, required this.state});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final _roomMessageController = TextEditingController();

  ThunderAppState get state => widget.state;

  @override
  void dispose() {
    _roomMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (state.werewolfRoom != null) {
      return _WerewolfRoomView(
        state: state,
        messageController: _roomMessageController,
      );
    }
    if (state.truthRoom != null) {
      return _TruthRoomView(
        state: state,
        messageController: _roomMessageController,
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(
          title: Text('遊戲', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _GameCard(
                title: '狼人殺',
                tag: '多人',
                reward: '+500',
                icon: Icons.visibility_off_rounded,
                onTap: () => _openWerewolf(context),
              ),
              const SizedBox(height: 12),
              _GameCard(
                title: '真心話大冒險',
                tag: '派對',
                reward: '+100',
                icon: Icons.casino_rounded,
                onTap: () => _openTruth(context),
              ),
              const SizedBox(height: 12),
              _GameCard(
                title: '每日小遊戲',
                tag: '每日',
                reward: '+50',
                icon: Icons.bolt_rounded,
                onTap: () => _playSimple(context, '每日小遊戲', 50),
              ),
              if (!state.realtimeConnected) ...[
                const SizedBox(height: 12),
                const SectionCard(
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('連線後才能開狼人殺多人房')),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  void _playSimple(BuildContext context, String title, int reward) {
    state.playGame(title == '真心話大冒險' ? 'truth' : 'daily');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title +$reward 金幣')),
    );
  }

  void _openTruth(BuildContext context) {
    if (!state.realtimeConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先連上伺服器')),
      );
      return;
    }

    state.listTruthRooms();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      isScrollControlled: true,
      builder: (_) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '真心話大冒險',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.truthBusy
                          ? null
                          : () => state.createTruthRoom(maxPlayers: 8),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(state.truthBusy ? '建立中…' : '開房'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.lastActionError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Text(state.lastActionError!),
                  ),
                if (state.truthRoom != null) ...[
                  SectionCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('房間已建立')),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('進入'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (state.truthRooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('目前沒有房間')),
                  )
                else
                  ...state.truthRooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('房間 ${room['roomId']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text(
                                      '${room['players']} / ${room['maxPlayers']}  · 房主 ${room['host']}'),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                state.joinTruthRoom('${room['roomId']}');
                              },
                              child: const Text('加入'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openWerewolf(BuildContext context) {
    if (!state.realtimeConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先連上伺服器')),
      );
      return;
    }

    state.listWerewolfRooms();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      isScrollControlled: true,
      builder: (_) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '狼人殺',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.werewolfBusy
                          ? null
                          : () => _showCreateWerewolfDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(state.werewolfBusy ? '建立中…' : '開房'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.lastActionError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Text(state.lastActionError!),
                  ),
                if (state.werewolfRoom != null) ...[
                  SectionCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('房間已建立')),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('進入'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (state.werewolfRooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('目前沒有房間')),
                  )
                else
                  ...state.werewolfRooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('房間 ${room['roomId']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text(
                                      '${room['players']} / ${room['maxPlayers']}  · Bot ${room['bots'] ?? 0} · 房主 ${room['host']}'),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                state.joinWerewolfRoom('${room['roomId']}');
                              },
                              child: const Text('加入'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateWerewolfDialog(BuildContext context) {
    var botCount = 3;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('建立狼人殺房間'),
          content: DropdownButtonFormField<int>(
            initialValue: botCount,
            decoration: const InputDecoration(labelText: 'Bot 數量'),
            items: List.generate(
                8,
                (index) =>
                    DropdownMenuItem(value: index, child: Text('$index 個'))),
            onChanged: (value) => setDialogState(() => botCount = value ?? 0),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                state.createWerewolfRoom(maxPlayers: 8, botCount: botCount);
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WerewolfRoomView extends StatelessWidget {
  final ThunderAppState state;
  final TextEditingController messageController;

  const _WerewolfRoomView({
    required this.state,
    required this.messageController,
  });

  String _phaseName(String phase) {
    switch (phase) {
      case 'lobby':
        return '等待玩家';
      case 'night':
        return '夜晚';
      case 'day':
        return '白天討論';
      case 'voting':
        return '投票';
      case 'hunter':
        return '獵人反擊';
      case 'ended':
        return '結束';
      default:
        return phase;
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = state.werewolfRoom!;
    final primary = Theme.of(context).colorScheme.primary;
    final alivePlayers = room.players.where((p) => p.alive).toList();
    final isHost = room.host == state.username;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Row(
            children: [
              Expanded(
                  child: Text('狼人殺 · ${room.roomId}',
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('${room.players.length}/${room.maxPlayers}',
                  style: const TextStyle(fontSize: 14, color: Colors.white54)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '離開',
              onPressed: state.leaveWerewolfRoom,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Chip(label: Text(_phaseName(room.phase))),
                  if (room.round > 0) ...[
                    const SizedBox(width: 8),
                    Chip(label: Text('第 ${room.round} 輪')),
                  ],
                ],
              ),
              if (room.phaseEndsAt != null &&
                  room.phaseDurationSeconds != null) ...[
                const SizedBox(height: 10),
                _WerewolfPhaseTimer(
                  phase: room.phase,
                  endsAt: room.phaseEndsAt!,
                  durationSeconds: room.phaseDurationSeconds!,
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('玩家',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.players.map((p) {
                        final label =
                            '${p.name}${p.bot ? ' · Bot' : ''}${p.alive ? '' : ' · 出局'}';
                        return Chip(
                          avatar: Icon(
                            p.alive
                                ? Icons.person_rounded
                                : Icons.person_off_rounded,
                            size: 16,
                            color: p.connected ? primary : Colors.white30,
                          ),
                          label: Text(label),
                        );
                      }).toList(),
                    ),
                    if (room.myRole != null) ...[
                      const SizedBox(height: 12),
                      Text('你的身份：${room.myRole}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: primary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _VoiceBar(
                state: state,
                roomType: 'werewolf',
                roomId: room.roomId,
              ),
              const SizedBox(height: 12),
              if (room.phase == 'lobby')
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('至少 4 人才能開始')),
                          if (isHost)
                            FilledButton(
                              onPressed: room.players.length >= 4
                                  ? state.startWerewolf
                                  : null,
                              child: const Text('開始'),
                            ),
                        ],
                      ),
                      if (isHost && state.friends.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showInvites(context, state, room),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('邀請好友'),
                        ),
                      ],
                    ],
                  ),
                )
              else if (room.phase == 'ended')
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${room.winner} 陣營獲勝',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('勝者 +500 金幣 · 其他參與者 +100 金幣'),
                    ],
                  ),
                )
              else ...[
                _WerewolfActionCard(
                    state: state,
                    room: room,
                    alivePlayers: alivePlayers,
                    isHost: isHost),
                const SizedBox(height: 12),
                _WerewolfChatCard(
                    state: state, room: room, controller: messageController),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static void _showInvites(
      BuildContext context, ThunderAppState state, WerewolfRoomState room) {
    final existing = room.players.map((p) => p.name).toSet();
    final targets =
        state.friends.where((f) => !existing.contains(f.name)).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('邀請好友',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            if (targets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child:
                    Text('沒有可邀請的好友', style: TextStyle(color: Colors.white54)),
              )
            else
              ...targets.map(
                (friend) => ListTile(
                  leading:
                      CircleAvatar(child: Text(friend.name.substring(0, 1))),
                  title: Text(friend.name),
                  subtitle: Text(friend.online ? '在線' : '離線'),
                  trailing: IconButton(
                    onPressed: friend.online
                        ? () {
                            state.inviteToWerewolf(friend.name);
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _WerewolfPhaseTimer extends StatefulWidget {
  final String phase;
  final DateTime endsAt;
  final int durationSeconds;

  const _WerewolfPhaseTimer({
    required this.phase,
    required this.endsAt,
    required this.durationSeconds,
  });

  @override
  State<_WerewolfPhaseTimer> createState() => _WerewolfPhaseTimerState();
}

class _WerewolfPhaseTimerState extends State<_WerewolfPhaseTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt
      .difference(DateTime.now())
      .inSeconds
      .clamp(0, widget.durationSeconds)
      .toInt();
    final progress = widget.durationSeconds == 0 ? 0.0 : remaining / widget.durationSeconds;
    final label = widget.phase == 'voting' ? '投票剩餘' : '發言剩餘';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label $remaining 秒', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _WerewolfActionCard extends StatelessWidget {
  final ThunderAppState state;
  final WerewolfRoomState room;
  final List<WerewolfPlayer> alivePlayers;
  final bool isHost;

  const _WerewolfActionCard({
    required this.state,
    required this.room,
    required this.alivePlayers,
    required this.isHost,
  });

  String _actionText() {
    if (!room.myAlive) return '你已出局，可以繼續觀看討論。';
    if (room.phase == 'night') {
      if (room.nightStep == 'wolf') return room.myRole == '狼人' ? '與狼隊討論後，選擇今晚的目標。' : '狼人正在行動，請保持安靜。';
      if (room.nightStep == 'witch') return room.myRole == '女巫' ? '女巫請決定是否使用藥水。' : '女巫正在行動，請保持安靜。';
      if (room.nightStep == 'seer') return room.myRole == '預言家' ? '查看一名玩家是否為狼人。' : '預言家正在行動，請保持安靜。';
      if (room.nightStep == 'guard') return room.myRole == '守衛' ? '保護一名玩家。' : '守衛正在行動，請保持安靜。';
      return '夜晚結算中，請保持安靜。';
    }
    if (room.phase == 'day') {
      return room.myTurn
          ? '輪到你發言，可按「說完了」提前結束。'
          : room.speaker == null
            ? '正在安排下一位發言者。'
            : '${room.speaker} 正在發言，請保持安靜。';
    }
    if (room.phase == 'voting') return '選一名活著的玩家投票。';
    if (room.phase == 'hunter') return '獵人已出局，請選一名活著的玩家反擊。';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final active = room.myAlive;
    final nightRole = (room.nightStep == 'wolf' && room.myRole == '狼人') ||
      (room.nightStep == 'seer' && room.myRole == '預言家') ||
      (room.nightStep == 'guard' && room.myRole == '守衛');
    final candidates =
        alivePlayers.where((p) => p.name != state.username).toList();
    final nightCandidates = room.nightStep == 'guard'
      ? alivePlayers
      : candidates;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionText(),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          if (room.phase == 'day' && room.myTurn) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.werewolfSpeakDone,
              icon: const Icon(Icons.check_rounded),
              label: const Text('說完了'),
            ),
          ],
          if (active && room.phase == 'night' && nightRole) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
                children: nightCandidates
                  .map((p) => OutlinedButton(
                      onPressed: () => state.werewolfNight(p.name),
                      child: Text(p.name)))
                  .toList(),
            ),
            if (state.werewolfInspectTarget != null &&
                room.myRole == '預言家') ...[
              const SizedBox(height: 10),
              Text(
                  '${state.werewolfInspectTarget}：${state.werewolfInspectIsWolf == true ? '是狼人' : '不是狼人'}'),
            ],
          ],
          if (active && room.phase == 'night' &&
              room.nightStep == 'witch' && room.myRole == '女巫') ...[
            if (room.witchVictim != null && room.witchHasAntidote) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => state.werewolfWitch('save'),
                icon: const Icon(Icons.favorite_rounded),
                label: Text('使用解藥救 ${room.witchVictim}'),
              ),
            ],
            if (room.witchHasPoison) ...[
              const SizedBox(height: 12),
              const Text('使用毒藥帶走一名玩家'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidates
                    .where((player) => player.name != room.witchVictim)
                    .map((p) => OutlinedButton(
                          onPressed: () => state.werewolfWitch('poison', target: p.name),
                          child: Text(p.name),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => state.werewolfWitch('skip'),
              child: const Text('本晚不使用藥水'),
            ),
          ],
          if (state.werewolfHunterAvailable &&
              state.werewolfHunterTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '獵人反擊：選一名玩家帶走',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.werewolfHunterTargets
                  .map(
                    (name) => OutlinedButton(
                      onPressed: () => state.werewolfHunter(name),
                      child: Text(name),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (active && room.phase == 'voting') ...[
            const SizedBox(height: 12),
            if (room.myVote == null && !state.werewolfVotePending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidates
                    .map((p) => OutlinedButton(
                        onPressed: () => state.werewolfVote(p.name),
                        child: Text('投 ${p.name}')))
                    .toList(),
              )
            else
              Text('你已投給 ${room.myVote}，投票不可更改。'),
          ],
          if (room.voteCounts != null && room.voteCounts!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('本輪投票結果',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: room.voteCounts!.entries
                  .map((entry) => Chip(label: Text('${entry.key}：${entry.value} 票')))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WerewolfChatCard extends StatefulWidget {
  final ThunderAppState state;
  final WerewolfRoomState room;
  final TextEditingController controller;

  const _WerewolfChatCard({
    required this.state,
    required this.room,
    required this.controller,
  });

  @override
  State<_WerewolfChatCard> createState() => _WerewolfChatCardState();
}

class _WerewolfChatCardState extends State<_WerewolfChatCard> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = -1;

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.room.messages;
    if (_lastMessageCount != messages.length) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(Icons.forum_outlined, size: 18),
              SizedBox(width: 8),
              Text('討論', style: TextStyle(fontWeight: FontWeight.w900))
            ]),
          ),
          SizedBox(
            height: 300,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final mine = m.sender == widget.state.username;
                final system = m.sender == '系統';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: system
                        ? Alignment.center
                        : (mine ? Alignment.centerRight : Alignment.centerLeft),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: system
                            ? Colors.white.withValues(alpha: 0.05)
                            : (mine
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: system || mine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!system)
                            Text(m.sender,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                          Text(m.text),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
            if ((widget.room.phase == 'day' && widget.room.myTurn) ||
              widget.room.phase == 'voting' ||
              (widget.room.phase == 'night' &&
                  widget.room.nightStep == 'wolf' &&
                  widget.room.myRole == '狼人' &&
                  widget.room.myAlive))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      onSubmitted: (value) {
                        widget.state.werewolfSpeak(value);
                        widget.controller.clear();
                      },
                      decoration: InputDecoration(
                        hintText: widget.room.phase == 'night'
                            ? '只限狼隊的私密討論…'
                            : '說點什麼…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      widget.state.werewolfSpeak(widget.controller.text);
                      widget.controller.clear();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _TruthRoomView extends StatelessWidget {
  final ThunderAppState state;
  final TextEditingController messageController;

  const _TruthRoomView({
    required this.state,
    required this.messageController,
  });

  String _phaseText(String phase) {
    switch (phase) {
      case 'lobby':
      case 'waiting':
        return '等待抽人';
      case 'choose':
        return '選擇中';
      case 'active':
        return '進行中';
      default:
        return phase;
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = state.truthRoom!;
    final isHost = room.host == state.username;
    final selectedMe = room.selected == state.username;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '真心話大冒險 · ${room.roomId}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${room.players.length}/${room.maxPlayers}',
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '離開',
              onPressed: state.leaveTruthRoom,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Chip(label: Text(_phaseText(room.phase))),
                  if (room.selected != null) ...[
                    const SizedBox(width: 8),
                    Chip(label: Text('抽到 ${room.selected}')),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('玩家',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.players
                          .map(
                            (p) => Chip(
                              avatar: Icon(
                                p.selected
                                    ? Icons.star_rounded
                                    : Icons.person_rounded,
                                size: 16,
                                color:
                                    p.selected ? Colors.amber : Colors.white70,
                              ),
                              label: Text(p.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _VoiceBar(
                state: state,
                roomType: 'truth',
                roomId: room.roomId,
              ),
              const SizedBox(height: 12),
              if (room.phase == 'lobby' || room.phase == 'waiting')
                SectionCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('房主抽一個人，抽到的人決定玩法。'),
                      ),
                      if (isHost)
                        FilledButton.icon(
                          onPressed: room.players.length >= 2
                              ? state.drawTruthPlayer
                              : null,
                          icon: const Icon(Icons.casino_rounded),
                          label: const Text('隨機抽人'),
                        ),
                    ],
                  ),
                )
              else if (room.phase == 'choose')
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedMe ? '抽到你了，選一個：' : '${room.selected} 正在選擇…',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      if (selectedMe)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => state.chooseTruth('truth'),
                                child: const Text('真心話'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => state.chooseTruth('dare'),
                                child: const Text('大冒險'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                )
              else if (room.phase == 'active')
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.choice == 'truth' ? '真心話' : '大冒險',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        room.prompt ?? '',
                        style: const TextStyle(fontSize: 17, height: 1.4),
                      ),
                      if (isHost) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: state.finishTruthRound,
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('完成這輪'),
                        ),
                      ],
                    ],
                  ),
                ),
              if (room.phase == 'active') ...[
                const SizedBox(height: 12),
                _TruthChatCard(
                  state: state,
                  room: room,
                  controller: messageController,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _TruthChatCard extends StatefulWidget {
  final ThunderAppState state;
  final TruthRoomState room;
  final TextEditingController controller;

  const _TruthChatCard({
    required this.state,
    required this.room,
    required this.controller,
  });

  @override
  State<_TruthChatCard> createState() => _TruthChatCardState();
}

class _TruthChatCardState extends State<_TruthChatCard> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = -1;

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.room.messages;
    if (_lastMessageCount != messages.length) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 18),
                SizedBox(width: 8),
                Text('大家的反應', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final mine = m.sender == widget.state.username;
                final system = m.sender == '系統';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: system
                        ? Alignment.center
                        : mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: system
                            ? Colors.white.withValues(alpha: 0.05)
                            : mine
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: system || mine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!system)
                            Text(
                              m.sender,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          Text(m.text),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onSubmitted: (value) {
                      widget.state.truthSpeak(value);
                      widget.controller.clear();
                    },
                    decoration: const InputDecoration(hintText: '打字說話…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    widget.state.truthSpeak(widget.controller.text);
                    widget.controller.clear();
                  },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _VoiceBar extends StatelessWidget {
  final ThunderAppState state;
  final String roomType;
  final String roomId;

  const _VoiceBar({
    required this.state,
    required this.roomType,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final inThisRoom = state.voice.active &&
        state.voice.roomType == roomType &&
        state.voice.roomId == roomId;
    final isWaitingForTurn = roomType == 'werewolf' &&
      state.werewolfRoom?.phase == 'day' &&
      state.werewolfRoom?.myTurn != true;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child:
                    Text('語音', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (inThisRoom)
                IconButton(
                  tooltip: state.voice.muted ? '開麥克風' : '靜音',
                  onPressed: isWaitingForTurn ? null : state.toggleVoiceMute,
                  icon: Icon(
                    state.voice.muted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                  ),
                ),
              FilledButton.icon(
                onPressed: () => state.toggleVoice(roomType, roomId),
                icon: Icon(
                  inThisRoom ? Icons.call_end_rounded : Icons.mic_rounded,
                  size: 18,
                ),
                label: Text(inThisRoom ? '離開語音' : '開麥克風'),
              ),
            ],
          ),
          if (state.voiceError != null) ...[
            const SizedBox(height: 6),
            Text(
              state.voiceError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (state.voiceUsers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.voiceUsers.keys.map(
                (name) {
                  final info = state.voiceUsers[name]!;
                  return Chip(
                    avatar: Icon(
                      info['muted'] == true
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 15,
                    ),
                    label: Text(name),
                  );
                },
              ).toList(),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Windows 建議戴耳機，避免麥克風回音。',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String tag;
  final String reward;
  final IconData icon;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.tag,
    required this.reward,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.22),
                    primary.withValues(alpha: 0.06)
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: primary, size: 27),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Pill(text: tag),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(reward,
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
