import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Круглая кнопка «назад» на поверхности.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          mouseCursor: SystemMouseCursors.click,
          child: Icon(Icons.chevron_left, color: t.text, size: 26),
        ),
      ),
    );
  }
}

/// Каркас экрана-оверлея: шапка с «назад», прокручиваемое тело и нижняя панель.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.scrollable = true,
  });

  final String title;
  final Widget body;
  final Widget? bottomBar;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      child: body,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  const CircleBackButton(),
                  Expanded(
                    child: Text(
                      title,
                      style:
                          AppTypography.appBarTitle.copyWith(color: t.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  scrollable ? SingleChildScrollView(child: content) : content,
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
