import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

class ClubDocumentTab extends StatelessWidget {
  const ClubDocumentTab({super.key, required this.club});

  final Club club;

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('verif') ||
        s.contains('lengkap') ||
        s.contains('tersedia') ||
        s.contains('sah')) {
      return const Color(0xFF176B38);
    }
    if (s.contains('pending') ||
        s.contains('review') ||
        s.contains('tinjau') ||
        s.contains('proses')) {
      return const Color(0xFFB45309);
    }
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final documents = club.documents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (documents.isEmpty)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.folder_off_outlined,
                  color: KokColors.muted,
                  size: 28,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Data dokumen klub belum tersedia.',
                  style: TextStyle(
                    color: KokColors.cardTitle,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dokumen akan tampil setelah tersedia dari sumber data resmi.',
                  style: TextStyle(color: KokColors.muted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          for (final document in documents)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: const TextStyle(
                      color: KokColors.cardTitle,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    document.status,
                    style: TextStyle(
                      color: _statusColor(document.status),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (document.fileUrl != null &&
                      document.fileUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Berkas tersedia',
                      style: TextStyle(color: KokColors.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Data demo lokal—belum terhubung dengan SICABOR. Perubahan diajukan lewat pengurus klub.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KokColors.muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
