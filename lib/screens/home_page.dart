import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/section_card.dart';
import 'community_page.dart';

class HomePage extends StatelessWidget {
  final ThunderAppState state;
  final ValueChanged<int> onGo;

  const HomePage({super.key, required this.state, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          titleSpacing: 20,
          title: const Text('雷霆611', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.6)),
          actions: [
            Stack(
              children: [
                IconButton(
                  tooltip: '通知',
                  onPressed: () => _showNotifications(context),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (state.unreadNotificationCount > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${state.unreadNotificationCount > 9 ? '9+' : state.unreadNotificationCount}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Pill(text: '${state.coins}', icon: Icons.monetization_on_outlined, color: Colors.amber)),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(state.username, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1))),
                  Text('6-11', style: TextStyle(color: Colors.white.withValues(alpha: 0.32), fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _QuickCard(icon: Icons.chat_bubble_rounded, title: '聊天', value: '大廳', onTap: () => onGo(1))),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickCard(icon: Icons.sports_esports_rounded, title: '遊戲', value: '開玩', onTap: () => onGo(2))),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityPage(state: state))),
                child: const Row(children: [
                  Icon(Icons.groups_rounded),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('社群', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('公告 · 排行榜 · 語音房', style: TextStyle(color: Colors.white38, fontSize: 11))])),
                  Icon(Icons.chevron_right_rounded, color: Colors.white30),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.bolt_rounded, color: primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('每日簽到', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('+10', style: TextStyle(fontSize: 13, color: Colors.white54)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: state.checkedIn
                          ? null
                          : () {
                              state.claimDaily();
                            },
                      child: Text(state.checkedIn ? '已領' : '領取'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: '在線', value: '${state.onlineCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: '勝場', value: '${state.wins}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: '道具', value: '${state.inventory.values.fold<int>(0, (a, b) => a + b)}')),
                ],
              ),
              if (state.lastNotificationText != null) ...[
                SectionCard(
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(child: Text(state.lastNotificationText!, style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(onPressed: state.clearNotification, icon: const Icon(Icons.close_rounded, size: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.friendRequests.any((r) => r.target == state.username)) ...[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.person_add_alt_1_rounded, size: 18), const SizedBox(width: 8), const Text('好友邀請', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${state.friendRequests.where((r) => r.target == state.username).length}', style: const TextStyle(color: Colors.white54))]),
                      const SizedBox(height: 10),
                      ...state.friendRequests.where((r) => r.target == state.username).map((request) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(child: Text(request.sender, style: const TextStyle(fontWeight: FontWeight.w800))),
                          TextButton(onPressed: () => state.respondFriendRequest(request.id, false), child: const Text('拒絕')),
                          FilledButton.tonal(onPressed: () => state.respondFriendRequest(request.id, true), child: const Text('接受')),
                        ]),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Expanded(child: Text('好友', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                  TextButton.icon(onPressed: state.refreshSocial, icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('更新')),
                ],
              ),
              const SizedBox(height: 10),
              if (state.friends.isEmpty)
                const SectionCard(child: Text('還沒有好友，點成員可以加好友。', style: TextStyle(color: Colors.white54)))
              else
                SectionCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: state.friends.take(5).map((friend) => ListTile(
                      dense: true,
                      leading: CircleAvatar(child: Text(friend.name.substring(0, 1))),
                      title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${friend.online ? '在線' : '離線'} · ${friend.wins} 勝', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      trailing: Text('${friend.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
                      onTap: () => _memberActions(context, friend.name),
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('成員', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              SectionCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: state.members.take(4).map((member) {
                    final dotColor = member.online ? Colors.greenAccent : Colors.white24;
                    return ListTile(
                      dense: true,
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: primary.withValues(alpha: 0.12),
                            child: Text(member.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF111117), width: 2)))),
                        ],
                      ),
                      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(member.status, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${member.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
                        ],
                      ),
                      onTap: () => _memberActions(context, member.name),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    state.markNotificationsRead();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '通知',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (state.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('目前沒有通知', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final item = state.notifications[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            item.type.contains('wallet')
                                ? Icons.monetization_on_outlined
                                : item.type.contains('truth') || item.type.contains('werewolf')
                                    ? Icons.sports_esports_rounded
                                    : Icons.notifications_none_rounded,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          _notificationTitle(item),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(item.time),
                        onTap: () {
                          final roomId = item.payload['roomId']?.toString();
                          if (roomId == null) return;
                          Navigator.pop(context);
                          if (item.type == 'werewolf.invite') {
                            onGo(2);
                            state.joinWerewolfRoom(roomId);
                          } else if (item.type == 'truth.invite') {
                            onGo(2);
                            state.joinTruthRoom(roomId);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _notificationTitle(SocialNotification item) {
    final p = item.payload;
    switch (item.type) {
      case 'friend.request':
        return '${p['sender'] ?? ''} 想加你為好友';
      case 'friend.accepted':
        return '${p['friend'] ?? ''} 接受了好友邀請';
      case 'werewolf.invite':
        return '${p['host'] ?? ''} 邀請你加入狼人殺';
      case 'truth.invite':
        return '${p['host'] ?? ''} 邀請你加入真心話大冒險';
      case 'wallet.received':
        return '${p['sender'] ?? ''} 轉了 ${p['amount'] ?? 0} 金幣給你';
      case 'wallet.stolen':
        return '${p['attacker'] ?? ''} 偷走了 ${p['stolen'] ?? 0} 金幣';
      case 'wallet.steal_blocked':
        return '${p['attacker'] ?? ''} 想偷你，但被護盾擋住';
      default:
        return '收到一則通知';
    }
  }

  void _memberActions(BuildContext context, String target) {
    final isFriend = state.friends.any((f) => f.name == target);
    final hasSteal = (state.inventory['steal'] ?? 0) > 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111117),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
              title: Text(target, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('成員操作'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('私訊'),
              onTap: () {
                Navigator.pop(context);
                onGo(1);
                state.openPrivate(target);
              },
            ),
            if (!isFriend)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('加好友'),
                onTap: () {
                  Navigator.pop(context);
                  state.sendFriendRequest(target);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: const Text('刪除好友'),
                onTap: () {
                  Navigator.pop(context);
                  state.removeFriend(target);
                },
              ),
            ListTile(
              leading: const Icon(Icons.monetization_on_outlined),
              title: const Text('轉帳金幣'),
              onTap: () {
                Navigator.pop(context);
                _transferDialog(context, target);
              },
            ),
            ListTile(
              enabled: hasSteal,
              leading: const Icon(Icons.person_search_outlined),
              title: const Text('偷金幣'),
              subtitle: Text(hasSteal ? '使用 1 張偷金幣卡' : '需要偷金幣卡'),
              onTap: hasSteal
                  ? () {
                      Navigator.pop(context);
                      state.stealCoins(target);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _transferDialog(BuildContext context, String target) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('轉給 $target'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '金幣', hintText: '例如 500'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(dialogContext);
              if (amount > 0 && amount <= state.coins) state.transferCoins(target, amount);
            },
            child: const Text('轉帳'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _QuickCard({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: primary, size: 24),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}
