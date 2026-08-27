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
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                                  Text('房間 ${room['roomId']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text('${room['players']} / ${room['maxPlayers']}  · 房主 ${room['host']}'),
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
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.werewolfBusy
                          ? null
                          : () {
                              state.createWerewolfRoom(maxPlayers: 8);
                            },
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
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                                  Text('房間 ${room['roomId']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text('${room['players']} / ${room['maxPlayers']}  · 房主 ${room['host']}'),
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
              Expanded(child: Text('狼人殺 · ${room.roomId}', style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('${room.players.length}/${room.maxPlayers}', style: const TextStyle(fontSize: 14, color: Colors.white54)),
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
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('玩家', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.players.map((p) {
                        final label = p.alive ? p.name : '${p.name} · 出局';
                        return Chip(
                          avatar: Icon(
                            p.alive ? Icons.person_rounded : Icons.person_off_rounded,
                            size: 16,
                            color: p.connected ? primary : Colors.white30,
                          ),
                          label: Text(label),
                        );
                      }).toList(),
                    ),
                    if (room.myRole != null) ...[
                      const SizedBox(height: 12),
                      Text('你的身份：${room.myRole}', style: TextStyle(fontWeight: FontWeight.w900, color: primary)),
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
                              onPressed: room.players.length >= 4 ? state.startWerewolf : null,
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
                      Text('${room.winner} 陣營獲勝', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('勝者 +500 金幣 · 其他參與者 +100 金幣'),
                    ],
                  ),
                )
              else ...[
                _WerewolfActionCard(state: state, room: room, alivePlayers: alivePlayers, isHost: isHost),
                const SizedBox(height: 12),
                _WerewolfChatCard(state: state, room: room, controller: messageController),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static void _showInvites(BuildContext context, ThunderAppState state, WerewolfRoomState room) {
    final existing = room.players.map((p) => p.name).toSet();
    final targets = state.friends.where((f) => !existing.contains(f.name)).toList();
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
                child: Text('邀請好友', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            if (targets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('沒有可邀請的好友', style: TextStyle(color: Colors.white54)),
              )
            else
              ...targets.map(
                (friend) => ListTile(
                  leading: CircleAvatar(child: Text(friend.name.substring(0, 1))),
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
      switch (room.myRole) {
        case '狼人':
          return '選一名玩家作為目標。';
        case '預言家':
          return '查看一名玩家是否為狼人。';
        case '守衛':
          return '保護一名玩家。';
        default:
          return '等待其他玩家。';
      }
    }
    if (room.phase == 'day') return '自由討論，房主可開始投票。';
    if (room.phase == 'voting') return '選一名活著的玩家投票。';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final active = room.myAlive;
    final nightRole = ['狼人', '預言家', '守衛'].contains(room.myRole);
    final candidates = alivePlayers.where((p) => p.name != state.username).toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionText(), style: const TextStyle(fontWeight: FontWeight.w800)),
          if (active && room.phase == 'night' && nightRole) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates
                  .map((p) => OutlinedButton(onPressed: () => state.werewolfNight(p.name), child: Text(p.name)))
                  .toList(),
            ),
            if (state.werewolfInspectTarget != null && room.myRole == '預言家') ...[
              const SizedBox(height: 10),
              Text('${state.werewolfInspectTarget}：${state.werewolfInspectIsWolf == true ? '是狼人' : '不是狼人'}'),
            ],
          ],
          if (active && room.phase == 'voting') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates
                  .map((p) => OutlinedButton(onPressed: () => state.werewolfVote(p.name), child: Text('投 ${p.name}')))
                  .toList(),
            ),
          ],
          if (isHost && room.phase == 'night') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.werewolfNextPhase,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('直接進入白天'),
            ),
          ],
          if (isHost && room.phase == 'day') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.werewolfNextPhase,
              icon: const Icon(Icons.how_to_vote_rounded),
              label: const Text('開始投票'),
            ),
          ],
          if (isHost && room.phase == 'voting') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.werewolfNextPhase,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('結束投票並進入下一輪'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WerewolfChatCard extends StatelessWidget {
  final ThunderAppState state;
  final WerewolfRoomState room;
  final TextEditingController controller;

  const _WerewolfChatCard({
    required this.state,
    required this.room,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final messages = room.messages;
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [Icon(Icons.forum_outlined, size: 18), SizedBox(width: 8), Text('討論', style: TextStyle(fontWeight: FontWeight.w900))]),
          ),
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final mine = m.sender == state.username;
                final system = m.sender == '系統';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: system ? Alignment.center : (mine ? Alignment.centerRight : Alignment.centerLeft),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: system ? Colors.white.withValues(alpha: 0.05) : (mine ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: system || mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!system) Text(m.sender, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                          Text(m.text),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (room.phase == 'day' || room.phase == 'voting')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (value) {
                        state.werewolfSpeak(value);
                        controller.clear();
                      },
                      decoration: const InputDecoration(hintText: '說點什麼…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      state.werewolfSpeak(controller.text);
                      controller.clear();
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
                    const Text('玩家', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.players.map(
                        (p) => Chip(
                          avatar: Icon(
                            p.selected ? Icons.star_rounded : Icons.person_rounded,
                            size: 16,
                            color: p.selected ? Colors.amber : Colors.white70,
                          ),
                          label: Text(p.name),
                        ),
                      ).toList(),
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
                          onPressed: room.players.length >= 2 ? state.drawTruthPlayer : null,
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
                        selectedMe
                            ? '抽到你了，選一個：'
                            : '${room.selected} 正在選擇…',
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

class _TruthChatCard extends StatelessWidget {
  final ThunderAppState state;
  final TruthRoomState room;
  final TextEditingController controller;

  const _TruthChatCard({
    required this.state,
    required this.room,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
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
              itemCount: room.messages.length,
              itemBuilder: (context, index) {
                final m = room.messages[index];
                final mine = m.sender == state.username;
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
                        crossAxisAlignment:
                            system || mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                    controller: controller,
                    onSubmitted: (value) {
                      state.truthSpeak(value);
                      controller.clear();
                    },
                    decoration: const InputDecoration(hintText: '打字說話…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    state.truthSpeak(controller.text);
                    controller.clear();
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
    final inThisRoom =
        state.voice.active && state.voice.roomType == roomType && state.voice.roomId == roomId;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('語音', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (inThisRoom)
                IconButton(
                  tooltip: state.voice.muted ? '開麥克風' : '靜音',
                  onPressed: state.toggleVoiceMute,
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
                  colors: [primary.withValues(alpha: 0.22), primary.withValues(alpha: 0.06)],
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
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Pill(text: tag),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(reward, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
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
