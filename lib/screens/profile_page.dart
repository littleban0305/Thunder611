import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/backend_config.dart';
import '../widgets/section_card.dart';

class ProfilePage extends StatelessWidget {
  final ThunderAppState state;
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.state, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(
          title: Text('我的', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SectionCard(
                child: Row(
                  children: [
                    Stack(children: [
                      _Avatar(
                          frame: state.selectedFrame,
                          name: state.username,
                          avatarUrl: state.avatarUrl),
                      Positioned(
                          right: -2,
                          bottom: -2,
                          child: IconButton.filled(
                              onPressed: () => _pickAvatar(context),
                              icon: const Icon(Icons.camera_alt_rounded,
                                  size: 15),
                              constraints: const BoxConstraints.tightFor(
                                  width: 34, height: 34),
                              padding: EdgeInsets.zero))
                    ]),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.displayName.isEmpty
                                ? state.username
                                : state.displayName,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text('@${state.username}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white38)),
                          if (state.bio.isNotEmpty)
                            Text(state.bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                          Row(children: [
                            Text(state.selectedTitle,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                )),
                            if (state.isAdmin) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                  label: Text('ADMIN'),
                                  visualDensity: VisualDensity.compact),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    Pill(
                      text: '${state.coins}',
                      icon: Icons.monetization_on_outlined,
                      color: Colors.amber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(title: '金幣', value: '${state.coins}')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(title: '勝場', value: '${state.wins}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      title: '道具',
                      value:
                          '${state.inventory.values.fold<int>(0, (a, b) => a + b)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('狼人殺戰績',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _Stat(
                                title: '對局',
                                value: '${state.werewolfStats['total'] ?? 0}')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _Stat(
                                title: '勝場',
                                value: '${state.werewolfStats['wins'] ?? 0}')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _Stat(
                                title: '勝率',
                                value: '${state.werewolfStats['rate'] ?? 0}%')),
                      ]),
                    ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('編輯資料',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('修改顯示名稱與個人簡介'),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white30),
                  onTap: () => _editProfile(context),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _RowItem(
                      icon: state.realtimeConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      title: '同步',
                      value: state.realtimeConnected ? '已連線' : '離線',
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('稱號',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        state.selectedTitle,
                        style: const TextStyle(color: Colors.white38),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white30),
                      onTap: () => _showTitles(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: const Text('頭像框',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        state.selectedFrame == 'default'
                            ? '預設'
                            : state.selectedFrame,
                        style: const TextStyle(color: Colors.white38),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white30),
                      onTap: () => _showFrames(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GameHistoryCard(state: state),
              const SizedBox(height: 12),
              if (state.transactionsList.isNotEmpty)
                _TransactionsCard(state: state),
              if (state.transactionsList.isNotEmpty) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('登出'),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (!context.mounted) return;
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('頭像上限 5MB')),
      );
      return;
    }

    final bytes = file.bytes!;
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到圖片內容，請重新選擇')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('頭像上傳中…')),
    );

    await state.uploadAvatar(
      dataBase64: base64Encode(bytes),
      ext: (file.extension ?? 'jpg').toLowerCase(),
    );

    if (!context.mounted) return;
    final error = state.lastActionError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '頭像已更新')),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final nameController = TextEditingController(
        text: state.displayName.isEmpty ? state.username : state.displayName);
    final bioController = TextEditingController(text: state.bio);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('編輯資料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                maxLength: 30,
                decoration: const InputDecoration(labelText: '顯示名稱')),
            TextField(
                controller: bioController,
                maxLength: 160,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '個人簡介')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty)
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('儲存')),
        ],
      ),
    );
    if (saved == true)
      state.updateProfile(nameController.text, bioController.text);
    nameController.dispose();
    bioController.dispose();
  }

  void _showTitles(BuildContext context) {
    const titles = ['新手', '聊天王', '遊戲王', '金幣富豪', '狼人獵人'];
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
                child: Text('選擇稱號',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            ...titles.map(
              (title) => ListTile(
                title: Text(title),
                trailing: state.selectedTitle == title
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  state.setCosmetics(title: title);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFrames(BuildContext context) {
    const frames = {'default': '預設', 'bolt': '閃電', 'moon': '月光', 'gold': '金色'};
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
                child: Text('選擇頭像框',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            ...frames.entries.map(
              (entry) => ListTile(
                leading: _Avatar(
                    frame: entry.key,
                    name: state.username,
                    radius: 18,
                    avatarUrl: state.avatarUrl),
                title: Text(entry.value),
                trailing: state.selectedFrame == entry.key
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  state.setCosmetics(frame: entry.key);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHistoryCard extends StatelessWidget {
  final ThunderAppState state;
  const _GameHistoryCard({required this.state});

  void _openAll(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _FullHistoryPage(state: state, transactions: false)));
  }

  @override
  Widget build(BuildContext context) {
    String name(String id) => switch (id) {
          'werewolf' => '狼人殺',
          'truth' => '真心話大冒險',
          _ => '每日小遊戲',
        };
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
            child: Row(
              children: [
                const Expanded(
                    child: Text('遊戲紀錄',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                if (state.gameHistory.length > 5)
                  TextButton(
                      onPressed: () => _openAll(context),
                      child: const Text('查看全部')),
              ],
            ),
          ),
          if (state.gameHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text('還沒有紀錄', style: TextStyle(color: Colors.white38)),
            )
          else
            ...state.gameHistory.take(5).map(
                  (game) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Icon(
                        game.gameId == 'werewolf'
                            ? Icons.visibility_off_rounded
                            : Icons.casino_rounded,
                        size: 16,
                      ),
                    ),
                    title: Text(name(game.gameId),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                    subtitle: Text('${game.result} · ${game.time}',
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 10)),
                    trailing: Text('+${game.reward}',
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.w900)),
                  ),
                ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  final ThunderAppState state;
  const _TransactionsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
            child: Row(
              children: [
                const Expanded(
                    child: Text('金幣紀錄',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                if (state.transactionsList.length > 5)
                  TextButton(
                      onPressed: () => _openAll(context, true),
                      child: const Text('查看全部')),
              ],
            ),
          ),
          ...state.transactionsList.take(5).map(
                (tx) => ListTile(
                  dense: true,
                  leading: Icon(
                    tx.amount >= 0
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    size: 18,
                    color:
                        tx.amount >= 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
                  title: Text(tx.kind,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text(tx.time,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white30)),
                  trailing: Text(
                    '${tx.amount >= 0 ? '+' : ''}${tx.amount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: tx.amount >= 0
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _openAll(BuildContext context, bool transactions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullHistoryPage(state: state, transactions: transactions),
      ),
    );
  }
}

class _FullHistoryPage extends StatelessWidget {
  final ThunderAppState state;
  final bool transactions;

  const _FullHistoryPage({required this.state, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(transactions ? '完整金幣紀錄' : '完整遊戲紀錄')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        itemCount: transactions
            ? state.transactionsList.length
            : state.gameHistory.length,
        itemBuilder: (context, index) {
          if (transactions) {
            final tx = state.transactionsList[index];
            return ListTile(
              leading: Icon(
                  tx.amount >= 0
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color:
                      tx.amount >= 0 ? Colors.greenAccent : Colors.redAccent),
              title: Text(tx.kind),
              subtitle: Text(tx.time),
              trailing: Text('${tx.amount >= 0 ? '+' : ''}${tx.amount}'),
            );
          }
          final game = state.gameHistory[index];
          return ListTile(
            leading: const Icon(Icons.sports_esports_outlined),
            title: Text(game.gameId),
            subtitle: Text('${game.result} · ${game.time}'),
            trailing: Text('+${game.reward}',
                style: const TextStyle(color: Colors.amber)),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String frame;
  final String name;
  final double radius;
  final String avatarUrl;

  const _Avatar({
    required this.frame,
    required this.name,
    this.radius = 31,
    this.avatarUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (frame) {
      'gold' => Colors.amber,
      'moon' => Colors.blueAccent,
      'bolt' => Colors.deepPurpleAccent,
      _ => Theme.of(context).colorScheme.primary,
    };

    final imageUrl = BackendConfig.mediaUrl(avatarUrl);

    final initials = name.isEmpty ? '?' : name.substring(0, 1);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.75),
          width: frame == 'default' ? 1 : 3,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: imageUrl.isEmpty
              ? ColoredBox(
                  color: color.withValues(alpha: 0.14),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: radius * 0.7,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: color.withValues(alpha: 0.14),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: radius * 0.7,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: color.withValues(alpha: 0.14),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;
  const _Stat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) => SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(title,
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
      );
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _RowItem(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 21),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: value.isEmpty
            ? const Icon(Icons.chevron_right_rounded, color: Colors.white30)
            : Text(value, style: const TextStyle(color: Colors.white54)),
      );
}
