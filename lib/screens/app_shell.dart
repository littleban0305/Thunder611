import 'package:flutter/material.dart';

import '../app_state.dart';
import 'chat_page.dart';
import 'login_page.dart';
import 'games_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import '../auth_controller.dart';
import 'shop_page.dart';

class AppShell extends StatefulWidget {
  final String username;

  const AppShell({super.key, required this.username});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ThunderAppState state;
  final AuthController _auth = AuthController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    state = ThunderAppState(username: widget.username)..addListener(_refresh);
  }

  void _refresh() => setState(() {});

  Future<void> logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    state.removeListener(_refresh);
    state.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(state: state, onGo: (index) => setState(() => _index = index)),
      ChatPage(state: state),
      GamesPage(state: state),
      ShopPage(state: state),
      ProfilePage(state: state, onLogout: logout),
    ];

    final destinations = const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '首頁'),
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: '聊天'),
      NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports_rounded), label: '遊戲'),
      NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: '商店'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: '我的'),
    ];

    final navItems = const [
      NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('首頁')),
      NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: Text('聊天')),
      NavigationRailDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports_rounded), label: Text('遊戲')),
      NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: Text('商店')),
      NavigationRailDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: Text('我的')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        return Scaffold(
          body: Stack(
            children: [
              const Positioned(
                top: -120,
                right: -90,
                child: _GlowOrb(color: Color(0x33F2B84B), size: 260),
              ),
              const Positioned(
                bottom: 120,
                left: -140,
                child: _GlowOrb(color: Color(0x225ED6C0), size: 280),
              ),
              SafeArea(
                child: Row(
                  children: [
                    if (isWide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 0, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: NavigationRail(
                            selectedIndex: _index,
                            onDestinationSelected: (index) => setState(() => _index = index),
                            destinations: navItems,
                            labelType: NavigationRailLabelType.all,
                            backgroundColor: const Color(0xCC111A1E),
                            indicatorColor: const Color(0x33F2B84B),
                          ),
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (index) => setState(() => _index = index),
                      destinations: destinations,
                    ),
                  ),
                ),
        );
      },
    );
  }

}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 10)]),
      ),
    );
  }
}
