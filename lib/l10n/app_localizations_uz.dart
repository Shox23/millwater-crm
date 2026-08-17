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
  String get commonCancelShort => 'Bekor qilish';

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
  String get errorGeneric => 'So‘rov bajarilmadi.';

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
    return 'Raqam to‘liq emas — +998 dan keyin $count ta raqam kerak';
  }

  @override
  String get fieldEmailInvalid => 'Pochta formati noto‘g‘ri';

  @override
  String get fieldEmailEmpty => 'Elektron pochtani kiriting';

  @override
  String get fieldPasswordEmpty => 'Parolni kiriting';

  @override
  String fieldMinLength(int count) {
    return 'Kamida $count ta belgi';
  }

  @override
  String fieldMaxLength(int count) {
    return '$count ta belgidan ko‘p emas';
  }

  @override
  String get fieldShowPassword => 'Parolni ko‘rsatish';

  @override
  String get fieldHidePassword => 'Parolni yashirish';

  @override
  String get phoneCallUnavailable => 'Qo‘ng‘iroq imkonsiz — raqam nusxalandi';

  @override
  String get phoneCopied => 'Raqam nusxalandi';

  @override
  String get phoneCopy => 'Raqamdan nusxa olish';

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
    return ' · $size KB';
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
  String get paymentCash => 'Naqd';

  @override
  String get paymentCard => 'Karta';

  @override
  String get paymentTransfer => 'Pul o‘tkazma';

  @override
  String get paymentDebt => 'Qarzga';

  @override
  String get periodToday => 'Bugun';

  @override
  String get periodWeek => 'Hafta';

  @override
  String get periodMonth => 'Oy';

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
  String get routeStops => 'MARSHRUT NUQTALARI';

  @override
  String routeStopsCount(int count) {
    return '$count nuqta';
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
    return '$count kapsula';
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
  String get stopTitle => 'Marshrut nuqtasi';

  @override
  String get stopCapsulesDelivered => 'kapsula yetkazildi';

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
  String get driverCreatedAt => 'Yaratilgan sana';

  @override
  String get driverTripsAndToday => '  ·  bugun ';

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
      'Boshlang‘ich parol — haydovchi uni sozlamalarda o‘zgartiradi';

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
  String get customerFormComment => 'Izoh';

  @override
  String get customerFormCommentHint => 'Masalan, tuman yoki mo‘ljal';

  @override
  String get customerFormSaveFailed => 'Mijozni saqlab bo‘lmadi.';

  @override
  String get myRoutesTitle => 'Mening marshrutlarim';

  @override
  String get myRoutesStatRoutes => 'jami marshrut';

  @override
  String get myRoutesStatDeliveredToday => 'bugun yetkazildi';

  @override
  String get myRoutesStatOrders => 'jami buyurtma';

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
  String get completionBalanceCaption =>
      'avvalgi qoldiq o‘rniga shu son yoziladi';

  @override
  String get completionBalanceUnchecked =>
      'Olib kelingan soni qo‘yildi. Mijoz omborini tekshiring — bu qiymat avvalgi qoldiqni almashtiradi.';

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
  String get profileAccountSection => 'HISOB YOZUVI';

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
  String get pricesDeposit => 'Idish garovi';

  @override
  String get pricesDepositHelper => 'So‘m; 0 — garov yo‘q';

  @override
  String pricesDepositRow(String amount) {
    return 'garov $amount';
  }

  @override
  String get pricesEmpty => 'Narxni kiriting';

  @override
  String get pricesZero => 'Kapsula narxi noldan katta bo‘lishi kerak';

  @override
  String get pricesConfirmTitle => 'Yangi narx belgilansinmi?';

  @override
  String pricesConfirmMessage(String capsule, String deposit) {
    return 'Kapsula — $capsule, garov — $deposit.';
  }

  @override
  String get pricesConfirmAction => 'Belgilash';

  @override
  String pricesEffectiveFrom(String date) {
    return '$date dan amal qiladi';
  }

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
}
