# Login UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoles tampilan layar Login (`LoginPage`) agar presisi sesuai acuan desain Figma `ui-screenshot-figma/login.png`, menggunakan CustomPainter untuk aksen dekoratif, penataan logo dan sepasang maskot simetris, styling input rounded elegan, serta penyempurnaan copywriting baku.

**Architecture:** Memisahkan komponen dekoratif latar belakang (`LoginHeaderDecoration` & `LoginHeaderPainter`) ke dalam widget tersendiri agar modular dan terisolasi. Menyusun ulang form dan kontrol interaktif pada `LoginPage` dengan `InputDecoration` custom, serta memperbarui assertion pengujian pada `test/app_test.dart`.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Flutter Riverpod, GoRouter, Material 3 with Custom Canvas Painting.

## Global Constraints

- Sesuai dengan spesifikasi `docs/superpowers/specs/2026-09-05-login-ui-polish-design.md`.
- Copywriting baku: "Selamat Datang!", "Silakan masuk untuk melanjutkan", "Masuk Akun", "Gunakan akun KOK Anda untuk mengakses sistem", "Nomor SK", "Kata Sandi", "Ingat Saya", "Masuk", "Mode demo: DEMO-001 · kokgarut123".
- Warna navy utama tombol: `#061A5C`, gradien header: `#07237B` ke `#03144B`.
- Menjaga fungsionalitas login mock demo dan penyimpanan nomor SK via SharedPreferences.
- `flutter analyze` harus tetap 0 issues dan `flutter test` harus 100% lulus.

---

### Task 1: Komponen Dekorasi Header & CustomPainter (Wave & Dot Matrix)

**Files:**
- Create: `lib/features/login_decorations.dart`
- Test: `test/login_decorations_test.dart`

**Interfaces:**
- Produces:
  - `class LoginHeaderDecoration extends StatelessWidget`: Widget yang merender latar belakang gradasi biru tua beserta aksen garis lengkung emas/cyan dan dot matrix di atasnya.
  - `class LoginHeaderPainter extends CustomPainter`: Custom painter yang menggambar dua kurva lengkung di kiri atas dan dot matrix di kanan atas.

- [ ] **Step 1: Tulis unit/widget test untuk `LoginHeaderDecoration`**

```dart
// test/login_decorations_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/login_decorations.dart';

void main() {
  testWidgets('LoginHeaderDecoration renders child with CustomPaint background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoginHeaderDecoration(
            child: Text('Header Content'),
          ),
        ),
      ),
    );

    expect(find.text('Header Content'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan (file belum ada)**

Run: `flutter test test/login_decorations_test.dart`  
Expected: FAIL (Compilation error / file not found)

- [ ] **Step 3: Implementasikan `lib/features/login_decorations.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoginHeaderDecoration extends StatelessWidget {
  const LoginHeaderDecoration({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 28),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF07237B),
            Color(0xFF03144B),
          ],
        ),
      ),
      child: CustomPaint(
        painter: const LoginHeaderPainter(),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class LoginHeaderPainter extends CustomPainter {
  const LoginHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Gambar Dot Matrix di kanan atas
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const rows = 8;
    const cols = 6;
    const spacing = 14.0;
    final startX = size.width - (cols * spacing) - 12;
    const startY = 16.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + (c * spacing), startY + (r * spacing)),
          1.8,
          dotPaint,
        );
      }
    }

    // 2. Gambar Kurva Lengkung Elegan di kiri atas
    final goldLinePaint = Paint()
      ..color = const Color(0xFFE2B743).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final cyanLinePaint = Paint()
      ..color = const Color(0xFF1E88E5).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final goldPath = Path()
      ..moveTo(0, size.height * 0.10)
      ..cubicTo(
        size.width * 0.25, size.height * 0.08,
        size.width * 0.15, size.height * 0.38,
        0, size.height * 0.46,
      );

    final cyanPath = Path()
      ..moveTo(0, size.height * 0.04)
      ..cubicTo(
        size.width * 0.35, size.height * 0.05,
        size.width * 0.25, size.height * 0.44,
        0, size.height * 0.54,
      );

    canvas.drawPath(cyanPath, cyanLinePaint);
    canvas.drawPath(goldPath, goldLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Jalankan test kembali untuk memverifikasi kelulusan**

Run: `flutter test test/login_decorations_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit perubahan**

```bash
git add lib/features/login_decorations.dart test/login_decorations_test.dart
git commit -m "feat(login): tambahkan komponen dekorasi header dan custom painter"
```

---

### Task 2: Pemolesan Komprehensif Halaman Login (`lib/features/login_page.dart`)

**Files:**
- Modify: `lib/features/login_page.dart`
- Consumes: `LoginHeaderDecoration` dari `lib/features/login_decorations.dart`
- Test: `test/app_test.dart`

- [ ] **Step 1: Rancang ulang `LoginPage` sesuai spesifikasi Figma**

Poin pembaruan pada `lib/features/login_page.dart`:
1. Ganti background header lama dengan `LoginHeaderDecoration`.
2. Hapus tulisan atas `"KONI KABUPATEN GARUT"`.
3. Tata letak logo KONI di tengah diapit 2 maskot:
   - Kiri: `Image.asset('assets/branding/mascot.png', width: 72, height: 88)`
   - Tengah: `Image.asset('assets/branding/logo-koni.png', width: 104, height: 114)`
   - Kanan: `Transform.flip(flipX: true, child: Image.asset('assets/branding/mascot.png', width: 72, height: 88))`
4. Teks sambutan:
   - `"Selamat Datang!"` (26pt, bold, putih)
   - `"Silakan masuk untuk melanjutkan"` (14pt, putih 70%)
5. Sheet bawah:
   - `BorderRadius.vertical(top: Radius.circular(32))`
   - Judul: `"Masuk Akun"`, Subjudul: `"Gunakan akun KOK Anda untuk mengakses sistem"`
   - Label: `"Nomor SK"`, Input prefix icon: `Icons.account_circle_outlined`, hint: `"Masukkan nomor SK"`
   - Label: `"Kata Sandi"`, Input prefix icon: `Icons.lock_outline`, suffix toggle eye, hint: `"Masukkan kata sandi"`
   - Checkbox: `"Ingat Saya"`
   - Tombol Utama: Text `"Masuk"`, Icon `Icons.login_rounded`, warna `#061A5C`, radius 12
   - Catatan Demo bawah: teks subtle `"Mode demo: DEMO-001 · kokgarut123"`

- [ ] **Step 2: Jalankan analyzer untuk memastikan kode bersih**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Commit perubahan pada `login_page.dart`**

```bash
git add lib/features/login_page.dart
git commit -m "feat(login): implementasikan pemolesan UI login sesuai acuan figma"
```

---

### Task 3: Pembaruan Test Suite & Validasi Menyeluruh

**Files:**
- Modify: `test/app_test.dart`

- [ ] **Step 1: Perbarui assertion teks pada `test/app_test.dart`**

Sesuaikan target pencarian teks yang diperbarui:
- Dari `find.text('Login Akun')` ke `find.text('Masuk Akun')`.
- Dari `find.text('Masuk demo')` ke `find.text('Masuk')`.

- [ ] **Step 2: Jalankan seluruh test suite**

Run: `flutter test`  
Expected: All tests passed!

- [ ] **Step 3: Jalankan analisis linter**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 4: Commit pembaruan test**

```bash
git add test/app_test.dart
git commit -m "test: perbarui ekspektasi teks widget test untuk login page yang telah dipoles"
```
