import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/app_models.dart';
import '../app_tokens.dart';

/// Compact pill showing a [ProfileFit] label — the only match signal the app
/// displays for schools, programmes and fields of study (no percentage, no
/// admission odds; never on a scholarship; see [ProfileFit]).
class ProfileFitBadge extends StatelessWidget {
  const ProfileFitBadge({super.key, required this.fit, this.fontSize = 11.5});

  final ProfileFit fit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = fit.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Text(
        fit.labelKey.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
