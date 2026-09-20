import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MissingPage extends StatelessWidget {
  const MissingPage({
    super.key,
    this.title = 'Data tidak ditemukan',
    this.message,
  });

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Kembali ke beranda'),
          ),
        ],
      ),
    ),
  );
}
