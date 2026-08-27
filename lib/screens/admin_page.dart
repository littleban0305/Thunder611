import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/section_card.dart';

class AdminPage extends StatefulWidget {
  final ThunderAppState state;
  const AdminPage({super.key, required this.state});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final title = TextEditingController();
  final body = TextEditingController();
  final voiceId = TextEditingController();
  final voiceName = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.state.loadAdminUsers();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('管理員後台', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const Text('帳號管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SectionCard(padding: EdgeInsets.zero, child: Column(children: state.adminUsers.map((u) => ListTile(
                title: Text('${u['username'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${u['coins'] ?? 0} 金幣 · ${u['wins'] ?? 0} 勝 · ${u['role'] ?? 'member'}'),
                trailing: u['banned'] == true || u['banned'] == 1
                    ? FilledButton.tonal(onPressed: () { state.adminUnban('${u['username']}'); state.loadAdminUsers(); }, child: const Text('解封'))
                    : TextButton(onPressed: '${u['username']}' == state.username ? null : () { state.adminBan('${u['username']}'); state.loadAdminUsers(); }, child: const Text('封禁')),
              )).toList())),
          const SizedBox(height: 18),
          const Text('發布公告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SectionCard(child: Column(children: [TextField(controller: title, decoration: const InputDecoration(labelText: '標題')), const SizedBox(height: 10), TextField(controller: body, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: '內容')), const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () { if (title.text.trim().isNotEmpty && body.text.trim().isNotEmpty) { state.adminCreateAnnouncement(title.text.trim(), body.text.trim()); title.clear(); body.clear(); } }, child: const Text('發布')))])),
          const SizedBox(height: 18),
          const Text('公告管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...state.announcements.map((a) => ListTile(title: Text(a.title), subtitle: Text(a.time), trailing: IconButton(onPressed: () => state.adminDeleteAnnouncement(a.id), icon: const Icon(Icons.delete_outline_rounded)))),
          const SizedBox(height: 12),
          const Text('回憶管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...state.memories.map((m) => ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(m.caption.isEmpty ? '${m.uploader} 的回憶' : m.caption), subtitle: Text('${m.uploader} · ${m.time}'), trailing: IconButton(onPressed: () => state.adminDeleteMemory(m.id), icon: const Icon(Icons.delete_outline_rounded)))),
          const SizedBox(height: 18),
          const Text('語音房管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SectionCard(child: Column(children: [TextField(controller: voiceId, decoration: const InputDecoration(labelText: 'ID（英文／數字）')), const SizedBox(height: 10), TextField(controller: voiceName, decoration: const InputDecoration(labelText: '名稱')), const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () { state.adminUpsertVoice(voiceId.text.trim(), voiceName.text.trim(), false); voiceId.clear(); voiceName.clear(); }, child: const Text('建立／更新')))])),
          const SizedBox(height: 10),
          ...state.voiceRooms.map((room) => ListTile(
                leading: const Icon(Icons.mic_rounded),
                title: Text('${room['name'] ?? room['id']}'),
                subtitle: Text('${room['id']} · ${room['users'] ?? 0} 人'),
                trailing: Wrap(spacing: 2, children: [IconButton(onPressed: () => state.adminLockVoice('${room['id']}', room['locked'] != true), icon: Icon(room['locked'] == true ? Icons.lock_rounded : Icons.lock_open_rounded)), IconButton(onPressed: () => state.adminDeleteVoice('${room['id']}'), icon: const Icon(Icons.delete_outline_rounded))]),
              )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    title.dispose(); body.dispose(); voiceId.dispose(); voiceName.dispose(); super.dispose();
  }
}
