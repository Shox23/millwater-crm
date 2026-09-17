// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'CRM Millwater';

  @override
  String get commonCancel => 'Bekor qilish';

  @override
  String get commonCancelShort => 'Bekor';

  @override
  String get commonDelete => 'O‘chirish';

  @override
  String get commonSave => 'Saqlash';

  @override
  String get commonSaving => 'Saqlanmoqda…';

  @override
  String get commonAdd => 'Qo‘shish';

  @override
  String get commonCreate => 'Yaratish';

  @override
  String get commonCreating => 'Yaratilmoqda…';

  @override
  String get commonEdit => 'Tahrirlash';

  @override
  String get commonRetry => 'Qayta urinish';

  @override
  String get commonLeave => 'Chiqish';

  @override
  String get commonStay => 'Qolish';

  @override
  String get commonOptional => 'Majburiy emas';

  @override
  String get commonClear => 'Tozalash';

  @override
  String get commonNothingFound => 'Hech narsa topilmadi';

  @override
  String get commonDone => 'Bajarildi';

  @override
  String get commonPhone => 'Telefon';

  @override
  String get commonSum => 'so‘m';

  @override
  String moneyAmount(String amount) {
    return '$amount so‘m';
  }

  @override
  String moneyMillions(String amount) {
    return '$amount mln so‘m';
  }

  @override
  String get leaveWithoutSavingTitle => 'Saqlamasdan chiqilsinmi?';

  @override
  String get leaveWithoutSavingMessage => 'Kiritilgan ma’lumotlar yo‘qoladi.';

  @override
  String get errorGeneric => 'Amalni bajarib bo‘lmadi. Yana urinib ko‘ring.';

  @override
  String get errorNoConnection => 'Server bilan aloqa yo‘q.';

  @override
  String get errorLoadFailed => 'Ma’lumotlarni yuklab bo‘lmadi';

  @override
  String get errorCheckConnection => 'Ulanishni tekshirib, yana urinib ko‘ring';

  @override
  String emptySearchTitle(String query) {
    return '«$query» bo‘yicha hech narsa yo‘q';
  }

  @override
  String get emptySearchHint =>
      'Yozilishini tekshiring yoki qidiruvni tozalang';

  @override
  String get emptySearchAction => 'Qidiruvni tozalash';

  @override
  String get fieldRequired => 'Maydonni to‘ldiring';

  @override
  String get fieldPhoneEmpty => 'Telefon raqamini kiriting';

  @override
  String fieldPhoneIncomplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta raqam',
    );
    return 'Raqam to‘liq emas — +998 dan keyin $_temp0 kerak';
  }

  @override
  String get fieldEmailInvalid => 'Pochta formati noto‘g‘ri';

  @override
  String get fieldEmailEmpty => 'Elektron pochtani kiriting';

  @override
  String get fieldPasswordEmpty => 'Parolni kiriting';

  @override
  String fieldMinLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta belgi',
    );
    return 'Kamida $_temp0';
  }

  @override
  String fieldMaxLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta belgi',
    );
    return '${_temp0}dan ko‘p emas';
  }

  @override
  String get fieldShowPassword => 'Parolni ko‘rsatish';

  @override
  String get fieldHidePassword => 'Parolni yashirish';

  @override
  String get validationGeneric => 'To‘ldirish to‘g‘riligini tekshiring';

  @override
  String validationRequired(String field) {
    return '«$field» maydonini to‘ldiring';
  }

  @override
  String validationTooShort(String field) {
    return '«$field» maydonidagi qiymat juda qisqa';
  }

  @override
  String validationTooLong(String field) {
    return '«$field» maydonidagi qiymat juda uzun';
  }

  @override
  String validationNotNumber(String field) {
    return '«$field» maydoniga son kerak';
  }

  @override
  String validationOutOfRange(String field) {
    return '«$field» maydonidagi qiymat ruxsat etilgan chegaradan tashqarida';
  }

  @override
  String validationBadFormat(String field) {
    return '«$field» maydonidagi format noto‘g‘ri';
  }

  @override
  String get apiFieldFullName => 'Ism yoki nomi';

  @override
  String get apiFieldPhone => 'Telefon';

  @override
  String get apiFieldAddress => 'Manzil';

  @override
  String get apiFieldComment => 'Izoh';

  @override
  String get apiFieldPassword => 'Parol';

  @override
  String get apiFieldOldPassword => 'Joriy parol';

  @override
  String get apiFieldNewPassword => 'Yangi parol';

  @override
  String get apiFieldDate => 'Sana';

  @override
  String get apiFieldDriver => 'Haydovchi';

  @override
  String get apiFieldCustomers => 'Mijozlar';

  @override
  String get apiFieldCapsules => 'Kapsulalar soni';

  @override
  String get apiFieldAmount => 'To‘lov summasi';

  @override
  String get apiFieldPaymentMethod => 'To‘lov usuli';

  @override
  String get apiFieldBalance => 'Kapsulalar qoldig‘i';

  @override
  String get apiFieldPrice => 'Kapsula narxi';

  @override
  String get phoneCallUnavailable => 'Qo‘ng‘iroq imkonsiz — raqam nusxalandi';

  @override
  String get phoneCopied => 'Raqam nusxalandi';

  @override
  String get phoneCopy => 'Raqamdan nusxa olish';

  @override
  String get fieldCopy => 'Nusxa olish';

  @override
  String get fieldCopied => 'Nusxa olindi';

  @override
  String get photoTitle => 'To‘lov surati';

  @override
  String get photoSubtitle => 'Chek yoki yetkazib berish suratini biriktiring';

  @override
  String get photoError => 'Suratni olib bo‘lmadi. Ruxsatni tekshiring.';

  @override
  String get photoRemove => 'Suratni olib tashlash';

  @override
  String get photoCamera => 'Kamera';

  @override
  String get photoGallery => 'Galereya';

  @override
  String photoSize(int size) {
    return '$size KB';
  }

  @override
  String get themeSystem => 'Tizimdagidek';

  @override
  String get themeSystemShort => 'Tizim';

  @override
  String get themeLight => 'Yorug‘';

  @override
  String get themeDark => 'Qorong‘i';

  @override
  String themeTitle(String mode) {
    return 'Mavzu · $mode';
  }

  @override
  String languageTitle(String name) {
    return 'Til · $name';
  }

  @override
  String get languageRussian => 'Ruscha';

  @override
  String get languageUzbek => 'O‘zbekcha';

  @override
  String get languageSection => 'TIL';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleDriver => 'Haydovchi';

  @override
  String get deliveryPending => 'Yangi';

  @override
  String get deliveryOnWay => 'Yo‘lda';

  @override
  String get deliveryDelivered => 'Yetkazildi';

  @override
  String get deliveryFailed => 'Yetkazilmadi';

  @override
  String get deliveryPaid => 'To‘landi';

  @override
  String get routeCreated => 'Yaratilgan';

  @override
  String get routeInProgress => 'Bajarilmoqda';

  @override
  String get routeCompleted => 'Yakunlangan';

  @override
  String get routeCancelled => 'Bekor qilingan';

  @override
  String get filterAll => 'Barchasi';

  @override
  String get filterInProgress => 'Yo‘lda';

  @override
  String get filterCompleted => 'Yakunlangan';

  @override
  String get filterNew => 'Yangi';

  @override
  String get filterCancelled => 'Bekor qilinganlar';

  @override
  String get filterFailed => 'Yetkazilmaganlar';

  @override
  String get filterWithDebt => 'Qarzdor';

  @override
  String get filterWithCooler => 'Kuleri bor';

  @override
  String get filterInactive => 'Nofaol';

  @override
  String get sessionDiagTitle => 'Sessiyaning oxirgi uzilishi';

  @override
  String get sessionDiagNever => 'Uzilishlar bo‘lmagan';

  @override
  String get sessionDiagCopied => 'Nusxalandi';

  @override
  String get sessionEndRefreshFailed => 'Tokenni yangilab bo‘lmadi';

  @override
  String get sessionEndRestoreRejected => 'Server saqlangan sessiyani rad etdi';

  @override
  String get sessionEndSignedOut => 'Tugma orqali chiqish';

  @override
  String get customerFormIsActive => 'Faol';

  @override
  String get customerFormIsActiveHint =>
      'Nofaollar marshrut tuzishda taklif qilinmaydi';

  @override
  String get paymentCash => 'Naqd';

  @override
  String get paymentCard => 'Karta';

  @override
  String get paymentTransfer => 'Pul o‘tkazmasi';

  @override
  String get paymentDebt => 'Qarzga';

  @override
  String get periodToday => 'Bugun';

  @override
  String get periodWeek => 'Hafta';

  @override
  String get periodMonth => 'Oy';

  @override
  String get periodCustom => 'Boshqa sanalar…';

  @override
  String dateRangeValue(String from, String to) {
    return '$from — $to';
  }

  @override
  String get loginTitle => 'Tizimga kirish';

  @override
  String get loginPhone => 'Telefon raqami';

  @override
  String get loginPassword => 'Parol';

  @override
  String get loginSubmit => 'Kirish';

  @override
  String get loginSubmitting => 'Kirilmoqda…';

  @override
  String get loginErrorCredentials => 'Telefon yoki parol noto‘g‘ri.';

  @override
  String get loginErrorGeneric => 'Kirishda xatolik. Yana urinib ko‘ring.';

  @override
  String get loginErrorFailed => 'Kirib bo‘lmadi. Yana urinib ko‘ring.';

  @override
  String get sessionExpired => 'Sessiya tugadi. Qaytadan kiring.';

  @override
  String get navRoute => 'Marshrut';

  @override
  String get navRoutes => 'Marshrutlar';

  @override
  String get navDrivers => 'Haydovchilar';

  @override
  String get navCustomers => 'Mijozlar';

  @override
  String get navReports => 'Hisobotlar';

  @override
  String get navProfile => 'Profil';

  @override
  String routesHeaderToday(String date) {
    return 'Bugun · $date';
  }

  @override
  String routesHeaderOn(String date) {
    return '$date sanasiga';
  }

  @override
  String get routesTitle => 'Marshrutlar';

  @override
  String get routesRefresh => 'Marshrutlarni yangilash';

  @override
  String get routesCreated => 'Marshrut yaratildi';

  @override
  String get routesLoadFailed => 'Marshrutlarni yuklab bo‘lmadi';

  @override
  String get routesEmptyTitle => 'Hozircha marshrutlar yo‘q';

  @override
  String routesEmptyDayHint(String date) {
    return '$date sanasiga marshrutlar yo‘q';
  }

  @override
  String get dateTabsPick => 'Sanani tanlash';

  @override
  String get filterEmptyTitle => 'Bu filtrda hech narsa yo‘q';

  @override
  String get filterEmptyHint => 'Boshqa filtrni tanlang';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get routeCardTitle => 'Marshrut kartasi';

  @override
  String get routeLoadFailed => 'Marshrutni yuklab bo‘lmadi';

  @override
  String get routeNotFound => 'Marshrut topilmadi';

  @override
  String get routeCancelTitle => 'Marshrut bekor qilinsinmi?';

  @override
  String get routeCancelMessage => 'Marshrut bekor qilingan deb belgilanadi.';

  @override
  String get routeCancelAction => 'Marshrutni bekor qilish';

  @override
  String get desktopEditRoute => 'Marshrutni tahrirlash';

  @override
  String get routeCancelShort => 'Bekor qilish';

  @override
  String get routeCancelFailed => 'Marshrutni bekor qilib bo‘lmadi.';

  @override
  String get routeCancelled2 => 'Marshrut bekor qilindi';

  @override
  String get routeDriver => 'Haydovchi';

  @override
  String get routeStatDone => 'BAJARILDI';

  @override
  String get routeStatCollected => 'YIG‘ILDI';

  @override
  String get routeNoDriver => 'Haydovchi tayinlanmagan';

  @override
  String get routeNoDriverHint =>
      'Haydovchi yo‘q ekan, marshrutni hech kim olib ketmaydi';

  @override
  String get routeAssignDriver => 'Tayinlash';

  @override
  String get routeCashSection => 'MARSHRUT KASSASI';

  @override
  String get routeExpensesSection => 'HAYDOVCHI XARAJATLARI';

  @override
  String get routeNoExpenses => 'Marshrut bo‘yicha xarajatlar yo‘q';

  @override
  String get routeStops => 'MARSHRUT NUQTALARI';

  @override
  String routeStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuqta',
    );
    return '$_temp0';
  }

  @override
  String get routeDoneShort => 'bajarildi';

  @override
  String get routeProgressTitle => 'Yetkazib berildi';

  @override
  String get routeCollectedToday => 'Bugun yig‘ildi';

  @override
  String get routeCollected => 'Yig‘ildi';

  @override
  String stopCapsules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapsula',
    );
    return '$_temp0';
  }

  @override
  String get routeFormTitle => 'Yangi marshrut';

  @override
  String get routeFormLoadFailed =>
      'Haydovchilar va mijozlarni yuklab bo‘lmadi';

  @override
  String get routeFormCreateFailed => 'Marshrut yaratib bo‘lmadi.';

  @override
  String get routeFormDate => 'SANA';

  @override
  String get routeFormPurpose => 'MARSHRUT MAQSADI';

  @override
  String get routeFormPurposeHint => 'Barcha nuqtalar uchun standart maqsad';

  @override
  String get routeFormAssignLater => 'Keyinroq tayinlash';

  @override
  String get routeFormAssignLaterHint =>
      'Haydovchi yo‘q ekan, marshrut yangi bo‘lib qoladi';

  @override
  String get routeFormStopPurpose => 'Nuqta maqsadi';

  @override
  String get routeFormBottleSell => 'YETKAZILADIGAN KAPSULALAR';

  @override
  String get routeFormBottleSellHint => 'Bu buyurtmachiga qancha olib boriladi';

  @override
  String get routeFormBottleSellRequired =>
      'Qancha kapsula olib borishni kiriting';

  @override
  String get routeFormBottleSellLocked =>
      'Nuqta qo‘shilganda belgilangan — server uni o‘zgartira olmaydi';

  @override
  String stopBottleSell(int count) {
    return 'Kutilayotgan kapsulalar soni: $count';
  }

  @override
  String get completionBottleSell => 'YETKAZISHGA BELGILANGAN';

  @override
  String completionBottleSellValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapsula',
      one: '$count kapsula',
    );
    return '$_temp0';
  }

  @override
  String get completionBottleSellHint =>
      'Admin shuncha belgilagan. Quyida haqiqatda qancha olib kelganingizni belgilang';

  @override
  String get routeFormDriver => 'HAYDOVCHI';

  @override
  String get routeFormNoDrivers => 'Avval haydovchi qo‘shing';

  @override
  String get routeFormCustomers => 'MIJOZLAR';

  @override
  String get routeFormNoCustomers => 'Avval mijoz qo‘shing';

  @override
  String get routeEditTitle => 'Marshrutni o‘zgartirish';

  @override
  String get routeFormSaveFailed => 'O‘zgarishlarni saqlab bo‘lmadi.';

  @override
  String get routeEditInProgressHint =>
      'Marshrut allaqachon ishda: sana va haydovchini o‘zgartirish kech, faqat mijoz qo‘shish mumkin.';

  @override
  String routeFormSelected(int count) {
    return 'tanlandi: $count';
  }

  @override
  String get customerSearch => 'Mijozni qidirish';

  @override
  String get customerSearchAddress => 'Ko‘cha, massiv, uy';

  @override
  String get customerSearchModeName => 'Ism va telefon';

  @override
  String get customerSearchModeAddress => 'Manzil';

  @override
  String get stopTitle => 'Marshrut nuqtasi';

  @override
  String get stopCapsulesDelivered => 'kapsula yetkazildi';

  @override
  String stopBulkBottles(int count, int liters) {
    return '$count × $liters l';
  }

  @override
  String get stopNothingTaken => 'hech narsa olinmadi';

  @override
  String get stopPaid => 'to‘landi';

  @override
  String get stopCompleted => 'Yakunlandi';

  @override
  String get stopPhotoLabel => 'TO‘LOV SURATI';

  @override
  String get stopPhotoFailed => 'Suratni yuklab bo‘lmadi';

  @override
  String get mapSectionLabel => 'XARITADAGI MARSHRUT';

  @override
  String get mapFromCurrentPlace =>
      'Marshrut hozirgi joylashuvingizdan quriladi.';

  @override
  String get mapBuildRoute => 'Marshrut qurish';

  @override
  String get mapNeedOnePoint => 'Marshrut uchun kamida bitta nuqta kerak.';

  @override
  String mapPointWithoutAddress(int number) {
    return '$number-nuqtada manzil ko‘rsatilmagan.';
  }

  @override
  String get mapOpenFailed => 'Yandex.Xaritani ochib bo‘lmadi';

  @override
  String get mapAllStopsDone =>
      'Marshrutning barcha nuqtalari yopilgan — boradigan joy yo‘q.';

  @override
  String mapStopsWithoutPoint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta manzilning xaritada nuqtasi yo‘q',
    );
    return '$_temp0';
  }

  @override
  String get mapAddMapLinkHint =>
      'Bunday marshrut brauzerda ochiladi. Yandex.Xaritada ochilishi uchun mijoz manziliga xaritadagi havolani qo‘ying.';

  @override
  String get driversTitle => 'Haydovchilar';

  @override
  String driversHeader(int count) {
    return 'Jamoa · $count';
  }

  @override
  String driversHeaderFound(int count) {
    return 'Topildi · $count';
  }

  @override
  String get driversSearch => 'Haydovchini qidirish';

  @override
  String get driversRefresh => 'Ro‘yxatni yangilash';

  @override
  String get driversLoadFailed => 'Haydovchilarni yuklab bo‘lmadi';

  @override
  String get driversEmptyTitle => 'Hozircha haydovchilar yo‘q';

  @override
  String get driversEmptyHint =>
      'Birinchisini qo‘shing — unga marshrut biriktirish mumkin bo‘ladi';

  @override
  String get driversEmptyAction => 'Haydovchi qo‘shish';

  @override
  String get driverAdded => 'Haydovchi qo‘shildi';

  @override
  String get driverDeleted => 'Haydovchi o‘chirildi';

  @override
  String get changesSaved => 'O‘zgarishlar saqlandi';

  @override
  String get driverDeleteTitle => 'Haydovchi o‘chirilsinmi?';

  @override
  String driverDeleteMessage(String name) {
    return '$name ro‘yxatdan o‘chiriladi.';
  }

  @override
  String get driverDeleteFailed => 'Haydovchini o‘chirib bo‘lmadi.';

  @override
  String get driverTitle => 'Haydovchi';

  @override
  String get driverOnRoute => 'Bugun marshrutda';

  @override
  String get driverNoTrips => 'Bugun reyslar yo‘q';

  @override
  String get driverTripsTotal => 'jami reyslar';

  @override
  String get driverTripsToday => 'bugungi reyslar';

  @override
  String get driverReportTile => 'Haydovchi bo‘yicha hisobot';

  @override
  String get driverReportTileHint =>
      'Davr uchun buyurtma va xarajatlar Excelda';

  @override
  String get driverCreatedAt => 'Yaratilgan sana';

  @override
  String get driverTripsAndToday => 'bugun';

  @override
  String get driverFormEditTitle => 'Haydovchini tahrirlash';

  @override
  String get driverFormNewTitle => 'Yangi haydovchi';

  @override
  String get driverFormName => 'Haydovchi ismi';

  @override
  String get driverFormNameHint => 'Masalan, Aziz Karimov';

  @override
  String get driverFormNameEmpty => 'Haydovchi ismini kiriting';

  @override
  String get driverFormPassword => 'Kirish uchun parol';

  @override
  String get driverFormPasswordHelper =>
      'Parolni haydovchiga bering — keyin uni tiklab bo‘lmaydi';

  @override
  String get driverFormSaveFailed => 'Haydovchini saqlab bo‘lmadi.';

  @override
  String get minSixChars => 'Kamida 6 ta belgi';

  @override
  String get customersTitle => 'Mijozlar';

  @override
  String customersHeader(int count) {
    return 'Baza · $count';
  }

  @override
  String customersHeaderFound(int count) {
    return 'Topildi · $count';
  }

  @override
  String get customersLoadFailed => 'Mijozlarni yuklab bo‘lmadi';

  @override
  String get customersEmptyTitle => 'Hozircha mijozlar yo‘q';

  @override
  String get customersEmptyHint =>
      'Birinchisini qo‘shing — u ro‘yxatda va marshrutlarda ko‘rinadi';

  @override
  String get customersEmptyAction => 'Mijoz qo‘shish';

  @override
  String get customerAdded => 'Mijoz qo‘shildi';

  @override
  String get customerDeleted => 'Mijoz o‘chirildi';

  @override
  String get customerDeleteTitle => 'Mijoz o‘chirilsinmi?';

  @override
  String customerDeleteMessage(String name) {
    return '$name bazadan o‘chiriladi.';
  }

  @override
  String get customerDeleteFailed => 'Mijozni o‘chirib bo‘lmadi.';

  @override
  String get customerTitle => 'Mijoz';

  @override
  String get customerHasCooler => 'Kuler bor';

  @override
  String get customerFormHasCooler => 'Mijozda kuler bor';

  @override
  String get customerCapsulesBalance => 'qo‘lidagi kapsula';

  @override
  String get customerLastOrder => 'oxirgi buyurtma';

  @override
  String customerLastOrderShort(String date) {
    return 'oxirgi buyurtma $date';
  }

  @override
  String get financePrepayment => 'Oldindan to‘lov';

  @override
  String get financeDebt => 'Qarz';

  @override
  String get customerFormEditTitle => 'Mijozni tahrirlash';

  @override
  String get customerFormNewTitle => 'Yangi mijoz';

  @override
  String get customerFormName => 'Nomi / ismi';

  @override
  String get customerFormNameHint => 'Masalan, «Nasiba» kafesi';

  @override
  String get customerFormNameEmpty => 'Nomi yoki ismini kiriting';

  @override
  String get customerFormAddress => 'Yetkazib berish manzili';

  @override
  String get customerFormAddressHint => 'Tuman, ko‘cha, uy';

  @override
  String get customerFormAddressEmpty => 'Yetkazib berish manzilini kiriting';

  @override
  String get customerFormPhoneSecondary => 'Qo‘shimcha telefon';

  @override
  String get customerFormComment => 'Izoh';

  @override
  String get customerFormCommentHint => 'Masalan, tuman yoki mo‘ljal';

  @override
  String get customerFormSaveFailed => 'Mijozni saqlab bo‘lmadi.';

  @override
  String get myRoutesTitle => 'Mening marshrutlarim';

  @override
  String get myRoutesStatRoutes => 'kunlik marshrut';

  @override
  String get myRoutesStatDeliveredToday => 'yetkazildi';

  @override
  String get myRoutesStatOrders => 'kunlik buyurtma';

  @override
  String get myRoutesEmptyHint =>
      'Dispetcher marshrut biriktirsa, u shu yerda paydo bo‘ladi';

  @override
  String get myRouteTitle => 'Marshrut';

  @override
  String get myRouteStatusFailed => 'Holatni o‘zgartirib bo‘lmadi.';

  @override
  String myRouteStatusChanged(String status) {
    return 'Holat: $status';
  }

  @override
  String get myRouteChangeStatus => 'Holatni o‘zgartirish';

  @override
  String get completionTitle => 'Yetkazishni yakunlash';

  @override
  String get completionCoordinates => 'NUQTA KOORDINATALARI';

  @override
  String get completionCapsules => 'KAPSULALAR SONI';

  @override
  String completionCapsulesCaption(int liters) {
    return '$liters l kapsula';
  }

  @override
  String get completionBalance => 'MIJOZDAGI KAPSULALAR';

  @override
  String completionBalanceFormula(int before, int delivered) {
    return 'avval $before + keltirildi $delivered';
  }

  @override
  String get completionMethod => 'TO‘LOV USULI';

  @override
  String get completionAmount => 'TO‘LOV SUMMASI';

  @override
  String get completionAmountRequired =>
      'Summani kiriting. To‘lov bo‘lmagan bo‘lsa — nol';

  @override
  String get completionTotal => 'Jami to‘lov';

  @override
  String get completionSubmit => 'Yakunlash';

  @override
  String get completionForbidden =>
      'Yetkazishni faqat shu marshrut haydovchisi yakunlay oladi.';

  @override
  String get completionFailed => 'Yetkazishni yakunlab bo‘lmadi.';

  @override
  String completionByPrice(String formula) {
    return 'Narxlar bo‘yicha: $formula';
  }

  @override
  String get completionRestoreAmount => 'Hisobni qaytarish';

  @override
  String get locationSearching => 'Koordinatalar aniqlanmoqda…';

  @override
  String get locationFixed => 'Nuqta belgilandi';

  @override
  String get locationNotFixed => 'Nuqta belgilanmadi';

  @override
  String get locationCanContinue => 'Yetkazishni shundayam yakunlash mumkin.';

  @override
  String get locationRetry => 'Qaytadan aniqlash';

  @override
  String get locationDisabled =>
      'Geolokatsiya telefon sozlamalarida o‘chirilgan.';

  @override
  String get locationDeniedForever =>
      'Geolokatsiyaga ruxsat yo‘q. Telefon sozlamalaridan ruxsat bering.';

  @override
  String get locationDenied => 'Geolokatsiyaga ruxsat yo‘q.';

  @override
  String get locationUnknown => 'Koordinatalarni aniqlab bo‘lmadi.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileAccountLabel => 'Hisob';

  @override
  String get profileStatsSection => 'STATISTIKA';

  @override
  String get profileStatsCapsules => 'Sotilgan kapsulalar';

  @override
  String get profileStatsBulk => 'Ulgurji 5 l / 10 l';

  @override
  String get profileStatsExpenses => 'Davr xarajatlari';

  @override
  String get profileStatsFailed => 'Statistikani hisoblab bo‘lmadi';

  @override
  String profileStatsBulkValue(int five, int ten) {
    return '$five / $ten';
  }

  @override
  String get profileAccountSection => 'HISOB';

  @override
  String get settingsAppearance => 'KO‘RINISH';

  @override
  String get settingsAccount => 'HISOB';

  @override
  String get settingsSessionActive => 'Sessiya faol';

  @override
  String get settingsLogout => 'Hisobdan chiqish';

  @override
  String get settingsLogoutTitle => 'Hisobdan chiqilsinmi?';

  @override
  String get settingsLogoutMessage =>
      'Telefon raqami va parol bilan qaytadan kirishga to‘g‘ri keladi.';

  @override
  String get passwordChangeTitle => 'Parolni o‘zgartirish';

  @override
  String get passwordChangeTile => 'Parolni o‘zgartirish';

  @override
  String get passwordChangeTileHint => 'Joriy parol kerak bo‘ladi';

  @override
  String get passwordChanged => 'Parol o‘zgartirildi';

  @override
  String get passwordCurrent => 'Joriy parol';

  @override
  String get passwordCurrentEmpty => 'Joriy parolni kiriting';

  @override
  String get passwordNew => 'Yangi parol';

  @override
  String get passwordRepeat => 'Yangi parolni takrorlang';

  @override
  String get passwordSameAsCurrent => 'Yangi parol joriy parol bilan bir xil';

  @override
  String get passwordMismatch => 'Parollar mos kelmadi';

  @override
  String get passwordChangeFailed => 'Parolni o‘zgartirib bo‘lmadi.';

  @override
  String get passwordWrongCurrent => 'Joriy parol noto‘g‘ri.';

  @override
  String get passwordKeepMessage => 'Parol o‘zgarishsiz qoladi.';

  @override
  String get passwordSubmit => 'O‘zgartirish';

  @override
  String get pricesTitle => 'Narxlar';

  @override
  String get pricesTileHint => 'Kapsula narxi va idish garovi';

  @override
  String get pricesSection => 'NARXLAR';

  @override
  String get pricesUpdated => 'Narxlar yangilandi';

  @override
  String get pricesLoadFailed => 'Narxlarni yuklab bo‘lmadi';

  @override
  String get pricesSaveFailed => 'Narxlarni saqlab bo‘lmadi.';

  @override
  String get pricesCurrent => 'AMALDAGI NARXLAR';

  @override
  String get pricesNew => 'YANGI QIYMATLAR';

  @override
  String get pricesHistory => 'O‘ZGARISHLAR TARIXI';

  @override
  String get pricesCapsule => 'Kapsula narxi';

  @override
  String pricesCapsuleHelper(int liters) {
    return 'Bitta $liters l kapsula uchun so‘m';
  }

  @override
  String pricesCapsuleRow(int liters) {
    return 'Kapsula $liters l';
  }

  @override
  String get pricesEmpty => 'Narxni kiriting';

  @override
  String get pricesZero => 'Kapsula narxi noldan katta bo‘lishi kerak';

  @override
  String get pricesConfirmTitle => 'Yangi narx belgilansinmi?';

  @override
  String pricesConfirmMessage(String capsule) {
    return 'Kapsula — $capsule.';
  }

  @override
  String get pricesConfirmAction => 'Belgilash';

  @override
  String pricesEffectiveFrom(String date) {
    return '$date dan amal qiladi';
  }

  @override
  String get pricesEffectiveFromColumn => 'Amal qiladi';

  @override
  String get pricesHistoryFailed => 'Tarixni yuklab bo‘lmadi.';

  @override
  String get pricesHistoryEmpty =>
      'Narx hali o‘zgartirilmagan — bu birinchi narx.';

  @override
  String get reportsLabel => 'Tahlil';

  @override
  String get reportsTitle => 'Hisobotlar';

  @override
  String get reportExportTitle => 'Excelga yuklash';

  @override
  String get reportExportKind => 'HISOBOT TURI';

  @override
  String get reportKindGeneral => 'Umumiy';

  @override
  String get reportKindGeneralHint => 'Har bir yetkazib berish uchun qator';

  @override
  String get reportKindCustomers => 'Mijozlar';

  @override
  String get reportKindCustomersHint =>
      'Davr uchun har bir mijoz bo‘yicha jami';

  @override
  String get reportKindDrivers => 'Haydovchilar';

  @override
  String get reportKindDriversHint =>
      'Haydovchilar bo‘yicha buyurtma va xarajatlar';

  @override
  String get reportExportDriver => 'HAYDOVCHI';

  @override
  String get reportExportAllDrivers => 'Barcha haydovchilar';

  @override
  String get reportExportPeriod => 'DAVR';

  @override
  String get reportExportAction => 'Yuklash';

  @override
  String get reportExportDone => 'Hisobot yuklandi';

  @override
  String get reportsExport => 'Excelga yuklash';

  @override
  String get reportsExportSubject => 'Millwater hisoboti';

  @override
  String get reportsExportFailed => 'Hisobotni yuklab bo‘lmadi.';

  @override
  String get reportsLoadFailed => 'Hisobotlarni yuklab bo‘lmadi';

  @override
  String get reportsRevenue => 'Tushum';

  @override
  String get reportsDeliveries => 'Yetkazishlar';

  @override
  String get reportsDebts => 'Qarzlar';

  @override
  String get reportsCapsules => 'Mijozlardagi kapsulalar';

  @override
  String reportsCapsulesCount(int count) {
    return '$count dona';
  }

  @override
  String get reportsDebtors => 'Mijozlar qarzi';

  @override
  String capsulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapsula',
    );
    return '$_temp0';
  }

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reys',
    );
    return '$_temp0';
  }

  @override
  String clientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mijoz',
    );
    return '$_temp0';
  }

  @override
  String get desktopBrandSubtitle => 'Suv yetkazib berish';

  @override
  String get desktopNavGroup => 'ISH';

  @override
  String get desktopOnLineTitle => 'BUGUN LINIYADA';

  @override
  String desktopOnLineOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count haydovchidan',
    );
    return '$_temp0';
  }

  @override
  String get desktopSearchHint => 'Qidirish';

  @override
  String get desktopNotifications => 'Bildirishnomalar';

  @override
  String get desktopAddDriver => 'Haydovchi';

  @override
  String get desktopAddRoute => 'Marshrut';

  @override
  String get desktopAddCustomer => 'Mijoz';

  @override
  String desktopRoutesSubtitle(String date, int count) {
    return '$date · $count ta ishda';
  }

  @override
  String get desktopDriverStubTitle => 'Bu — administratorning ish joyi';

  @override
  String get desktopDriverStubHint =>
      'Marshrutlar va yetkazmalar mobil ilovada ochiladi — telefondan kiring.';

  @override
  String driversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count haydovchi',
    );
    return '$_temp0';
  }

  @override
  String customersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mijoz',
    );
    return '$_temp0';
  }

  @override
  String get filterDelivered => 'Yetkazilgan';

  @override
  String get desktopColCustomer => 'MIJOZ';

  @override
  String get desktopColDriver => 'HAYDOVCHI';

  @override
  String get desktopColCapsules => 'KAPSULALAR';

  @override
  String get desktopColSum => 'SUMMA';

  @override
  String get desktopColPayment => 'TO‘LOV';

  @override
  String get navCash => 'Kassa';

  @override
  String get cashDesktopTitle => 'Kassa va xarajatlar';

  @override
  String get cashDesktopTotal => 'Davr xarajatlari';

  @override
  String get cashDesktopEmpty => 'Davr uchun xarajatlar yo‘q';

  @override
  String get cashDesktopEmptyHint => 'Boshqa davr yoki toifani tanlang';

  @override
  String get cashDesktopFailed => 'Xarajatlarni yuklab bo‘lmadi';

  @override
  String get desktopColCategory => 'TOIFA';

  @override
  String get desktopColComment => 'IZOH';

  @override
  String get desktopColDate => 'SANA';

  @override
  String get desktopColNumber => '№';

  @override
  String get desktopColPurpose => 'MAQSAD';

  @override
  String get desktopColDamaged => 'BRAK';

  @override
  String get desktopColStatus => 'HOLAT';

  @override
  String get desktopKpiCollected => 'Kun davomida yig‘ildi';

  @override
  String get desktopKpiDebt => 'Kun davomida qarzga';

  @override
  String get desktopKpiCashBalance => 'Kassa qoldig‘i';

  @override
  String get desktopKpiExpenses => 'Kunlik xarajatlar';

  @override
  String get desktopKpiCapsules => 'Berilgan kapsulalar';

  @override
  String get desktopKpiPlannedStops => 'Rejadagi nuqtalar';

  @override
  String get desktopExpectedWholeDay => 'Butun kun';

  @override
  String get desktopKpiPlannedDrivers => 'Kunga haydovchilar';

  @override
  String get desktopKpiPlannedCustomers => 'Rejadagi mijozlar';

  @override
  String get desktopSummaryDone => 'Bajarilgan yetkazmalar';

  @override
  String get desktopSummaryPlanned => 'Rejalashtirilgan yetkazmalar';

  @override
  String get desktopDebtShort => 'Qarzga';

  @override
  String get desktopDateToday => 'bugun';

  @override
  String desktopDatePlanned(int count) {
    return '$count ta rejada';
  }

  @override
  String get desktopDayEmpty => 'Bu kunga yetkazmalar yo‘q';

  @override
  String get desktopDayEmptyHint =>
      'Marshrut yarating yoki boshqa kunni tanlang';

  @override
  String get desktopDebtEstimated => 'kapsula narxi bo‘yicha taxmin';

  @override
  String routesCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marshrut',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Yopish';

  @override
  String get desktopDeliveryTitle => 'Yetkazma';

  @override
  String get desktopFinishedAndPaid => 'Yakunlangan va to‘langan';

  @override
  String get desktopDeleteRoute => 'Marshrutni o‘chirish';

  @override
  String get routeDeleteTitle => 'Marshrut o‘chirilsinmi?';

  @override
  String get routeDeleteMessage =>
      'Marshrut va undagi barcha yetkazmalar butunlay o‘chiriladi.';

  @override
  String get routeDeleted => 'Marshrut o‘chirildi';

  @override
  String get routeDeleteFailed => 'Marshrutni o‘chirib bo‘lmadi.';

  @override
  String get desktopOnLine => 'Liniyada';

  @override
  String get desktopFree => 'Bo‘sh';

  @override
  String get desktopColAddress => 'MANZIL';

  @override
  String get desktopColBalance => 'BALANS';

  @override
  String get desktopColLastOrder => 'OXIRGI BUYURTMA';

  @override
  String get desktopColCapsulesShort => 'KAPSULA';

  @override
  String desktopBalanceDebt(String amount) {
    return 'Qarz $amount';
  }

  @override
  String desktopBalancePrepaid(String amount) {
    return 'Avans $amount';
  }

  @override
  String get desktopSuccessDone => 'Tayyor';

  @override
  String get desktopWithCooler => 'Kuler bilan';

  @override
  String get desktopWithoutCooler => 'Kulersiz';

  @override
  String get desktopFieldCapsules => 'Kapsulalar';

  @override
  String get desktopFieldSum => 'Summa';

  @override
  String get desktopFieldStatus => 'Holat';

  @override
  String get desktopFieldTime => 'Yopilgan';

  @override
  String get desktopFieldAddress => 'Manzil';

  @override
  String get desktopChartTitle => 'Kunlar bo‘yicha tushum';

  @override
  String get desktopPrepayments => 'Avanslar';

  @override
  String get desktopNoDebtors => 'Qarzdorlar yo‘q';

  @override
  String get desktopNoPrepayments => 'Avanslar yo‘q';

  @override
  String get desktopCapsulesWithCooler => 'Kuleri bor mijozlarda';

  @override
  String get desktopCapsulesWithoutCooler => 'Qolganlarda';

  @override
  String get desktopFieldCooler => 'Kuler';

  @override
  String get orderPurposeDelivery => '19 l yetkazish';

  @override
  String get orderPurposePickup => 'Olib ketish';

  @override
  String get orderPurposeDeliveryShort => '19 l';

  @override
  String get orderPurposePickupShort => 'Olib ketish';

  @override
  String get orderPurposeBulkShort => 'Ulgurji';

  @override
  String get orderPurposeBulk => 'Ulgurji 5/10 l';

  @override
  String coolersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kuler',
    );
    return '$_temp0';
  }

  @override
  String customerCustomPrice(String price) {
    return 'Shaxsiy narx: $price';
  }

  @override
  String get customerFormCoolers => 'Mijozdagi kulerlar soni';

  @override
  String get customerFormCoolersHint =>
      'Kulerga kapsula qo‘yiladi, usiz suv quyib beriladi';

  @override
  String get customerFormCapsules => 'Mijozdagi kapsulalar soni';

  @override
  String get customerFormCapsulesHint => 'Hozir qo‘lida nechta tara bor';

  @override
  String get customerFormCapsulesLocked =>
      'Haydovchi yuritadigan qoldiqni almashtiradi';

  @override
  String get customerFormLastOrder => 'Oxirgi buyurtma';

  @override
  String get customerFormLastOrderHint =>
      'Mijoz oxirgi marta qachon suv olgan — shu kun bo‘yicha ro‘yxat jim qolganlarni ajratib ko‘rsatadi';

  @override
  String get customerFormLastOrderNone => 'Ko‘rsatilmagan';

  @override
  String get customerFormLastOrderLocked =>
      'Yetkazib berish yopilganda qo‘yiladigan sanani almashtiradi';

  @override
  String get customerFormBalance => 'Boshlang‘ich balans';

  @override
  String get customerFormBalanceNone => 'Yo‘q';

  @override
  String get customerFormBalanceDebt => 'Qarz';

  @override
  String get customerFormBalancePrepayment => 'Oldindan to‘lov';

  @override
  String get customerFormBalanceAmount => 'Summa';

  @override
  String get customerFormBalanceEmpty => 'Summani kiriting';

  @override
  String get customerFormBalanceHint =>
      'Qarz va oldindan to‘lov bir vaqtda bo‘lmaydi';

  @override
  String get customerFormPrice => 'Kapsula narxi';

  @override
  String get customerFormPriceDefault => 'Narxlar bo‘yicha';

  @override
  String get customerFormPriceCustom => 'Shaxsiy';

  @override
  String get customerFormPriceValue => 'Mijoz uchun narx';

  @override
  String get customerFormPriceEmpty => 'Narxni kiriting';

  @override
  String customerFormPriceHelper(String price) {
    return 'Umumiy narx: $price';
  }

  @override
  String get pricesDamagedFine => 'Shikast uchun jarima';

  @override
  String get pricesDamagedFineHelper =>
      'Bitta shikastlangan kapsula uchun so‘m';

  @override
  String get pricesDamagedFineRow => 'Kapsula uchun jarima';

  @override
  String get completionDebtLine => 'Qarzga yoziladi';

  @override
  String get completionDebtHint =>
      'Qarzga pul olinmaydi — summa mijozga yoziladi';

  @override
  String get completionReturned => 'BO‘SH QAYTARILDI';

  @override
  String get completionReturnedCaption => 'buyurtmachidan olingan kapsulalar';

  @override
  String get completionDamaged => 'SHIKASTLANGAN';

  @override
  String get completionDamagedCaption => 'brak kapsulalar — ular uchun jarima';

  @override
  String get completionPickedCoolers => 'KULERLAR OLINDI';

  @override
  String get completionPickedCoolersCaption =>
      'nuqtadan olib ketiladigan kulerlar';

  @override
  String get completionPickedBottles => 'KAPSULALAR OLINDI';

  @override
  String get completionPickedBottlesCaption =>
      'nuqtadan olib ketiladigan kapsulalar';

  @override
  String get completionBulk5l => '5 L BUTILKALAR';

  @override
  String get completionBulk10l => '10 L BUTILKALAR';

  @override
  String get completionBulkCount => 'soni';

  @override
  String get completionBulkPrice => 'Bitta butilka narxi';

  @override
  String get completionBulkPriceRequired =>
      'Butilka narxini kiriting — aks holda server qabul qilmaydi';

  @override
  String get completionPickupHint =>
      'Olib ketish summasi — mijoz bilan kelishuv bo‘yicha';

  @override
  String get completionZeroNeedsDebt =>
      'Nol summani server faqat «Qarzga» usuli bilan qabul qiladi';

  @override
  String get completionPickupRequired =>
      'Nimani olganingizni kiriting: kuler, kapsula yoki brak';

  @override
  String get completionDeliveryRequired =>
      'Nima keltirganingizni, brak olganingizni yoki qaytarish qabul qilganingizni kiriting';

  @override
  String completionFormulaDamaged(
    String capsules,
    String price,
    String damaged,
    String fine,
  ) {
    return '$capsules × $price + brak $damaged × $fine';
  }

  @override
  String get errorBothBalances =>
      'Mijozda qarz va oldindan to‘lov bir vaqtda bo‘lmaydi';

  @override
  String get errorOrderCompleted => 'Buyurtma allaqachon yopilgan';

  @override
  String get errorOrderNotCompleted => 'Buyurtma hali yopilmagan';

  @override
  String get errorRouteNotInProgress => 'Marshrut ishda emas';

  @override
  String get errorBulkPriceRequired => 'Ulgurji uchun narxni kiriting';

  @override
  String get errorInvalidDamagedCount =>
      'Shikastlanganlar olib kelingan va olingandan ko‘p';

  @override
  String get errorCustomerPhoneExists =>
      'Bu raqam boshqa mijozga biriktirilgan';

  @override
  String get errorPhoneExists => 'Bu raqam allaqachon band';

  @override
  String get errorDriverBusy => 'Haydovchida bu sanaga marshrut bor';

  @override
  String get errorRouteStarted => 'Marshrut allaqachon boshlangan';

  @override
  String get errorRouteCompleted => 'Marshrut allaqachon yakunlangan';

  @override
  String get errorAccessDenied => 'Ruxsat yo‘q';

  @override
  String get errorNotFound => 'Yozuv topilmadi';

  @override
  String get ordersTitle => 'Buyurtmalar';

  @override
  String get ordersTileHint => 'Butun davr uchun barcha buyurtmalar';

  @override
  String get ordersDateRange => 'Davr…';

  @override
  String ordersDateRangeValue(String from, String to) {
    return '$from — $to';
  }

  @override
  String get ordersSearch => 'Mijoz, telefon, manzil';

  @override
  String get ordersEmpty => 'Hozircha buyurtmalar yo‘q';

  @override
  String get ordersLoadFailed => 'Buyurtmalarni yuklab bo‘lmadi';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buyurtma',
    );
    return '$_temp0';
  }

  @override
  String orderNumber(int number) {
    return 'Buyurtma №$number';
  }

  @override
  String get orderNoDriver => 'Haydovchi tayinlanmagan';

  @override
  String get orderBulk5l => '5 l butilkalar';

  @override
  String get orderBulk10l => '10 l butilkalar';

  @override
  String get orderPickedCoolers => 'Kulerlar olindi';

  @override
  String get orderPickedBottles => 'Kapsulalar olindi';

  @override
  String get orderBulkTotal => 'Ulgurji, summa';

  @override
  String get orderSectionPayments => 'TO‘LOVLAR TARIXI';

  @override
  String get orderPaymentsEmpty => 'Buyurtma bo‘yicha to‘lovlar yo‘q';

  @override
  String get orderPaymentRefund => 'Qaytarish';

  @override
  String get orderUnpaid => 'Olish qoldi';

  @override
  String get orderSectionExpected => 'KUTILMOQDA';

  @override
  String get orderExpectedCapsules => 'Kutilayotgan kapsulalar soni';

  @override
  String get orderExpectedAmount => 'Kutilayotgan summa';

  @override
  String get orderSectionComposition => 'TARKIBI';

  @override
  String get orderSectionMoney => 'HISOB';

  @override
  String get orderSectionRoute => 'MARSHRUT';

  @override
  String get orderDelivered => 'Yetkazildi';

  @override
  String get orderReturned => 'Bo‘sh olindi';

  @override
  String get orderDamaged => 'Shikastlangan';

  @override
  String get orderBalanceAfter => 'Mijozdagi qoldiq';

  @override
  String get orderAmount => 'Buyurtma summasi';

  @override
  String get orderPriceApplied => 'Buyurtmadagi kapsula narxi';

  @override
  String get orderFineApplied => 'Shikast uchun jarima';

  @override
  String get orderPaymentMethod => 'To‘lov usuli';

  @override
  String get orderCompletedAt => 'Yopilgan';

  @override
  String get orderCreatedAt => 'Yaratilgan';

  @override
  String get orderNotCompleted => 'Hali yopilmagan';

  @override
  String get orderOpenFailed => 'Buyurtmani ochib bo‘lmadi';

  @override
  String get driverOrdersTitle => 'Mening buyurtmalarim';

  @override
  String get driverOrdersTileHint => 'Butun davr uchun buyurtmalar tarixi';

  @override
  String pricesFineRow(String amount) {
    return 'jarima $amount';
  }

  @override
  String pricesConfirmFine(String fine) {
    return 'Shikastlangan kapsula uchun jarima — $fine.';
  }

  @override
  String get orderMoveTitle => 'Buyurtmani ko‘chirish';

  @override
  String get orderMoveDate => 'Sana';

  @override
  String get orderMoveRoutes => 'SHU SANADAGI MARSHRUT';

  @override
  String get orderMoveNewRoute => 'Yangi marshrut';

  @override
  String get orderMoveNewRouteHint =>
      'Server tanlangan sanaga marshrut yaratadi';

  @override
  String get orderMoveNoDriver =>
      'Yangi marshrutda haydovchi bo‘lmaydi — uni marshrutlar ekranida tayinlang';

  @override
  String get orderMoveNoRoutes => 'Bu sanaga hozircha marshrut yo‘q';

  @override
  String get orderMoveRoutesFailed => 'Marshrutlarni yuklab bo‘lmadi';

  @override
  String get orderMoveAction => 'Ko‘chirish';

  @override
  String get orderMoveFailed => 'Buyurtmani ko‘chirib bo‘lmadi.';

  @override
  String get orderMoved => 'Buyurtma ko‘chirildi';

  @override
  String orderRouteStops(int count, String driver) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuqta',
    );
    return '$_temp0 · $driver';
  }

  @override
  String get orderNoDriverShort => 'haydovchisiz';

  @override
  String get orderPaymentTitle => 'To‘lovni o‘zgartirish';

  @override
  String get orderPaymentAmount => 'Buyurtmaning yakuniy summasi';

  @override
  String get orderPaymentAmountHint =>
      'Qo‘shimcha to‘lov emas, butun summa: farqni server o‘zi hisoblaydi';

  @override
  String get orderPaymentAmountEmpty => 'Summani kiriting';

  @override
  String orderPaymentWasBecomes(String before, String after) {
    return 'Edi $before → bo‘ladi $after';
  }

  @override
  String get orderPaymentNote => 'Izoh';

  @override
  String get orderPaymentNoteHint =>
      'Nima uchun o‘zgartirdingiz — to‘lovlar tarixida qoladi';

  @override
  String get orderPaymentBalanceNow => 'Mijoz balansi hozir';

  @override
  String get orderPaymentBalanceHint =>
      'Farqni server mijozga qarz yoki oldindan to‘lov qilib yozadi';

  @override
  String get orderPaymentSaved => 'To‘lov o‘zgartirildi';

  @override
  String get orderPaymentFailed => 'To‘lovni o‘zgartirib bo‘lmadi.';

  @override
  String get orderActionMove => 'Ko‘chirish';

  @override
  String get orderActionPayment => 'To‘lovni o‘zgartirish';

  @override
  String get expenseCategoryFuel => 'Yoqilg‘i';

  @override
  String get expenseCategoryLunch => 'Tushlik';

  @override
  String get expenseCategoryRepair => 'Ta’mirlash';

  @override
  String get expenseCategoryOther => 'Boshqa';

  @override
  String get cashTitle => 'Marshrut kassasi';

  @override
  String get cashOpen => 'Kassa va xarajatlar';

  @override
  String get cashCollectedCash => 'Naqd';

  @override
  String get cashCollectedCashless => 'Naqdsiz';

  @override
  String get cashDebtAmount => 'Qarzga ketdi';

  @override
  String get cashExpensesTotal => 'Xarajatlar';

  @override
  String get cashBalance => 'Naqd qoldiq';

  @override
  String get cashBalanceHint =>
      'Yig‘ilgan naqd minus xarajatlar — shuncha topshiriladi';

  @override
  String get cashExpensesSection => 'XARAJATLAR';

  @override
  String get cashNoExpenses => 'Hozircha xarajat yo‘q';

  @override
  String get cashAddExpense => 'Xarajat qo‘shish';

  @override
  String get cashLoadFailed => 'Kassani yuklab bo‘lmadi';

  @override
  String get expenseTitle => 'Yangi xarajat';

  @override
  String get expenseAmount => 'Xarajat summasi';

  @override
  String get expenseAmountHint => 'Kassadan qancha sarflandi';

  @override
  String get expenseAmountRequired => 'Noldan katta summa kiriting';

  @override
  String get expenseCategory => 'TOIFA';

  @override
  String get expenseComment => 'Izoh';

  @override
  String get expenseCommentHint => 'Nimaga sarflandi — hisobotda qoladi';

  @override
  String get expensePhoto => 'Chek surati';

  @override
  String get expensePhotoSubtitle =>
      'Chek surati — xarajat shu bo‘yicha tekshiriladi';

  @override
  String get expenseSaved => 'Xarajat yozildi';

  @override
  String get expenseFailed => 'Xarajatni yozib bo‘lmadi.';

  @override
  String get expenseDelete => 'Xarajatni o‘chirish';

  @override
  String get expenseDeleteConfirm =>
      'Xarajat kassaga qaytariladi. O‘chirilsinmi?';

  @override
  String get expenseDeleteFailed => 'Xarajatni o‘chirib bo‘lmadi.';

  @override
  String get errorDateInPast => 'Sana o‘tmishda bo‘lishi mumkin emas';

  @override
  String get errorLastOrderDateFuture =>
      'Oxirgi buyurtma sanasi kelajakda bo‘lishi mumkin emas';

  @override
  String get deliveryCancelled => 'Bekor qilingan';

  @override
  String get orderReturnedFull => 'Suv bilan qaytarildi';

  @override
  String get completionReturnedFull => 'SUV BILAN QAYTARILDI';

  @override
  String get completionReturnedFullCaption =>
      'to‘la kapsulalarni buyurtmachi qaytardi — qoldig‘idan chiqadi';

  @override
  String completionBalanceFormulaReturned(
    int before,
    int delivered,
    int returned,
  ) {
    return 'avval $before + keltirildi $delivered − qaytarildi $returned';
  }

  @override
  String completionFormulaReturnedPart(String returned, String price) {
    return '− qaytarish $returned × $price';
  }

  @override
  String get completionReturnedFullHint =>
      'Qaytarish bo‘yicha yakunni server hisoblaydi — bu yerdagi summa taxminiy';

  @override
  String get orderActionCancel => 'Buyurtmani bekor qilish';

  @override
  String get orderCancelTitle => 'Buyurtmani bekor qilish';

  @override
  String get orderCancelWarning =>
      'Buyurtma yetkazilmasdan yopiladi. Uni qayta ishga qaytarib bo‘lmaydi.';

  @override
  String get orderCancelReason => 'Bekor qilish sababi';

  @override
  String get orderCancelReasonHint =>
      'Majburiy emas — buyurtma kartasida qoladi';

  @override
  String get orderCancelled => 'Buyurtma bekor qilindi';

  @override
  String get orderCancelFailed => 'Buyurtmani bekor qilib bo‘lmadi.';

  @override
  String get orderSectionCancellation => 'BEKOR QILISH';

  @override
  String get orderCancelledAt => 'Bekor qilingan';

  @override
  String get orderCancelReasonEmpty => 'Sabab ko‘rsatilmagan';

  @override
  String get routeFormCustomPrice => 'Buyurtma narxi';

  @override
  String get routeFormCustomPriceHint => 'Narxlar bo‘yicha';

  @override
  String get routeFormCustomPriceHelper =>
      'Butun buyurtma uchun so‘m, necha kapsula keltirilishidan qat’i nazar. Bo‘sh — narxlar bo‘yicha';

  @override
  String get routeFormCustomPriceInvalid => 'Summa noldan katta bo‘lishi kerak';

  @override
  String get routeFormPickupPriceHint => 'To‘lovsiz';

  @override
  String get routeFormPickupPriceHelper =>
      'Kuler yoki kapsulalarni olib ketish uchun so‘m. Bo‘sh — olib ketish to‘lovsiz';

  @override
  String stopCustomPrice(String amount) {
    return 'Kutilayotgan summa: $amount';
  }

  @override
  String get orderCustomPrice => 'Buyurtma narxi (kelishilgan)';

  @override
  String get completionCustomPrice => 'BUYURTMA NARXI';

  @override
  String get completionCustomPriceCaption =>
      'Butun buyurtma uchun kelishilgan summa — kapsula, brak va qaytarish uni o‘zgartirmaydi';

  @override
  String get completionPickupCustomPriceCaption =>
      'Olib ketish uchun kelishilgan summa — kulerlar, kapsulalar va brak uni o‘zgartirmaydi';

  @override
  String completionByCustomPrice(String amount) {
    return 'Buyurtma narxi bo‘yicha: $amount';
  }
}
