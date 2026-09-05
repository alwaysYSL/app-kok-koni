import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'login_decorations.dart';

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
    backgroundColor: const Color(0xFF03144B),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  LoginHeaderDecoration(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/branding/mascot.png',
                                width: 72,
                                height: 88,
                                semanticLabel: 'Maskot domba Garut kiri',
                              ),
                              const SizedBox(width: 14),
                              Image.asset(
                                'assets/branding/logo-koni.png',
                                width: 104,
                                height: 114,
                                semanticLabel: 'Logo KONI Garut',
                              ),
                              const SizedBox(width: 14),
                              Transform.flip(
                                flipX: true,
                                child: Image.asset(
                                  'assets/branding/mascot.png',
                                  width: 72,
                                  height: 88,
                                  semanticLabel: 'Maskot domba Garut kanan',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Selamat Datang!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Silakan masuk untuk melanjutkan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Masuk Akun',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C2464),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gunakan akun KOK Anda untuk mengakses sistem',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'Nomor SK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C2464),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _sk,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: InputDecoration(
                                hintText: 'Masukkan nomor SK',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.account_circle_outlined,
                                  color: Color(0xFF757575),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D8E0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D8E0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0C2464),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Nomor SK wajib diisi.'
                                      : null,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Kata Sandi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C2464),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _password,
                              obscureText: _hidden,
                              enableSuggestions: false,
                              autocorrect: false,
                              onFieldSubmitted: (_) =>
                                  _busy ? null : _submit(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan kata sandi',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF757575),
                                ),
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
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D8E0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4D8E0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0C2464),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty
                                      ? 'Kata sandi wajib diisi.'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _remember,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    activeColor: const Color(0xFF061A5C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF9E9E9E),
                                      width: 1.5,
                                    ),
                                    onChanged: (v) => setState(
                                      () => _remember = v ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _remember = !_remember,
                                  ),
                                  child: const Text(
                                    'Ingat Saya',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF616161),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: KokColors.red,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF061A5C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.login_rounded,
                                        size: 20,
                                      ),
                                label: const Text('Masuk'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Center(
                              child: SelectableText(
                                'Mode demo: DEMO-001 · kokgarut123',
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
      ),
    ),
  );
}
