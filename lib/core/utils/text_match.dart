/// Совпадение текста с поисковым запросом по словам.
///
/// Все слова запроса должны найтись в строке, в любом порядке и в любом
/// месте. Обычного `contains` здесь мало: адреса в базе неформальные —
/// «Чиланзар, 12 квартал, дом 4, подъезд 2», — и запрос «чиланзар дом 4»
/// целиком в строке не встречается, хотя человек имел в виду именно её.
///
/// Регистр не важен. Пустой запрос совпадает со всем: фильтровать нечем.
bool matchesAllWords(String haystack, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;

  final text = haystack.toLowerCase();
  return words.every(text.contains);
}
