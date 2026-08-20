import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'CRM Millwater'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get commonCancel;

  /// No description provided for @commonCancelShort.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancelShort;

  /// No description provided for @commonDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @commonSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение…'**
  String get commonSaving;

  /// No description provided for @commonAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get commonAdd;

  /// No description provided for @commonCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get commonCreate;

  /// No description provided for @commonCreating.
  ///
  /// In ru, this message translates to:
  /// **'Создание…'**
  String get commonCreating;

  /// No description provided for @commonEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get commonRetry;

  /// No description provided for @commonLeave.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get commonLeave;

  /// No description provided for @commonStay.
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get commonStay;

  /// No description provided for @commonOptional.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно'**
  String get commonOptional;

  /// No description provided for @commonClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get commonClear;

  /// No description provided for @commonNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get commonNothingFound;

  /// No description provided for @commonDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено'**
  String get commonDone;

  /// No description provided for @commonPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get commonPhone;

  /// No description provided for @commonSum.
  ///
  /// In ru, this message translates to:
  /// **'сум'**
  String get commonSum;

  /// No description provided for @moneyAmount.
  ///
  /// In ru, this message translates to:
  /// **'{amount} сум'**
  String moneyAmount(String amount);

  /// No description provided for @moneyMillions.
  ///
  /// In ru, this message translates to:
  /// **'{amount} млн сум'**
  String moneyMillions(String amount);

  /// No description provided for @leaveWithoutSavingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти без сохранения?'**
  String get leaveWithoutSavingTitle;

  /// No description provided for @leaveWithoutSavingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Введённые данные будут потеряны.'**
  String get leaveWithoutSavingMessage;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие. Попробуйте ещё раз.'**
  String get errorGeneric;

  /// No description provided for @errorNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером.'**
  String get errorNoConnection;

  /// No description provided for @errorLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные'**
  String get errorLoadFailed;

  /// No description provided for @errorCheckConnection.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте подключение и попробуйте ещё раз'**
  String get errorCheckConnection;

  /// No description provided for @emptySearchTitle.
  ///
  /// In ru, this message translates to:
  /// **'По запросу «{query}» ничего нет'**
  String emptySearchTitle(String query);

  /// No description provided for @emptySearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте написание или сбросьте поиск'**
  String get emptySearchHint;

  /// No description provided for @emptySearchAction.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить поиск'**
  String get emptySearchAction;

  /// No description provided for @fieldRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните поле'**
  String get fieldRequired;

  /// No description provided for @fieldPhoneEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона'**
  String get fieldPhoneEmpty;

  /// No description provided for @fieldPhoneIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'Номер неполный — нужно {count, plural, one{{count} цифра} few{{count} цифры} other{{count} цифр}} после +998'**
  String fieldPhoneIncomplete(int count);

  /// No description provided for @fieldEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат почты'**
  String get fieldEmailInvalid;

  /// No description provided for @fieldEmailEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите электронную почту'**
  String get fieldEmailEmpty;

  /// No description provided for @fieldPasswordEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get fieldPasswordEmpty;

  /// No description provided for @fieldMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимум {count, plural, one{{count} символ} few{{count} символа} other{{count} символов}}'**
  String fieldMinLength(int count);

  /// No description provided for @fieldMaxLength.
  ///
  /// In ru, this message translates to:
  /// **'Не более {count, plural, one{{count} символа} few{{count} символов} other{{count} символов}}'**
  String fieldMaxLength(int count);

  /// No description provided for @fieldShowPassword.
  ///
  /// In ru, this message translates to:
  /// **'Показать пароль'**
  String get fieldShowPassword;

  /// No description provided for @fieldHidePassword.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть пароль'**
  String get fieldHidePassword;

  /// No description provided for @validationGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте правильность заполнения'**
  String get validationGeneric;

  /// No description provided for @validationRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните поле «{field}»'**
  String validationRequired(String field);

  /// No description provided for @validationTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Слишком короткое значение в поле «{field}»'**
  String validationTooShort(String field);

  /// No description provided for @validationTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинное значение в поле «{field}»'**
  String validationTooLong(String field);

  /// No description provided for @validationNotNumber.
  ///
  /// In ru, this message translates to:
  /// **'В поле «{field}» нужно число'**
  String validationNotNumber(String field);

  /// No description provided for @validationOutOfRange.
  ///
  /// In ru, this message translates to:
  /// **'Значение в поле «{field}» вне допустимых границ'**
  String validationOutOfRange(String field);

  /// No description provided for @validationBadFormat.
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат в поле «{field}»'**
  String validationBadFormat(String field);

  /// No description provided for @apiFieldFullName.
  ///
  /// In ru, this message translates to:
  /// **'Имя или название'**
  String get apiFieldFullName;

  /// No description provided for @apiFieldPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get apiFieldPhone;

  /// No description provided for @apiFieldAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get apiFieldAddress;

  /// No description provided for @apiFieldComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get apiFieldComment;

  /// No description provided for @apiFieldPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get apiFieldPassword;

  /// No description provided for @apiFieldOldPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get apiFieldOldPassword;

  /// No description provided for @apiFieldNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get apiFieldNewPassword;

  /// No description provided for @apiFieldDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get apiFieldDate;

  /// No description provided for @apiFieldDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get apiFieldDriver;

  /// No description provided for @apiFieldCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Заказчики'**
  String get apiFieldCustomers;

  /// No description provided for @apiFieldCapsules.
  ///
  /// In ru, this message translates to:
  /// **'Количество капсул'**
  String get apiFieldCapsules;

  /// No description provided for @apiFieldAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма оплаты'**
  String get apiFieldAmount;

  /// No description provided for @apiFieldPaymentMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get apiFieldPaymentMethod;

  /// No description provided for @apiFieldBalance.
  ///
  /// In ru, this message translates to:
  /// **'Остаток капсул'**
  String get apiFieldBalance;

  /// No description provided for @apiFieldPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена капсулы'**
  String get apiFieldPrice;

  /// No description provided for @apiFieldDeposit.
  ///
  /// In ru, this message translates to:
  /// **'Залог за тару'**
  String get apiFieldDeposit;

  /// No description provided for @phoneCallUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Звонок недоступен — номер скопирован'**
  String get phoneCallUnavailable;

  /// No description provided for @phoneCopied.
  ///
  /// In ru, this message translates to:
  /// **'Номер скопирован'**
  String get phoneCopied;

  /// No description provided for @phoneCopy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать номер'**
  String get phoneCopy;

  /// No description provided for @fieldCopy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get fieldCopy;

  /// No description provided for @fieldCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get fieldCopied;

  /// No description provided for @photoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото оплаты'**
  String get photoTitle;

  /// No description provided for @photoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепите чек или фото доставки'**
  String get photoSubtitle;

  /// No description provided for @photoError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить фото. Проверьте доступ.'**
  String get photoError;

  /// No description provided for @photoRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фото'**
  String get photoRemove;

  /// No description provided for @photoCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get photoCamera;

  /// No description provided for @photoGallery.
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get photoGallery;

  /// No description provided for @photoSize.
  ///
  /// In ru, this message translates to:
  /// **'{size} КБ'**
  String photoSize(int size);

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeSystem;

  /// No description provided for @themeSystemShort.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get themeSystemShort;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @themeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тема · {mode}'**
  String themeTitle(String mode);

  /// No description provided for @languageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Язык · {name}'**
  String languageTitle(String name);

  /// No description provided for @languageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageUzbek.
  ///
  /// In ru, this message translates to:
  /// **'O‘zbekcha'**
  String get languageUzbek;

  /// No description provided for @languageSection.
  ///
  /// In ru, this message translates to:
  /// **'ЯЗЫК'**
  String get languageSection;

  /// No description provided for @roleAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get roleAdmin;

  /// No description provided for @roleDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get roleDriver;

  /// No description provided for @deliveryPending.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get deliveryPending;

  /// No description provided for @deliveryOnWay.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get deliveryOnWay;

  /// No description provided for @deliveryDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлено'**
  String get deliveryDelivered;

  /// No description provided for @deliveryFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не доставлено'**
  String get deliveryFailed;

  /// No description provided for @deliveryPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get deliveryPaid;

  /// No description provided for @routeCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get routeCreated;

  /// No description provided for @routeInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Выполняется'**
  String get routeInProgress;

  /// No description provided for @routeCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершён'**
  String get routeCompleted;

  /// No description provided for @routeCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get routeCancelled;

  /// No description provided for @filterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filterAll;

  /// No description provided for @filterInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get filterInProgress;

  /// No description provided for @filterCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершены'**
  String get filterCompleted;

  /// No description provided for @filterNew.
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get filterNew;

  /// No description provided for @paymentCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get paymentCard;

  /// No description provided for @paymentTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Перечисление'**
  String get paymentTransfer;

  /// No description provided for @paymentDebt.
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get paymentDebt;

  /// No description provided for @periodToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get periodToday;

  /// No description provided for @periodWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get periodMonth;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в систему'**
  String get loginTitle;

  /// No description provided for @loginPhone.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get loginPhone;

  /// No description provided for @loginPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get loginPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginSubmit;

  /// No description provided for @loginSubmitting.
  ///
  /// In ru, this message translates to:
  /// **'Вход…'**
  String get loginSubmitting;

  /// No description provided for @loginErrorCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный телефон или пароль.'**
  String get loginErrorCredentials;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка входа. Попробуйте ещё раз.'**
  String get loginErrorGeneric;

  /// No description provided for @loginErrorFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось войти. Попробуйте ещё раз.'**
  String get loginErrorFailed;

  /// No description provided for @sessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get sessionExpired;

  /// No description provided for @navRoute.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут'**
  String get navRoute;

  /// No description provided for @navRoutes.
  ///
  /// In ru, this message translates to:
  /// **'Маршруты'**
  String get navRoutes;

  /// No description provided for @navDrivers.
  ///
  /// In ru, this message translates to:
  /// **'Водители'**
  String get navDrivers;

  /// No description provided for @navCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Заказчики'**
  String get navCustomers;

  /// No description provided for @navReports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get navReports;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @routesHeaderToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня · {date}'**
  String routesHeaderToday(String date);

  /// No description provided for @routesHeaderOn.
  ///
  /// In ru, this message translates to:
  /// **'На {date}'**
  String routesHeaderOn(String date);

  /// No description provided for @routesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Маршруты'**
  String get routesTitle;

  /// No description provided for @routesRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить маршруты'**
  String get routesRefresh;

  /// No description provided for @routesCreated.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут создан'**
  String get routesCreated;

  /// No description provided for @routesLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить маршруты'**
  String get routesLoadFailed;

  /// No description provided for @routesEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутов пока нет'**
  String get routesEmptyTitle;

  /// No description provided for @routesEmptyDayHint.
  ///
  /// In ru, this message translates to:
  /// **'На {date} маршрутов нет'**
  String routesEmptyDayHint(String date);

  /// No description provided for @dateTabsPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату'**
  String get dateTabsPick;

  /// No description provided for @filterEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'В этом фильтре пусто'**
  String get filterEmptyTitle;

  /// No description provided for @filterEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте другой фильтр'**
  String get filterEmptyHint;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @routeCardTitle.
  ///
  /// In ru, this message translates to:
  /// **'Карточка маршрута'**
  String get routeCardTitle;

  /// No description provided for @routeLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить маршрут'**
  String get routeLoadFailed;

  /// No description provided for @routeNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут не найден'**
  String get routeNotFound;

  /// No description provided for @routeCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить маршрут?'**
  String get routeCancelTitle;

  /// No description provided for @routeCancelMessage.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут будет помечен как отменённый.'**
  String get routeCancelMessage;

  /// No description provided for @routeCancelAction.
  ///
  /// In ru, this message translates to:
  /// **'Отменить маршрут'**
  String get routeCancelAction;

  /// No description provided for @routeCancelFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отменить маршрут.'**
  String get routeCancelFailed;

  /// No description provided for @routeCancelled2.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут отменён'**
  String get routeCancelled2;

  /// No description provided for @routeDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get routeDriver;

  /// No description provided for @routeStatDone.
  ///
  /// In ru, this message translates to:
  /// **'ВЫПОЛНЕНО'**
  String get routeStatDone;

  /// No description provided for @routeStatCollected.
  ///
  /// In ru, this message translates to:
  /// **'СОБРАНО'**
  String get routeStatCollected;

  /// No description provided for @routeStops.
  ///
  /// In ru, this message translates to:
  /// **'ТОЧКИ МАРШРУТА'**
  String get routeStops;

  /// No description provided for @routeStopsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} точка} few{{count} точки} other{{count} точек}}'**
  String routeStopsCount(int count);

  /// No description provided for @routeDoneShort.
  ///
  /// In ru, this message translates to:
  /// **'выполнено'**
  String get routeDoneShort;

  /// No description provided for @routeProgressTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено доставок'**
  String get routeProgressTitle;

  /// No description provided for @routeCollectedToday.
  ///
  /// In ru, this message translates to:
  /// **'Собрано сегодня'**
  String get routeCollectedToday;

  /// No description provided for @routeCollected.
  ///
  /// In ru, this message translates to:
  /// **'Собрано'**
  String get routeCollected;

  /// No description provided for @stopCapsules.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} капсула} few{{count} капсулы} other{{count} капсул}}'**
  String stopCapsules(int count);

  /// No description provided for @routeFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый маршрут'**
  String get routeFormTitle;

  /// No description provided for @routeFormLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить водителей и заказчиков'**
  String get routeFormLoadFailed;

  /// No description provided for @routeFormCreateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать маршрут.'**
  String get routeFormCreateFailed;

  /// No description provided for @routeFormDate.
  ///
  /// In ru, this message translates to:
  /// **'ДАТА'**
  String get routeFormDate;

  /// No description provided for @routeFormDriver.
  ///
  /// In ru, this message translates to:
  /// **'ВОДИТЕЛЬ'**
  String get routeFormDriver;

  /// No description provided for @routeFormNoDrivers.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте водителей'**
  String get routeFormNoDrivers;

  /// No description provided for @routeFormCustomers.
  ///
  /// In ru, this message translates to:
  /// **'ЗАКАЗЧИКИ'**
  String get routeFormCustomers;

  /// No description provided for @routeFormNoCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте заказчиков'**
  String get routeFormNoCustomers;

  /// No description provided for @routeEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить маршрут'**
  String get routeEditTitle;

  /// No description provided for @routeFormSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить изменения.'**
  String get routeFormSaveFailed;

  /// No description provided for @routeEditInProgressHint.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут уже в работе: дату и водителя менять поздно, можно только добавить заказчиков.'**
  String get routeEditInProgressHint;

  /// No description provided for @routeFormSelected.
  ///
  /// In ru, this message translates to:
  /// **'выбрано: {count}'**
  String routeFormSelected(int count);

  /// No description provided for @customerSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск заказчика'**
  String get customerSearch;

  /// No description provided for @stopTitle.
  ///
  /// In ru, this message translates to:
  /// **'Точка маршрута'**
  String get stopTitle;

  /// No description provided for @stopCapsulesDelivered.
  ///
  /// In ru, this message translates to:
  /// **'капсул доставлено'**
  String get stopCapsulesDelivered;

  /// No description provided for @stopPaid.
  ///
  /// In ru, this message translates to:
  /// **'оплачено'**
  String get stopPaid;

  /// No description provided for @stopCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершено'**
  String get stopCompleted;

  /// No description provided for @stopPhotoLabel.
  ///
  /// In ru, this message translates to:
  /// **'ФОТО ОПЛАТЫ'**
  String get stopPhotoLabel;

  /// No description provided for @stopPhotoFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото'**
  String get stopPhotoFailed;

  /// No description provided for @mapSectionLabel.
  ///
  /// In ru, this message translates to:
  /// **'МАРШРУТ НА КАРТЕ'**
  String get mapSectionLabel;

  /// No description provided for @mapFromCurrentPlace.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут построится от вашего текущего места.'**
  String get mapFromCurrentPlace;

  /// No description provided for @mapBuildRoute.
  ///
  /// In ru, this message translates to:
  /// **'Построить маршрут'**
  String get mapBuildRoute;

  /// No description provided for @mapNeedOnePoint.
  ///
  /// In ru, this message translates to:
  /// **'Для маршрута нужна хотя бы одна точка.'**
  String get mapNeedOnePoint;

  /// No description provided for @mapPointWithoutAddress.
  ///
  /// In ru, this message translates to:
  /// **'У точки {number} не заполнен адрес.'**
  String mapPointWithoutAddress(int number);

  /// No description provided for @mapOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть Яндекс.Карты'**
  String get mapOpenFailed;

  /// No description provided for @driversTitle.
  ///
  /// In ru, this message translates to:
  /// **'Водители'**
  String get driversTitle;

  /// No description provided for @driversHeader.
  ///
  /// In ru, this message translates to:
  /// **'Команда · {count}'**
  String driversHeader(int count);

  /// No description provided for @driversHeaderFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено · {count}'**
  String driversHeaderFound(int count);

  /// No description provided for @driversSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск водителя'**
  String get driversSearch;

  /// No description provided for @driversRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить список'**
  String get driversRefresh;

  /// No description provided for @driversLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить водителей'**
  String get driversLoadFailed;

  /// No description provided for @driversEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Водителей пока нет'**
  String get driversEmptyTitle;

  /// No description provided for @driversEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого — на него можно будет назначить маршрут'**
  String get driversEmptyHint;

  /// No description provided for @driversEmptyAction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить водителя'**
  String get driversEmptyAction;

  /// No description provided for @driverAdded.
  ///
  /// In ru, this message translates to:
  /// **'Водитель добавлен'**
  String get driverAdded;

  /// No description provided for @driverDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Водитель удалён'**
  String get driverDeleted;

  /// No description provided for @changesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Изменения сохранены'**
  String get changesSaved;

  /// No description provided for @driverDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить водителя?'**
  String get driverDeleteTitle;

  /// No description provided for @driverDeleteMessage.
  ///
  /// In ru, this message translates to:
  /// **'{name} будет удалён из списка.'**
  String driverDeleteMessage(String name);

  /// No description provided for @driverDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить водителя.'**
  String get driverDeleteFailed;

  /// No description provided for @driverTitle.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get driverTitle;

  /// No description provided for @driverOnRoute.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня на маршруте'**
  String get driverOnRoute;

  /// No description provided for @driverNoTrips.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня без поездок'**
  String get driverNoTrips;

  /// No description provided for @driverTripsTotal.
  ///
  /// In ru, this message translates to:
  /// **'всего поездок'**
  String get driverTripsTotal;

  /// No description provided for @driverTripsToday.
  ///
  /// In ru, this message translates to:
  /// **'поездок сегодня'**
  String get driverTripsToday;

  /// No description provided for @driverCreatedAt.
  ///
  /// In ru, this message translates to:
  /// **'Дата создания'**
  String get driverCreatedAt;

  /// No description provided for @driverTripsAndToday.
  ///
  /// In ru, this message translates to:
  /// **'сегодня'**
  String get driverTripsAndToday;

  /// No description provided for @driverFormEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование водителя'**
  String get driverFormEditTitle;

  /// No description provided for @driverFormNewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый водитель'**
  String get driverFormNewTitle;

  /// No description provided for @driverFormName.
  ///
  /// In ru, this message translates to:
  /// **'Имя водителя'**
  String get driverFormName;

  /// No description provided for @driverFormNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Азиз Каримов'**
  String get driverFormNameHint;

  /// No description provided for @driverFormNameEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя водителя'**
  String get driverFormNameEmpty;

  /// No description provided for @driverFormPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль для входа'**
  String get driverFormPassword;

  /// No description provided for @driverFormPasswordHelper.
  ///
  /// In ru, this message translates to:
  /// **'Передайте пароль водителю — восстановить его потом нельзя'**
  String get driverFormPasswordHelper;

  /// No description provided for @driverFormSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить водителя.'**
  String get driverFormSaveFailed;

  /// No description provided for @minSixChars.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get minSixChars;

  /// No description provided for @customersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказчики'**
  String get customersTitle;

  /// No description provided for @customersHeader.
  ///
  /// In ru, this message translates to:
  /// **'База · {count}'**
  String customersHeader(int count);

  /// No description provided for @customersHeaderFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено · {count}'**
  String customersHeaderFound(int count);

  /// No description provided for @customersLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить заказчиков'**
  String get customersLoadFailed;

  /// No description provided for @customersEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказчиков пока нет'**
  String get customersEmptyTitle;

  /// No description provided for @customersEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого — он появится в списке и в маршрутах'**
  String get customersEmptyHint;

  /// No description provided for @customersEmptyAction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить заказчика'**
  String get customersEmptyAction;

  /// No description provided for @customerAdded.
  ///
  /// In ru, this message translates to:
  /// **'Заказчик добавлен'**
  String get customerAdded;

  /// No description provided for @customerDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Заказчик удалён'**
  String get customerDeleted;

  /// No description provided for @customerDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить заказчика?'**
  String get customerDeleteTitle;

  /// No description provided for @customerDeleteMessage.
  ///
  /// In ru, this message translates to:
  /// **'{name} будет удалён из базы.'**
  String customerDeleteMessage(String name);

  /// No description provided for @customerDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить заказчика.'**
  String get customerDeleteFailed;

  /// No description provided for @customerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказчик'**
  String get customerTitle;

  /// No description provided for @customerHasCooler.
  ///
  /// In ru, this message translates to:
  /// **'Есть кулер'**
  String get customerHasCooler;

  /// No description provided for @customerFormHasCooler.
  ///
  /// In ru, this message translates to:
  /// **'У заказчика есть кулер'**
  String get customerFormHasCooler;

  /// No description provided for @customerCapsulesBalance.
  ///
  /// In ru, this message translates to:
  /// **'капсул на руках'**
  String get customerCapsulesBalance;

  /// No description provided for @customerLastOrder.
  ///
  /// In ru, this message translates to:
  /// **'последний заказ'**
  String get customerLastOrder;

  /// No description provided for @customerLastOrderShort.
  ///
  /// In ru, this message translates to:
  /// **'посл. заказ {date}'**
  String customerLastOrderShort(String date);

  /// No description provided for @financePrepayment.
  ///
  /// In ru, this message translates to:
  /// **'Предоплата'**
  String get financePrepayment;

  /// No description provided for @financeDebt.
  ///
  /// In ru, this message translates to:
  /// **'Долг'**
  String get financeDebt;

  /// No description provided for @customerFormEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование заказчика'**
  String get customerFormEditTitle;

  /// No description provided for @customerFormNewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказчик'**
  String get customerFormNewTitle;

  /// No description provided for @customerFormName.
  ///
  /// In ru, this message translates to:
  /// **'Название / имя'**
  String get customerFormName;

  /// No description provided for @customerFormNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Кафе «Nasiba»'**
  String get customerFormNameHint;

  /// No description provided for @customerFormNameEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите название или имя'**
  String get customerFormNameEmpty;

  /// No description provided for @customerFormAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get customerFormAddress;

  /// No description provided for @customerFormAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Район, улица, дом'**
  String get customerFormAddressHint;

  /// No description provided for @customerFormAddressEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите адрес доставки'**
  String get customerFormAddressEmpty;

  /// No description provided for @customerFormComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get customerFormComment;

  /// No description provided for @customerFormCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, район или ориентир'**
  String get customerFormCommentHint;

  /// No description provided for @customerFormSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить заказчика.'**
  String get customerFormSaveFailed;

  /// No description provided for @myRoutesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои маршруты'**
  String get myRoutesTitle;

  /// No description provided for @myRoutesStatRoutes.
  ///
  /// In ru, this message translates to:
  /// **'всего маршрутов'**
  String get myRoutesStatRoutes;

  /// No description provided for @myRoutesStatDeliveredToday.
  ///
  /// In ru, this message translates to:
  /// **'доставлено сегодня'**
  String get myRoutesStatDeliveredToday;

  /// No description provided for @myRoutesStatOrders.
  ///
  /// In ru, this message translates to:
  /// **'всего заказов'**
  String get myRoutesStatOrders;

  /// No description provided for @myRoutesEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Когда диспетчер назначит маршрут, он появится здесь'**
  String get myRoutesEmptyHint;

  /// No description provided for @myRouteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут'**
  String get myRouteTitle;

  /// No description provided for @myRouteStatusFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось изменить статус.'**
  String get myRouteStatusFailed;

  /// No description provided for @myRouteStatusChanged.
  ///
  /// In ru, this message translates to:
  /// **'Статус: {status}'**
  String myRouteStatusChanged(String status);

  /// No description provided for @myRouteChangeStatus.
  ///
  /// In ru, this message translates to:
  /// **'Изменить статус'**
  String get myRouteChangeStatus;

  /// No description provided for @completionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Завершение доставки'**
  String get completionTitle;

  /// No description provided for @completionCoordinates.
  ///
  /// In ru, this message translates to:
  /// **'КООРДИНАТЫ ТОЧКИ'**
  String get completionCoordinates;

  /// No description provided for @completionCapsules.
  ///
  /// In ru, this message translates to:
  /// **'КОЛИЧЕСТВО КАПСУЛ'**
  String get completionCapsules;

  /// No description provided for @completionCapsulesCaption.
  ///
  /// In ru, this message translates to:
  /// **'капсул {liters} л'**
  String completionCapsulesCaption(int liters);

  /// No description provided for @completionBalance.
  ///
  /// In ru, this message translates to:
  /// **'КАПСУЛ У КЛИЕНТА'**
  String get completionBalance;

  /// No description provided for @completionBalanceCaption.
  ///
  /// In ru, this message translates to:
  /// **'станет остатком у клиента вместо прежнего'**
  String get completionBalanceCaption;

  /// No description provided for @completionBalanceUnchecked.
  ///
  /// In ru, this message translates to:
  /// **'Подставлено число привезённых. Сверьте со складом клиента — это значение заменит прежний остаток.'**
  String get completionBalanceUnchecked;

  /// No description provided for @completionMethod.
  ///
  /// In ru, this message translates to:
  /// **'СПОСОБ ОПЛАТЫ'**
  String get completionMethod;

  /// No description provided for @completionAmount.
  ///
  /// In ru, this message translates to:
  /// **'СУММА ОПЛАТЫ'**
  String get completionAmount;

  /// No description provided for @completionAmountRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите сумму. Ноль — если оплаты не было'**
  String get completionAmountRequired;

  /// No description provided for @completionTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого к оплате'**
  String get completionTotal;

  /// No description provided for @completionSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get completionSubmit;

  /// No description provided for @completionForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Завершать доставку может только водитель этого маршрута.'**
  String get completionForbidden;

  /// No description provided for @completionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось завершить доставку.'**
  String get completionFailed;

  /// No description provided for @completionByPrice.
  ///
  /// In ru, this message translates to:
  /// **'По прайсу: {formula}'**
  String completionByPrice(String formula);

  /// No description provided for @completionRestoreAmount.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть расчёт'**
  String get completionRestoreAmount;

  /// No description provided for @locationSearching.
  ///
  /// In ru, this message translates to:
  /// **'Определяем координаты…'**
  String get locationSearching;

  /// No description provided for @locationFixed.
  ///
  /// In ru, this message translates to:
  /// **'Точка зафиксирована'**
  String get locationFixed;

  /// No description provided for @locationNotFixed.
  ///
  /// In ru, this message translates to:
  /// **'Точка не зафиксирована'**
  String get locationNotFixed;

  /// No description provided for @locationCanContinue.
  ///
  /// In ru, this message translates to:
  /// **'Доставку можно завершить и так.'**
  String get locationCanContinue;

  /// No description provided for @locationRetry.
  ///
  /// In ru, this message translates to:
  /// **'Определить заново'**
  String get locationRetry;

  /// No description provided for @locationDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Геолокация выключена в настройках телефона.'**
  String get locationDisabled;

  /// No description provided for @locationDeniedForever.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к геолокации запрещён. Разрешите его в настройках телефона.'**
  String get locationDeniedForever;

  /// No description provided for @locationDenied.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к геолокации.'**
  String get locationDenied;

  /// No description provided for @locationUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить координаты.'**
  String get locationUnknown;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @profileAccountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get profileAccountLabel;

  /// No description provided for @profileAccountSection.
  ///
  /// In ru, this message translates to:
  /// **'АККАУНТ'**
  String get profileAccountSection;

  /// No description provided for @settingsAppearance.
  ///
  /// In ru, this message translates to:
  /// **'ОФОРМЛЕНИЕ'**
  String get settingsAppearance;

  /// No description provided for @settingsAccount.
  ///
  /// In ru, this message translates to:
  /// **'АККАУНТ'**
  String get settingsAccount;

  /// No description provided for @settingsSessionActive.
  ///
  /// In ru, this message translates to:
  /// **'Сессия активна'**
  String get settingsSessionActive;

  /// No description provided for @settingsLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get settingsLogoutTitle;

  /// No description provided for @settingsLogoutMessage.
  ///
  /// In ru, this message translates to:
  /// **'Придётся войти заново по номеру телефона и паролю.'**
  String get settingsLogoutMessage;

  /// No description provided for @passwordChangeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена пароля'**
  String get passwordChangeTitle;

  /// No description provided for @passwordChangeTile.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get passwordChangeTile;

  /// No description provided for @passwordChangeTileHint.
  ///
  /// In ru, this message translates to:
  /// **'Понадобится текущий пароль'**
  String get passwordChangeTileHint;

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get passwordChanged;

  /// No description provided for @passwordCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get passwordCurrent;

  /// No description provided for @passwordCurrentEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите текущий пароль'**
  String get passwordCurrentEmpty;

  /// No description provided for @passwordNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get passwordNew;

  /// No description provided for @passwordRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторите новый пароль'**
  String get passwordRepeat;

  /// No description provided for @passwordSameAsCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль совпадает с текущим'**
  String get passwordSameAsCurrent;

  /// No description provided for @passwordMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordMismatch;

  /// No description provided for @passwordChangeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сменить пароль.'**
  String get passwordChangeFailed;

  /// No description provided for @passwordWrongCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Неверный текущий пароль.'**
  String get passwordWrongCurrent;

  /// No description provided for @passwordKeepMessage.
  ///
  /// In ru, this message translates to:
  /// **'Пароль останется прежним.'**
  String get passwordKeepMessage;

  /// No description provided for @passwordSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Сменить'**
  String get passwordSubmit;

  /// No description provided for @pricesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Цены'**
  String get pricesTitle;

  /// No description provided for @pricesTileHint.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость капсулы и залог за тару'**
  String get pricesTileHint;

  /// No description provided for @pricesSection.
  ///
  /// In ru, this message translates to:
  /// **'ПРАЙС'**
  String get pricesSection;

  /// No description provided for @pricesUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Цены обновлены'**
  String get pricesUpdated;

  /// No description provided for @pricesLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить цены'**
  String get pricesLoadFailed;

  /// No description provided for @pricesSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить цены.'**
  String get pricesSaveFailed;

  /// No description provided for @pricesCurrent.
  ///
  /// In ru, this message translates to:
  /// **'ДЕЙСТВУЮЩИЙ ПРАЙС'**
  String get pricesCurrent;

  /// No description provided for @pricesNew.
  ///
  /// In ru, this message translates to:
  /// **'НОВЫЕ ЗНАЧЕНИЯ'**
  String get pricesNew;

  /// No description provided for @pricesHistory.
  ///
  /// In ru, this message translates to:
  /// **'ИСТОРИЯ ИЗМЕНЕНИЙ'**
  String get pricesHistory;

  /// No description provided for @pricesCapsule.
  ///
  /// In ru, this message translates to:
  /// **'Цена капсулы'**
  String get pricesCapsule;

  /// No description provided for @pricesCapsuleHelper.
  ///
  /// In ru, this message translates to:
  /// **'Сум за одну капсулу {liters} л'**
  String pricesCapsuleHelper(int liters);

  /// No description provided for @pricesCapsuleRow.
  ///
  /// In ru, this message translates to:
  /// **'Капсула {liters} л'**
  String pricesCapsuleRow(int liters);

  /// No description provided for @pricesDeposit.
  ///
  /// In ru, this message translates to:
  /// **'Залог за тару'**
  String get pricesDeposit;

  /// No description provided for @pricesDepositHelper.
  ///
  /// In ru, this message translates to:
  /// **'Сум; 0 — залога нет'**
  String get pricesDepositHelper;

  /// No description provided for @pricesDepositRow.
  ///
  /// In ru, this message translates to:
  /// **'залог {amount}'**
  String pricesDepositRow(String amount);

  /// No description provided for @pricesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Укажите цену'**
  String get pricesEmpty;

  /// No description provided for @pricesZero.
  ///
  /// In ru, this message translates to:
  /// **'Цена капсулы должна быть больше нуля'**
  String get pricesZero;

  /// No description provided for @pricesConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Назначить новую цену?'**
  String get pricesConfirmTitle;

  /// No description provided for @pricesConfirmMessage.
  ///
  /// In ru, this message translates to:
  /// **'Капсула — {capsule}, залог — {deposit}.'**
  String pricesConfirmMessage(String capsule, String deposit);

  /// No description provided for @pricesConfirmAction.
  ///
  /// In ru, this message translates to:
  /// **'Назначить'**
  String get pricesConfirmAction;

  /// No description provided for @pricesEffectiveFrom.
  ///
  /// In ru, this message translates to:
  /// **'Действует с {date}'**
  String pricesEffectiveFrom(String date);

  /// No description provided for @pricesHistoryFailed.
  ///
  /// In ru, this message translates to:
  /// **'Историю загрузить не удалось.'**
  String get pricesHistoryFailed;

  /// No description provided for @pricesHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Прайс ещё не меняли — это первая цена.'**
  String get pricesHistoryEmpty;

  /// No description provided for @reportsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get reportsLabel;

  /// No description provided for @reportsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get reportsTitle;

  /// No description provided for @reportsExport.
  ///
  /// In ru, this message translates to:
  /// **'Выгрузить в Excel'**
  String get reportsExport;

  /// No description provided for @reportsExportSubject.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт Millwater'**
  String get reportsExportSubject;

  /// No description provided for @reportsExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выгрузить отчёт.'**
  String get reportsExportFailed;

  /// No description provided for @reportsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить отчёты'**
  String get reportsLoadFailed;

  /// No description provided for @reportsRevenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get reportsRevenue;

  /// No description provided for @reportsDeliveries.
  ///
  /// In ru, this message translates to:
  /// **'Доставки'**
  String get reportsDeliveries;

  /// No description provided for @reportsDebts.
  ///
  /// In ru, this message translates to:
  /// **'Долги'**
  String get reportsDebts;

  /// No description provided for @reportsCapsules.
  ///
  /// In ru, this message translates to:
  /// **'Капсулы у клиентов'**
  String get reportsCapsules;

  /// No description provided for @reportsCapsulesCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} шт.'**
  String reportsCapsulesCount(int count);

  /// No description provided for @reportsDebtors.
  ///
  /// In ru, this message translates to:
  /// **'Долги заказчиков'**
  String get reportsDebtors;

  /// No description provided for @capsulesCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} капсула} few{{count} капсулы} other{{count} капсул}}'**
  String capsulesCount(int count);

  /// No description provided for @tripsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} поездка} few{{count} поездки} other{{count} поездок}}'**
  String tripsCount(int count);

  /// No description provided for @clientsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} клиент} few{{count} клиента} other{{count} клиентов}}'**
  String clientsCount(int count);

  /// No description provided for @desktopBrandSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Доставка воды'**
  String get desktopBrandSubtitle;

  /// No description provided for @desktopNavGroup.
  ///
  /// In ru, this message translates to:
  /// **'РАБОТА'**
  String get desktopNavGroup;

  /// No description provided for @desktopOnLineTitle.
  ///
  /// In ru, this message translates to:
  /// **'СЕГОДНЯ НА ЛИНИИ'**
  String get desktopOnLineTitle;

  /// No description provided for @desktopOnLineOf.
  ///
  /// In ru, this message translates to:
  /// **'из {count, plural, one{{count} водителя} other{{count} водителей}}'**
  String desktopOnLineOf(int count);

  /// No description provided for @desktopSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get desktopSearchHint;

  /// No description provided for @desktopNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get desktopNotifications;

  /// No description provided for @desktopAddDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get desktopAddDriver;

  /// No description provided for @desktopAddCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Заказчик'**
  String get desktopAddCustomer;

  /// No description provided for @desktopRoutesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{date} · {count} в работе'**
  String desktopRoutesSubtitle(String date, int count);

  /// No description provided for @desktopDriverStubTitle.
  ///
  /// In ru, this message translates to:
  /// **'Это рабочее место администратора'**
  String get desktopDriverStubTitle;

  /// No description provided for @desktopDriverStubHint.
  ///
  /// In ru, this message translates to:
  /// **'Маршруты и доставки открываются в мобильном приложении — зайдите с телефона.'**
  String get desktopDriverStubHint;

  /// No description provided for @driversCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} водитель} few{{count} водителя} other{{count} водителей}}'**
  String driversCount(int count);

  /// No description provided for @customersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} заказчик} few{{count} заказчика} other{{count} заказчиков}}'**
  String customersCount(int count);

  /// No description provided for @filterDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлены'**
  String get filterDelivered;

  /// No description provided for @desktopColCustomer.
  ///
  /// In ru, this message translates to:
  /// **'ЗАКАЗЧИК'**
  String get desktopColCustomer;

  /// No description provided for @desktopColDriver.
  ///
  /// In ru, this message translates to:
  /// **'ВОДИТЕЛЬ'**
  String get desktopColDriver;

  /// No description provided for @desktopColCapsules.
  ///
  /// In ru, this message translates to:
  /// **'КАПСУЛЫ'**
  String get desktopColCapsules;

  /// No description provided for @desktopColSum.
  ///
  /// In ru, this message translates to:
  /// **'СУММА'**
  String get desktopColSum;

  /// No description provided for @desktopColPayment.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАТА'**
  String get desktopColPayment;

  /// No description provided for @desktopColStatus.
  ///
  /// In ru, this message translates to:
  /// **'СТАТУС'**
  String get desktopColStatus;

  /// No description provided for @desktopKpiCollected.
  ///
  /// In ru, this message translates to:
  /// **'Собрано за день'**
  String get desktopKpiCollected;

  /// No description provided for @desktopKpiDebt.
  ///
  /// In ru, this message translates to:
  /// **'В долг за день'**
  String get desktopKpiDebt;

  /// No description provided for @desktopKpiCapsules.
  ///
  /// In ru, this message translates to:
  /// **'Выдано капсул'**
  String get desktopKpiCapsules;

  /// No description provided for @desktopKpiPlannedStops.
  ///
  /// In ru, this message translates to:
  /// **'Точек в плане'**
  String get desktopKpiPlannedStops;

  /// No description provided for @desktopKpiPlannedDrivers.
  ///
  /// In ru, this message translates to:
  /// **'Водителей на день'**
  String get desktopKpiPlannedDrivers;

  /// No description provided for @desktopKpiPlannedCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Заказчиков в плане'**
  String get desktopKpiPlannedCustomers;

  /// No description provided for @desktopSummaryDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполненные доставки'**
  String get desktopSummaryDone;

  /// No description provided for @desktopSummaryPlanned.
  ///
  /// In ru, this message translates to:
  /// **'Запланировано доставок'**
  String get desktopSummaryPlanned;

  /// No description provided for @desktopDebtShort.
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get desktopDebtShort;

  /// No description provided for @desktopDateToday.
  ///
  /// In ru, this message translates to:
  /// **'сегодня'**
  String get desktopDateToday;

  /// No description provided for @desktopDatePlanned.
  ///
  /// In ru, this message translates to:
  /// **'{count} в плане'**
  String desktopDatePlanned(int count);

  /// No description provided for @desktopDayEmpty.
  ///
  /// In ru, this message translates to:
  /// **'На этот день доставок нет'**
  String get desktopDayEmpty;

  /// No description provided for @desktopDayEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте маршрут или выберите другой день'**
  String get desktopDayEmptyHint;

  /// No description provided for @desktopDebtEstimated.
  ///
  /// In ru, this message translates to:
  /// **'оценка по цене капсулы'**
  String get desktopDebtEstimated;

  /// No description provided for @routesCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} маршрут} few{{count} маршрута} other{{count} маршрутов}}'**
  String routesCountPlural(int count);

  /// No description provided for @commonClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get commonClose;

  /// No description provided for @desktopDeliveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get desktopDeliveryTitle;

  /// No description provided for @desktopFinishRoute.
  ///
  /// In ru, this message translates to:
  /// **'Закончить маршрут'**
  String get desktopFinishRoute;

  /// No description provided for @desktopMarkDebtPaid.
  ///
  /// In ru, this message translates to:
  /// **'Отметить оплату долга'**
  String get desktopMarkDebtPaid;

  /// No description provided for @desktopFinishedAndPaid.
  ///
  /// In ru, this message translates to:
  /// **'Завершено и оплачено'**
  String get desktopFinishedAndPaid;

  /// No description provided for @desktopDriverOnlyHint.
  ///
  /// In ru, this message translates to:
  /// **'Доставку закрывает водитель в своём приложении — отсюда это сделать нельзя.'**
  String get desktopDriverOnlyHint;

  /// No description provided for @desktopDebtPaidHint.
  ///
  /// In ru, this message translates to:
  /// **'Пока недоступно: отметить оплату долга можно будет позже.'**
  String get desktopDebtPaidHint;

  /// No description provided for @desktopOnLine.
  ///
  /// In ru, this message translates to:
  /// **'На линии'**
  String get desktopOnLine;

  /// No description provided for @desktopFree.
  ///
  /// In ru, this message translates to:
  /// **'Свободен'**
  String get desktopFree;

  /// No description provided for @desktopColAddress.
  ///
  /// In ru, this message translates to:
  /// **'АДРЕС'**
  String get desktopColAddress;

  /// No description provided for @desktopColBalance.
  ///
  /// In ru, this message translates to:
  /// **'БАЛАНС'**
  String get desktopColBalance;

  /// No description provided for @desktopColLastOrder.
  ///
  /// In ru, this message translates to:
  /// **'ПОСЛ. ЗАКАЗ'**
  String get desktopColLastOrder;

  /// No description provided for @desktopColCapsulesShort.
  ///
  /// In ru, this message translates to:
  /// **'КАПСУЛ'**
  String get desktopColCapsulesShort;

  /// No description provided for @desktopBalanceDebt.
  ///
  /// In ru, this message translates to:
  /// **'Долг {amount}'**
  String desktopBalanceDebt(String amount);

  /// No description provided for @desktopBalancePrepaid.
  ///
  /// In ru, this message translates to:
  /// **'Аванс {amount}'**
  String desktopBalancePrepaid(String amount);

  /// No description provided for @desktopSuccessDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get desktopSuccessDone;

  /// No description provided for @desktopWithCooler.
  ///
  /// In ru, this message translates to:
  /// **'С кулером'**
  String get desktopWithCooler;

  /// No description provided for @desktopWithoutCooler.
  ///
  /// In ru, this message translates to:
  /// **'Без кулера'**
  String get desktopWithoutCooler;

  /// No description provided for @desktopFieldCapsules.
  ///
  /// In ru, this message translates to:
  /// **'Капсулы'**
  String get desktopFieldCapsules;

  /// No description provided for @desktopFieldSum.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get desktopFieldSum;

  /// No description provided for @desktopFieldStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get desktopFieldStatus;

  /// No description provided for @desktopFieldTime.
  ///
  /// In ru, this message translates to:
  /// **'Закрыта'**
  String get desktopFieldTime;

  /// No description provided for @desktopFieldAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get desktopFieldAddress;

  /// No description provided for @desktopChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выручка по дням'**
  String get desktopChartTitle;

  /// No description provided for @desktopPrepayments.
  ///
  /// In ru, this message translates to:
  /// **'Предоплаты'**
  String get desktopPrepayments;

  /// No description provided for @desktopNoDebtors.
  ///
  /// In ru, this message translates to:
  /// **'Должников нет'**
  String get desktopNoDebtors;

  /// No description provided for @desktopNoPrepayments.
  ///
  /// In ru, this message translates to:
  /// **'Предоплат нет'**
  String get desktopNoPrepayments;

  /// No description provided for @desktopCapsulesWithCooler.
  ///
  /// In ru, this message translates to:
  /// **'У заказчиков с кулером'**
  String get desktopCapsulesWithCooler;

  /// No description provided for @desktopCapsulesWithoutCooler.
  ///
  /// In ru, this message translates to:
  /// **'У остальных'**
  String get desktopCapsulesWithoutCooler;

  /// No description provided for @desktopFieldCooler.
  ///
  /// In ru, this message translates to:
  /// **'Кулер'**
  String get desktopFieldCooler;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
