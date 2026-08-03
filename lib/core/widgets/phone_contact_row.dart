import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/uz_phone.dart';
import 'action_feedback.dart';
import 'app_button.dart';
import 'contact_row.dart';

/// Строка с телефоном: тап — звонок, кнопка справа — копирование.
///
/// В CRM доставки позвонить заказчику нужно чаще всего остального,
/// а раньше номер был просто текстом.
class PhoneContactRow extends StatelessWidget {
  const PhoneContactRow({
    super.key,
    required this.phone,
    this.label = 'Телефон',
  });

  final String phone;
  final String label;

  bool get _hasNumber => UzPhone.subscriberDigits(phone).isNotEmpty;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: UzPhone.normalize(phone));
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) _copy(context, failedCall: true);
    } catch (_) {
      // На десктопе и в части браузеров tel: не обрабатывается — копируем.
      if (context.mounted) _copy(context, failedCall: true);
    }
  }

  Future<void> _copy(BuildContext context, {bool failedCall = false}) async {
    await Clipboard.setData(ClipboardData(text: UzPhone.normalize(phone)));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      failedCall ? 'Звонок недоступен — номер скопирован' : 'Номер скопирован',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasNumber) {
      return ContactRow(icon: Icons.call, label: label, value: '—');
    }
    return InkWell(
      onTap: () => _call(context),
      borderRadius: BorderRadius.circular(8),
      child: ContactRow(
        icon: Icons.call,
        label: label,
        value: UzPhone.format(phone),
        trailing: IconActionButton(
          icon: Icons.copy_rounded,
          tooltip: 'Скопировать номер',
          onPressed: () => _copy(context),
        ),
      ),
    );
  }
}
