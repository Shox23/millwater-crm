import 'package:crm_millwater/app/locale_cubit.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/drivers/presentation/drivers_page.dart';
import 'package:crm_millwater/features/settings/presentation/widgets/language_selector_card.dart';
import 'package:crm_millwater/l10n/app_localizations_ru.dart';
import 'package:crm_millwater/l10n/app_localizations_uz.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Строки есть на обоих языках', () {
    test('узбекская локаль переводит статусы, фильтры и роли', () {
      final uz = AppLocalizationsUz();
      final ru = AppLocalizationsRu();

      for (final status in DeliveryStatus.values) {
        expect(status.label(uz), isNotEmpty);
        expect(status.label(uz), isNot(status.label(ru)),
            reason: 'статус ${status.wire} остался по-русски');
      }
      for (final status in RouteStatus.values) {
        expect(status.label(uz), isNot(status.label(ru)));
      }
      for (final filter in RouteFilter.values) {
        expect(filter.label(uz), isNotEmpty);
      }
      for (final method in PaymentMethod.values) {
        expect(method.label(uz), isNot(method.label(ru)));
      }
    });

    test('деньги и склонения зависят от языка', () {
      final uz = AppLocalizationsUz();
      final ru = AppLocalizationsRu();

      expect(ru.moneyAmount('20 000'), '20 000 сум');
      expect(uz.moneyAmount('20 000'), '20 000 so‘m');

      // Русские склонения: 1 капсула · 2 капсулы · 5 капсул.
      expect(ru.capsulesCount(1), '1 капсула');
      expect(ru.capsulesCount(2), '2 капсулы');
      expect(ru.capsulesCount(5), '5 капсул');
      // В узбекском форма одна.
      expect(uz.capsulesCount(1), '1 kapsula');
      expect(uz.capsulesCount(5), '5 kapsula');
    });
  });

  group('Выбор языка', () {
    test('без явного выбора берётся системный, иначе русский', () {
      expect(LocaleCubit.resolve(null, const Locale('uz')), AppLocales.uz);
      expect(LocaleCubit.resolve(null, const Locale('ru')), AppLocales.ru);
      // Незнакомый язык — русский, а не пустой экран.
      expect(LocaleCubit.resolve(null, const Locale('en')), AppLocales.ru);
      expect(LocaleCubit.resolve(null, null), AppLocales.ru);
      // Явный выбор перекрывает систему.
      expect(LocaleCubit.resolve(AppLocales.ru, const Locale('uz')),
          AppLocales.ru);
    });

    testWidgets('переключатель меняет язык интерфейса', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final locale = LocaleCubit();
      await tester.pumpWidget(
        BlocProvider.value(
          value: locale,
          child: RepositoryProvider<CrmRepository>.value(
            value: MockCrmRepository(),
            child: BlocBuilder<LocaleCubit, Locale?>(
              bloc: locale,
              builder: (context, selected) => MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocales.supported,
                locale: selected ?? AppLocales.ru,
                theme: AppTheme.light(),
                home: const Scaffold(
                  body: Column(
                    children: [LanguageSelectorCard(), Expanded(child: DriversPage())],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Водители'), findsWidgets);

      await tester.tap(find.text('O‘zbekcha').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Экран перерисовался на узбекском, русских подписей не осталось.
      expect(find.text('Haydovchilar'), findsWidgets);
      expect(find.text('Водители'), findsNothing);
    });
  });
}
