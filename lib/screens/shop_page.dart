import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/section_card.dart';

class ShopPage extends StatelessWidget {
  final ThunderAppState state;
  const ShopPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('商店', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Pill(
                  text: '${state.coins}',
                  icon: Icons.monetization_on_outlined,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: SliverToBoxAdapter(
            child: SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 19),
                  const SizedBox(width: 9),
                  const Text('背包', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(
                    '${state.inventoryCount} 件',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
          sliver: SliverToBoxAdapter(
            child: _InventoryCard(state: state),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = state.shopItems[index];
                final count = state.inventory[item.id] ?? 0;
                return SectionCard(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item.icon, style: const TextStyle(fontSize: 30)),
                          const Spacer(),
                          if (count > 0)
                            Pill(text: '×$count', color: Colors.greenAccent),
                        ],
                      ),
                      const Spacer(),
                      Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(item.effect, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Text('${item.cost}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          SizedBox(
                            width: 76,
                            child: FilledButton.tonal(
                              onPressed: state.itemBusy.contains(item.id) ? null : () => _buy(context, item),
                              child: state.itemBusy.contains(item.id)
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('買'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: state.shopItems.length,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 205,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _buy(BuildContext context, ShopItem item) {
    if (!state.realtimeConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先連上伺服器')),
      );
      return;
    }
    if (state.buy(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在購買：${item.name}')),
      );
    }
  }
}

class _InventoryCard extends StatelessWidget {
  final ThunderAppState state;
  const _InventoryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = state.shopItems.where((item) => (state.inventory[item.id] ?? 0) > 0).toList();
    if (items.isEmpty) {
      return const SectionCard(
        child: Row(
          children: [
            Icon(Icons.backpack_outlined, color: Colors.white54),
            SizedBox(width: 10),
            Text('背包目前是空的', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: items.map((item) {
          final count = state.inventory[item.id] ?? 0;
          final auto = item.id == 'shield';
          return ListTile(
            dense: true,
            leading: Text(item.icon, style: const TextStyle(fontSize: 23)),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              auto ? '自動生效' : '持有 $count 件',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
            trailing: auto
                ? const Icon(Icons.shield_outlined, color: Colors.greenAccent)
                : FilledButton.tonal(
                onPressed: state.itemBusy.contains(item.id) ? null : () => _use(context, item),
                child: state.itemBusy.contains(item.id)
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('使用'),
                  ),
          );
        }).toList(),
      ),
    );
  }

  void _use(BuildContext context, ShopItem item) {
    if (!state.realtimeConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先連上伺服器')));
      return;
    }
    if (item.id == 'scan') {
      _selectTarget(context, item);
      return;
    }
    state.useItem(item.id);
  }

  void _selectTarget(BuildContext context, ShopItem item) {
    final candidates = state.werewolfRoom?.players
            .where((p) => p.alive && p.name != state.username)
            .map((p) => p.name)
            .toList() ??
        [];
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('身份探測器只能在狼人殺房間中使用')),
      );
      return;
    }
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
                child: Text('選擇目標', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            ...candidates.map(
              (name) => ListTile(
                leading: const Icon(Icons.person_search_outlined),
                title: Text(name),
                onTap: () {
                  Navigator.pop(context);
                  state.useItem(item.id, target: name);
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
