# Правила R8 для release-сборки.
#
# Flutter-плагин сам добавляет keep-правила для движка и
# GeneratedPluginRegistrant, поэтому здесь только то, что не покрыто им.

# flutter_secure_storage тянет androidx.security.crypto, а та через рефлексию
# добирается до Tink. Без keep'а R8 вырезает провайдеры, и чтение токена
# падает уже в проде — там, где отладчика нет.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Аннотации ошибок, на которые ссылаются зависимости AndroidX.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
