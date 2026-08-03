import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Поле поиска: рамка 1.5px, радиус 13, фокус — акцентная рамка.
///
/// Кнопка очистки появляется, как только в поле что-то есть.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  /// Свой контроллер освобождаем, переданный снаружи — нет.
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextField(
      controller: _controller,
      onChanged: (value) {
        widget.onChanged?.call(value);
        setState(() {});
      },
      textInputAction: TextInputAction.search,
      style: TextStyle(color: t.text),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(Icons.search, color: t.text3, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: t.text3, size: 20),
                tooltip: 'Очистить',
                onPressed: _clear,
              ),
      ),
    );
  }
}
