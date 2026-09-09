import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

class ClubDocumentTab extends StatelessWidget {
  const ClubDocumentTab({super.key, required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    final registration = club.registrationNumber;
    final available = registration != null && registration.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final title in ['SK Klub', 'Kepengurusan'])
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: KokColors.cardTitle,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title == 'SK Klub' && available
                      ? 'Tersedia'
                      : 'Belum tersedia',
                  style: TextStyle(
                    color: title == 'SK Klub' && available
                        ? const Color(0xFF176B38)
                        : const Color(0xFF4B5563),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title == 'SK Klub' && available) ...[
                  const SizedBox(height: 6),
                  Text(
                    registration,
                    style: const TextStyle(color: KokColors.muted),
                  ),
                ],
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Data milik SICABOR. Perubahan diajukan lewat pengurus klub — aplikasi ini tidak menyunting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KokColors.muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
