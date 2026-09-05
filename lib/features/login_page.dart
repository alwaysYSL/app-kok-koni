import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/session.dart';
import '../core/theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _sk = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false, _hidden = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _sk.text = ref.read(preferencesProvider).getString('remembered_sk') ?? '';
    _remember = _sk.text.isNotEmpty;
  }

  @override
  void dispose() {
    _sk.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(sessionProvider.notifier)
          .signIn(_sk.text, _password.text, _remember);
      if (mounted && !ok) {
        setState(() => _error = 'Nomor SK atau kata sandi demo tidak sesuai.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Preferensi gagal disimpan. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF143E9D), KokColors.navy],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KONI KABUPATEN GARUT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/branding/logo-koni.png',
                            width: 102,
                            height: 112,
                            semanticLabel: 'Logo KONI Garut',
                          ),
                          const SizedBox(width: 24),
                          Image.asset(
                            'assets/branding/mascot.png',
                            width: 70,
                            height: 90,
                            semanticLabel: 'Maskot domba Garut',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Selamat Datang!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bersama memajukan olahraga Garut.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Login Akun',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: KokColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Koordinator Organisasi Kecamatan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: KokColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'Nomor SK',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KokColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sk,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            hintText: 'Masukkan nomor SK',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nomor SK wajib diisi.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Kata sandi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KokColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidden,
                          enableSuggestions: false,
                          autocorrect: false,
                          onFieldSubmitted: (_) => _busy ? null : _submit(),
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Tampilkan kata sandi'
                                  : 'Sembunyikan kata sandi',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Kata sandi wajib diisi.'
                              : null,
                        ),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'Ingat nomor SK',
                              style: TextStyle(
                                fontSize: 13,
                                color: KokColors.muted,
                              ),
                            ),
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? false),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: KokColors.red),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: KokColors.navy,
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Masuk demo'),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: KokColors.pale,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'AKUN DEMO',
                                style: TextStyle(
                                  color: KokColors.ink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              SizedBox(height: 4),
                              SelectableText(
                                'DEMO-001  /  kokgarut123',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: KokColors.ink,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Autentikasi SICABOR belum terhubung.',
                                style: TextStyle(
                                  color: KokColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
