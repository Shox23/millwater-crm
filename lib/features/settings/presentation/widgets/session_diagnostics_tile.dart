import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/observability/session_log.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/app_card.dart';

/// Пункт «Последний обрыв сессии».
///
/// Заведён после жалобы «один раз выкинуло»: разбирать такое по пересказу
/// нечем. Здесь видно время, причина, эндпоинт и код ответа — то, с чем
/// бэкенд сверит свой журнал. Тап копирует строку в буфер.
///
/// Один и тот же пункт в настройках админа и в профиле водителя: выкинуть
/// может обоих.
class SessionDiagnosticsTile extends StatefulWidget {
  const SessionDiagnosticsTile({super.key});

  @override
  State<SessionDiagnosticsTile> createState() => _SessionDiagnosticsTileState();
}

class _SessionDiagnosticsTileState extends State<SessionDiagnosticsTile> {
  SessionEnd? _end;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Журнал читается необязательным — тем же приёмом, что и поток
    // уведомлений в `notifications_scope.dart`. Боевое дерево его кладёт, а
    // виджет-тесты собирают экран вокруг одного репозитория, и обязательный
    // провайдер уронил бы их все. Экран без журнала просто не показывает
    // пункт; это рабочее поведение, а не сбой.
    final log = context.read<SessionLog?>();
    if (log == null) return;

    // Хранилище ошибок не бросает — см. [SessionLog].
    final end = await log.last();
    if (!mounted) return;
    setState(() {
      _end = end;
      _ready = true;
    });
  }

  Future<void> _copy(SessionEnd end) async {
    await Clipboard.setData(ClipboardData(text: end.details));
    if (mounted) showAppSnackBar(context, context.l10n.sessionDiagCopied);
  }

  /// Причина словами. Обычный выход тоже записывается — иначе «выкинуло» не
  /// отличить от «вышел сам».
  String _reason(AppLocalizations l10n, SessionEndReason reason) =>
      switch (reason) {
        SessionEndReason.refreshFailed => l10n.sessionEndRefreshFailed,
        SessionEndReason.restoreRejected => l10n.sessionEndRestoreRejected,
        SessionEndReason.signedOut => l10n.sessionEndSignedOut,
      };

  @override
  Widget build(BuildContext context) {
    // Пока не прочитали (или журнала в дереве нет) — пункта не показываем:
    // мигнуть «Обрывов не было» и тут же подменить его записью хуже, чем
    // показать её кадром позже.
    if (!_ready) return const SizedBox.shrink();

    final t = context.tokens;
    final l10n = context.l10n;
    final end = _end;

    final subtitle = end == null
        ? l10n.sessionDiagNever
        : '${DateFormat('dd.MM.yyyy · HH:mm').format(end.at)} — '
            '${_reason(l10n, end.reason)}'
            '${end.statusCode == null ? '' : ' (${end.statusCode})'}';

    return AppCard(
      onTap: end == null ? null : () => _copy(end),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.softOf(t.text2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.history_outlined, size: 20, color: t.text2),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(l10n.sessionDiagTitle,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Text(subtitle,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
              ],
            ),
          ),
          if (end != null) Icon(Icons.copy_outlined, size: 18, color: t.text2),
        ],
      ),
    );
  }
}
