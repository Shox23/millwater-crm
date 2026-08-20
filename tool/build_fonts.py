#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Пересобирает шрифты приложения из вариативных Inter и Onest.

Зачем: раньше шрифты тянул `google_fonts` с fonts.gstatic.com при первом
запуске. Водитель, впервые открывший приложение без связи, видел системный
шрифт вместо макета, а обращение к стороннему сервису приходилось объявлять
в Play Data Safety и App Privacy.

Что делает:
  * закрепляет ось веса вариативного шрифта в статические начертания —
    Flutter надёжно работает со статикой, а вариативную ось разные платформы
    применяют по-разному;
  * режет набор символов до того, что приложению нужно: латиница (узбекский),
    кириллица (русский) и используемая типографика.

Итог — 1,2 МБ на десять файлов вместо ~8 МБ полных начертаний.

Запуск:
    python3 -m venv .fontenv
    .fontenv/bin/pip install fonttools brotli
    .fontenv/bin/python tool/build_fonts.py

Лицензия шрифтов — SIL OFL 1.1, она допускает изменение и встраивание.
Файлы лицензий лежат рядом со шрифтами: assets/fonts/Inter-OFL.txt
и assets/fonts/Onest-OFL.txt — у семейств разные правообладатели.
"""
import os
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.subset import Subsetter, Options

OUT_DIR = 'assets/fonts'

SOURCES = {
    # семейство: (адрес вариативного файла, чем закрепить прочие оси)
    'Inter': (
        'https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf',
        # Оптический размер: 14 — значение по умолчанию, с ним же отдаёт
        # статику Google Fonts. Приложение рисует текст от 10.5 до 30 px,
        # и одно значение оси на все размеры оставляет вид прежним.
        {'opsz': 14},
    ),
    'Onest': (
        'https://github.com/google/fonts/raw/main/ofl/onest/Onest%5Bwght%5D.ttf',
        {},
    ),
}

# Начертания, которые действительно встречаются в стилях приложения:
# AppTypography и DesktopTypography плюс базовая тема Material (400).
WEIGHTS = [400, 500, 600, 700, 800]

# Диапазоны символов. Всё остальное из шрифта вырезается.
RANGES = [
    (0x0020, 0x007F),  # ASCII
    (0x00A0, 0x00FF),  # латиница-1: « » · °
    (0x0100, 0x017F),  # латиница расширенная A
    (0x02B0, 0x02FF),  # модификаторы: ʻ узбекского алфавита
    (0x0300, 0x036F),  # комбинируемые диакритики
    (0x0400, 0x04FF),  # кириллица
    (0x2000, 0x206F),  # пунктуация: — … • ‘ ’ “ ”
    (0x20A0, 0x20BF),  # символы валют
]
EXTRA = [0x2116]  # №


def unicodes():
    codes = []
    for start, end in RANGES:
        codes.extend(range(start, end + 1))
    codes.extend(EXTRA)
    return codes


def build(family, url, pins, cache_dir):
    source = os.path.join(cache_dir, f'{family}-var.ttf')
    if not os.path.exists(source):
        print(f'скачиваю {family}…')
        urllib.request.urlretrieve(url, source)

    codes = unicodes()
    for weight in WEIGHTS:
        font = instancer.instantiateVariableFont(
            TTFont(source), {'wght': weight, **pins}
        )

        options = Options()
        options.layout_features = ['*']
        options.name_IDs = ['*']
        options.notdef_outline = True

        subsetter = Subsetter(options=options)
        subsetter.populate(unicodes=codes)
        subsetter.subset(font)

        path = os.path.join(OUT_DIR, f'{family}-{weight}.ttf')
        font.save(path)
        font.close()
        print(f'  {path}  {os.path.getsize(path) // 1024} КБ')


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    cache_dir = os.path.join(OUT_DIR, '.src')
    os.makedirs(cache_dir, exist_ok=True)

    for family, (url, pins) in SOURCES.items():
        build(family, url, pins, cache_dir)

    print('\nГотово. Веса и семейства объявлены в pubspec.yaml.')


if __name__ == '__main__':
    main()
