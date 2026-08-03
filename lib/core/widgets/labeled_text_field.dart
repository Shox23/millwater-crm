import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Поле ввода с подписью сверху.
///
/// Это `TextFormField`: внутри [Form] участвует в валидации и показывает
/// ошибку под полем. При [obscureText] справа появляется кнопка «показать».
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
            suffixIcon: widget.obscureText ? _revealButton(t) : null,
          ),
        ),
      ],
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
      tooltip: _obscured ? 'Показать пароль' : 'Скрыть пароль',
      onPressed: () => setState(() => _obscured = !_obscured),
    );
  }
}
