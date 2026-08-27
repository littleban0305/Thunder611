import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/section_card.dart';
import 'app_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController(text: '611');
  final _auth = AuthController();
  bool _register = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final username = await _auth.restoreSession();
    if (!mounted || username == null) return;
    _openApp(username);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    String? username;
    if (_register) {
      username = await _auth.register(_name.text, _password.text, _code.text);
    } else {
      username = await _auth.login(_name.text, _password.text);
    }
    if (!mounted) return;
    if (username == null) {
      _showError(_auth.error ?? '無法進入');
      return;
    }
    _openApp(username);
  }

  void _openApp(String username) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AppShell(username: username)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Text('雷霆611', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: primary)),
                const SizedBox(height: 8),
                Text(_register ? '建立帳號' : '登入', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                SectionCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '暱稱', prefixIcon: Icon(Icons.person_outline_rounded)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '密碼',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                        ),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '班級代碼', prefixIcon: Icon(Icons.key_outlined)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: _auth,
                        builder: (context, _) => SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _auth.loading ? null : _submit,
                            child: _auth.loading
                                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                                : Text(_register ? '建立並進入' : '進入'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _auth.loading ? null : () => setState(() => _register = !_register),
                        child: Text(_register ? '已有帳號？登入' : '第一次使用？建立帳號'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('登入後資料會同步到伺服器', style: TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _code.dispose();
    _auth.dispose();
    super.dispose();
  }
}
