import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Склонение числительных в строках, где раньше его не было.
///
/// «1 точек» и «1 капсул» стояли на самых заметных экранах: в списке
/// маршрутов у админа и в карточке точки у водителя. Одна капсула и маршрут
/// из одной точки — обычное дело, а не край.
void main() {
  late AppLocalizations ru;
  late AppLocalizations uz;

  setUp(() async {
    ru = await AppLocalizations.delegate.load(AppLocales.ru);
    uz = await AppLocalizations.delegate.load(AppLocales.uz);
  });

  group('Точки маршрута', () {
    test('русский склоняет по всем формам', () {
      expect(ru.routeStopsCount(1), '1 точка');
      expect(ru.routeStopsCount(2), '2 точки');
      expect(ru.routeStopsCount(3), '3 точки');
      expect(ru.routeStopsCount(5), '5 точек');
      expect(ru.routeStopsCount(11), '11 точек');
      expect(ru.routeStopsCount(21), '21 точка');
      expect(ru.routeStopsCount(22), '22 точки');
    });

    test('в узбекском числительное форму не меняет', () {
      expect(uz.routeStopsCount(1), '1 nuqta');
      expect(uz.routeStopsCount(5), '5 nuqta');
    });
  });

  group('Капсулы', () {
    test('склоняются в карточке точки', () {
      expect(ru.stopCapsules(1), '1 капсула');
      expect(ru.stopCapsules(2), '2 капсулы');
      expect(ru.stopCapsules(5), '5 капсул');
    });

    test('и там, где склонение уже было, ничего не сломалось', () {
      expect(ru.capsulesCount(1), '1 капсула');
      expect(ru.capsulesCount(5), '5 капсул');
    });
  });

  group('Длина поля', () {
    test('склоняется на всех значениях, с которыми её вызывают', () {
      // maxLen вызывается с 10, 120, 160, 200, 255, 300; минимум пароля — 6.
      expect(ru.fieldMinLength(6), 'Минимум 6 символов');
      expect(ru.fieldMaxLength(10), 'Не более 10 символов');
      expect(ru.fieldMaxLength(120), 'Не более 120 символов');
      expect(ru.fieldMaxLength(300), 'Не более 300 символов');
      // Единица раньше давала «Минимум 1 символов».
      expect(ru.fieldMinLength(1), 'Минимум 1 символ');
    });

    test('телефон просит именно девять цифр, а не «9 цифр» наугад', () {
      expect(ru.fieldPhoneIncomplete(9), 'Номер неполный — нужно 9 цифр после +998');
    });
  });

  group('Единицы и написание', () {
    test('сокращение «шт.» с точкой', () {
      expect(ru.reportsCapsulesCount(12), '12 шт.');
    });

    test('пробел перед единицей объёма', () {
      expect(ru.completionCapsulesCaption(19), 'капсул 19 л');
    });
  });

  group('Статусы доставки согласованы по роду', () {
    test('русский', () {
      // «Доставлен» рядом с «Не доставлено» стояли в одном переключателе.
      expect(ru.deliveryDelivered, 'Доставлено');
      expect(ru.deliveryFailed, 'Не доставлено');
    });
  });

  group('Узбекский называет заказчика одним словом', () {
    test('везде Mijoz, нигде Buyurtmachi', () {
      final samples = [
        uz.desktopAddCustomer,
        uz.desktopColCustomer,
        uz.customersCount(3),
        uz.desktopKpiPlannedCustomers,
        uz.desktopCapsulesWithCooler,
        uz.customersTitle,
        uz.customerTitle,
      ];
      for (final text in samples) {
        expect(text.toLowerCase(), isNot(contains('buyurtmachi')),
            reason: 'в строке «$text» остался второй термин');
      }
    });
  });
}
