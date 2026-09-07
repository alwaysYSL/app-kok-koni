import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MissingPage extends StatelessWidget {
  const MissingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data tidak ditemukan')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/home'),
        child: const Text('Kembali ke beranda'),
      ),
    ),
  );
}
