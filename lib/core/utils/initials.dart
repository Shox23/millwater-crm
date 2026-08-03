/// Инициалы из имени/названия для аватарки: "Азиз Каримов" -> "АК".
abstract class Initials {
  static String of(String name) {
    final cleaned = name.replaceAll(RegExp(r'[«»"()]'), ' ').trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      final take = w.length >= 2 ? w.substring(0, 2) : w;
      return take.toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
