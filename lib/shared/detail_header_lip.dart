import 'package:flutter/material.dart';
import 'package:kok_app/core/theme.dart';

class DetailHeaderLip extends StatelessWidget {
  const DetailHeaderLip({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Stack(
      children: [
        header,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('detail-header-lip'),
            height: KokRadii.contentTop,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(KokRadii.contentTop),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
