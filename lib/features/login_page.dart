import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/domain/auth_state.dart';
import '../core/auth/presentation/auth_controller.dart';
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
  bool _remember = false;
  bool _staySignedIn = false;
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedSk();
  }

  Future<void> _loadRememberedSk() async {
    final sk = await ref.read(rememberedSkStoreProvider).readSk();
    if (mounted && sk != null && sk.isNotEmpty) {
      setState(() {
        _sk.text = sk;
        _remember = true;
      });
    }
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
      final ok = await ref.read(authControllerProvider.notifier).login(
            skNumber: _sk.text.trim(),
            password: _password.text,
            staySignedIn: _staySignedIn,
            rememberSk: _remember,
          );
      if (ok) {
        try {
          await ref.read(sessionProvider.notifier).signIn(
                _sk.text.trim(),
                _password.text,
                _remember,
              );
        } catch (_) {}
      } else if (mounted) {
        final authState = ref.read(authControllerProvider);
        if (authState is AuthSignedOut && authState.errorMessage != null) {
          setState(() => _error = authState.errorMessage);
        } else {
          setState(() => _error = 'Nomor SK atau kata sandi tidak sesuai.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nomor SK atau kata sandi tidak sesuai.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showDemoAccountsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Akun Demo',
                style: TextStyle(
                  fontFamily: 'KokSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih salah satu profil untuk pengujian cepat:',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Text(
                    'PA',
                    style: TextStyle(
                      color: Color(0xFF1B4F9E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: const Text(
                  'Pak Asep · Kec. Garut Kota',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: KokColors.cardTitle,
                  ),
                ),
                subtitle: const Text(
                  'DEMO-001 · Koordinator Kecamatan',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                onTap: () {
                  setState(() {
                    _sk.text = 'DEMO-001';
                    _password.text = 'kokgarut123';
                    _error = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD1FAE5),
                  child: Text(
                    'PC',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: const Text(
                  'Pak Cecep · Kec. Tarogong Kidul',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: KokColors.cardTitle,
                  ),
                ),
                subtitle: const Text(
                  'DEMO-002 · Koordinator Kecamatan',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                onTap: () {
                  setState(() {
                    _sk.text = 'DEMO-002';
                    _password.text = 'koktarogong123';
                    _error = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFEE2E2)),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEE2E2),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Simulasi Gangguan Timeout',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: KokColors.cardTitle,
                  ),
                ),
                subtitle: const Text(
                  'DEMO-TIMEOUT · timeout123',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                onTap: () {
                  setState(() {
                    _sk.text = 'DEMO-TIMEOUT';
                    _password.text = 'timeout123';
                    _error = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                      child: AutofillGroup(
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
                                autofillHints: const [AutofillHints.password],
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
                              const SizedBox(height: 12),
                              // Checkbox 1: Ingat nomor SK (min tap target >= 44px)
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 44),
                                child: InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => setState(() => _remember = !_remember),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
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
                                          onChanged: _busy
                                              ? null
                                              : (v) => setState(
                                                  () => _remember = v ?? false,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Ingat nomor SK di perangkat ini',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF616161),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Checkbox 2: Tetap Masuk (min tap target >= 44px)
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 44),
                                child: InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => setState(
                                          () => _staySignedIn = !_staySignedIn,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _staySignedIn,
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
                                          onChanged: _busy
                                              ? null
                                              : (v) => setState(
                                                  () => _staySignedIn =
                                                      v ?? false,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Tetap Masuk',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF616161),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_error != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 14),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                      fontFamily: 'KokSans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
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
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _showDemoAccountsSheet(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0C2464),
                                    side: const BorderSide(
                                      color: Color(0xFFD4D8E0),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.account_circle_outlined,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Pilih Akun Demo',
                                    style: TextStyle(
                                      fontFamily: 'KokSans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Center(
                                child: SelectableText(
                                  'Mode demo: DEMO-001 · kokgarut123',
                                  style: TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
