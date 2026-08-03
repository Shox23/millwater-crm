import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../utils/initials.dart';

/// Аватар-инициалы: две буквы имени, цветной фон, скруглённый квадрат.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.tokens.avatarPalette;
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final bg = color ?? palette[hash % palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.avatar),
      ),
      child: Text(
        Initials.of(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
