import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'action_feedback.dart';

/// Поле ввода с подписью сверху.
///
/// Это `TextFormField`: внутри [Form] участвует в валидации и показывает
/// ошибку под полем. При [obscureText] справа появляется кнопка «показать».
///
/// Момент первой подсветки задаёт форма — она ставит
/// `AutovalidateMode.onUnfocus`, и ошибка появляется, когда пользователь
/// закончил ввод и ушёл из этого поля, а не на первом же символе. Своё
/// `onUserInteractionIfError` нужно для второй половины сценария: пока
/// ошибка висит, каждое нажатие клавиши перепроверяет поле, и подсказка
/// гаснет сразу после исправления, а не при следующем уходе из поля.
class LabeledTextField extends StatefulWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.autofillHints,
    this.autofocus = false,
    this.copyable = false,
  });

  final String label;
  final String? hint;

  /// Пояснение под полем — видно, пока нет ошибки.
  final String? helper;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  /// Ограничение длины. Счётчик символов скрыт — он ломает вёрстку карточек.
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final bool autofocus;

  /// Показывать кнопку «скопировать».
  ///
  /// Нужна там, где значение подставило приложение, а передать его должен
  /// человек: стартовый пароль водителя генерируется и нигде больше не
  /// хранится — сбросить его потом нечем.
  final bool copyable;

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          widget.label,
          style: AppTypography.secondary
              .copyWith(color: t.text2, fontWeight: FontWeight.w600),
        ),
        TextFormField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: _obscured,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          autofillHints: widget.autofillHints,
          autofocus: widget.autofocus,
          style: TextStyle(color: t.text),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            counterText: '',
            suffixIcon: _suffix(t),
          ),
        ),
      ],
    );
  }

  /// Кнопки справа в поле. Их может быть две — «скопировать» и «показать».
  Widget? _suffix(AppTokens t) {
    final buttons = [
      if (widget.copyable) _copyButton(t),
      if (widget.obscureText) _revealButton(t),
    ];
    if (buttons.isEmpty) return null;
    if (buttons.length == 1) return buttons.first;
    // mainAxisSize.min обязателен: Row внутри suffixIcon иначе растягивается
    // на всю ширину поля и выдавливает текст за край.
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Widget _copyButton(AppTokens t) {
    return IconButton(
      icon: Icon(Icons.copy_rounded, size: 19, color: t.text3),
      tooltip: context.l10n.fieldCopy,
      onPressed: () {
        final value = widget.controller?.text ?? '';
        if (value.isEmpty) return;
        Clipboard.setData(ClipboardData(text: value));
        showAppSnackBar(context, context.l10n.fieldCopied);
      },
    );
  }

  Widget _revealButton(AppTokens t) {
    return IconButton(
      icon: Icon(
        _obscured
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 20,
        color: t.text3,
      ),
      tooltip: _obscured ? context.l10n.fieldShowPassword : context.l10n.fieldHidePassword,
      onPressed: () => setState(() => _obscured = !_obscured),
    );
  }
}
