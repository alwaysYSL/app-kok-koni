import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'club_brand_palette.dart';
import 'club_people_filter.dart';

class ClubPersonCard extends StatelessWidget {
  const ClubPersonCard({
    super.key,
    required this.person,
    required this.palette,
    required this.onTap,
  });

  final SportPerson person;
  final ClubBrandPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      ?person.gender,
      if (person.age case final value?) '$value th',
      if (person.group.trim().isNotEmpty) person.group,
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _PersonMedia(person: person, palette: palette),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF17191D),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadata.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KokColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _trailingState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailingState() {
    if (personNeedsAttention(person)) {
      final label = person.role == 'Pelatih' && person.expiredLicense
          ? 'lisensi'
          : person.role == 'Official' && !person.verified
          ? 'verifikasi'
          : 'berkas';
      return _IssueBadge(label: label);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.softAccent,
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: Icon(Icons.check_rounded, size: 20, semanticLabel: 'Lengkap'),
      ),
    );
  }
}

class _PersonMedia extends StatelessWidget {
  const _PersonMedia({required this.person, required this.palette});

  final SportPerson person;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final photoUrl = person.photoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty) return _initials();
    return Semantics(
      label: 'Foto ${person.name}',
      image: true,
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initials(),
        ),
      ),
    );
  }

  Widget _initials() {
    final words = person.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Semantics(
      label: 'Inisial ${person.name}',
      image: true,
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: 24,
          backgroundColor: palette.fallbackAvatar,
          foregroundColor: palette.foreground,
          child: Text(
            initials,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _IssueBadge extends StatelessWidget {
  const _IssueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: KokColors.red,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
