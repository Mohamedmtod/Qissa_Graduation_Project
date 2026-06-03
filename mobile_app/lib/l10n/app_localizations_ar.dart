// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get labelQty => 'الكمية';

  @override
  String get appTitle => 'قصة';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get labelWelcomeTitle => 'مرحباً بك في قصة';

  @override
  String get btnLogin => 'تسجيل الدخول';

  @override
  String get btnRegister => 'إنشاء حساب';

  @override
  String get hintEmail => 'البريد الإلكتروني';

  @override
  String get hintPassword => 'كلمة المرور';

  @override
  String get labelLoginWelcome => 'مرحباً بعودتك!\nسجل الدخول إلى حسابك';

  @override
  String get btnForgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get hintFirstName => 'الاسم الأول';

  @override
  String get hintLastName => 'الاسم الأخير';

  @override
  String get msgLoggingIn => 'جاري تسجيل الدخول...';

  @override
  String get msgCreatingAccount => 'جاري إنشاء الحساب...';

  @override
  String get hintConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get labelResetPassword => 'إعادة ضبط كلمة المرور';

  @override
  String get msgResetPasswordInstructions =>
      'أدخل بريدك الإلكتروني لتلقي رابط إعادة تعيين المرور.';

  @override
  String get msgSending => 'جاري الإرسال...';

  @override
  String get btnSendResetLink => 'إرسال رمز التحقق';

  @override
  String get msgResetLinkSent => 'تم إرسال الرابط! تفقد صندوق الوارد.';

  @override
  String get msgResetCodeInstructions =>
      'أدخل بريدك الإلكتروني لتلقي رمز إعادة تعيين مكوّن من 6 أرقام.';

  @override
  String get msgEnterResetCodeInstructions =>
      'أدخل الرمز المرسل إلى بريدك الإلكتروني.';

  @override
  String get msgChooseNewPasswordInstructions => 'اختر كلمة مرور جديدة لحسابك.';

  @override
  String get msgResetCodeSentGeneric =>
      'إذا كان هذا البريد موجودًا، تم إرسال رمز إعادة التعيين.';

  @override
  String get msgInvalidOrExpiredCode => 'الرمز غير صحيح أو انتهت صلاحيته.';

  @override
  String get msgResetCodeSendFailed => 'تعذر إرسال رمز إعادة التعيين حاليًا.';

  @override
  String get hintResetCode => 'رمز من 6 أرقام';

  @override
  String get btnContinue => 'متابعة';

  @override
  String get btnResendCode => 'إعادة إرسال الرمز';

  @override
  String get labelCategories => 'الأقسام';

  @override
  String get hintSearch => 'بحث';

  @override
  String get hintSearchPerfumes => 'البحث عن عطور...';

  @override
  String get labelFlashSale => 'عروض لفترة محدودة';

  @override
  String get btnSeeAll => 'عرض الكل';

  @override
  String get labelViewedBefore => 'شوهدت سابقاً';

  @override
  String get msgViewedBefore => 'تصفح المنتجات التي شاهدتها سابقاً';

  @override
  String get btnHistory => 'السجل';

  @override
  String get labelMyWishlist => 'قائمة أمنياتي';

  @override
  String get msgEmptyWishlist => 'قائمة أمنياتك فارغة';

  @override
  String labelPrice(String price) {
    return '$price ج.م';
  }

  @override
  String get labelInStock => 'متوفر';

  @override
  String get labelOutOfStock => 'غير متوفر';

  @override
  String get labelDescription => 'الوصف';

  @override
  String get msgLoginToAddToCart => 'يرجى تسجيل الدخول لإضافة منتجات للسلة';

  @override
  String get msgLoginToAddToWishlist =>
      'يرجى تسجيل الدخول لإضافة منتجات إلى المفضلة.';

  @override
  String get btnAddToCart => 'أضف للسلة';

  @override
  String get labelFrequentlyBoughtTogether => 'غالباً ما يُشترى معاً';

  @override
  String get msgCustomersAlsoBought =>
      'العملاء الذين اشتروا هذا المنتج فضلوا هذه العطور أيضاً.';

  @override
  String labelConfidence(int percent) {
    return 'ثقة $percent%';
  }

  @override
  String labelLift(String lift) {
    return 'تأثير $lift';
  }

  @override
  String get msgCancelOrderTitle => 'إلغاء الطلب؟';

  @override
  String get msgCancelOrderDesc =>
      'يمكنك إلغاء الطلبات قيد الانتظار فقط. سيتم استرجاع المخزون تلقائياً.';

  @override
  String get btnNo => 'لا';

  @override
  String get btnYesCancel => 'نعم، إلغاء';

  @override
  String msgOrderCancelledSuccess(String id) {
    return 'تم إلغاء الطلب #$id بنجاح.';
  }

  @override
  String get msgNoOrdersYet => 'لا توجد طلبات بعد';

  @override
  String get msgStartShoppingOrders => 'ابدأ التسوق وستظهر\nطلباتك هنا';

  @override
  String get btnBrowseProducts => 'تصفح المنتجات';

  @override
  String get msgSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get btnTryAgain => 'حاول مرة أخرى';

  @override
  String labelOrderNumber(String id) {
    return 'طلب #$id';
  }

  @override
  String get labelNA => 'غير متوفر';

  @override
  String labelReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get labelTotal => 'الإجمالي';

  @override
  String get btnCancelOrder => 'إلغاء الطلب';

  @override
  String get labelStatusOrderProcessing => 'قيد التجهيز';

  @override
  String get labelStatusOutForDelivery => 'في الطريق';

  @override
  String get labelStatusDelivered => 'تم التوصيل';

  @override
  String get msgEmptyCart => 'عربة التسوق فارغة';

  @override
  String get labelOrderSummary => 'ملخص الطلب';

  @override
  String get labelSubtotal => 'المجموع الفرعي';

  @override
  String get labelShippingFee => 'رسوم الشحن';

  @override
  String get labelDiscounts => 'الخصومات';

  @override
  String get btnCheckout => 'الدفع';

  @override
  String get labelHello => 'مرحباً،';

  @override
  String get labelCheckout => 'إتمام الطلب';

  @override
  String get msgFailedToLoadCart => 'فشل في تحميل بيانات السلة';

  @override
  String get msgOrderPlacedAwaitingConfirmation =>
      'تم تأكيد الطلب بنجاح، في انتظار الموافقة النهائية...';

  @override
  String get msgSelectDeliveryAddress => 'اختر عنوان التوصيل';

  @override
  String labelCityStreet(String city, String street) {
    return '$city، $street';
  }

  @override
  String labelBuildingFloor(String building, String floor) {
    return 'مبنى $building، الطابق $floor';
  }

  @override
  String get labelPayWith => 'الدفع باستخدام';

  @override
  String get labelPaymentSummary => 'ملخص الدفع';

  @override
  String get msgPleaseSelectDeliveryAddress =>
      'يرجى اختيار عنوان التوصيل أولاً.';

  @override
  String get btnPlaceOrder => 'تأكيد الطلب';

  @override
  String msgNumOfItems(int count) {
    return '$count عناصر';
  }

  @override
  String get labelOrderPreview => 'معاينة الطلب';

  @override
  String get labelDeliveryInstructions => 'تعليمات التوصيل';

  @override
  String get hintAddDeliveryInstructions => 'أضف تعليمات التوصيل...';

  @override
  String get labelMyOrders => 'طلباتي';

  @override
  String get msgWhereDeliver => 'أين يجب أن نوصل الطلب؟';

  @override
  String get labelPersonalInfo => 'المعلومات الشخصية';

  @override
  String get labelFullName => 'الاسم الكامل';

  @override
  String get hintName => 'الاسم';

  @override
  String get msgNameRequired => 'الاسم مطلوب';

  @override
  String get msgNameNoSymbols => 'الاسم لا يمكن أن يحتوي على رموز أو أرقام.';

  @override
  String get labelPhoneNumber => 'رقم الهاتف';

  @override
  String get hintPhone => '01XXXXXXXXX';

  @override
  String get msgPhoneRequired => 'رقم الهاتف مطلوب';

  @override
  String get msgInvalidPhone => 'أدخل رقم هاتف صحيح';

  @override
  String get labelAddressDetails => 'تفاصيل العنوان';

  @override
  String get labelCity => 'المدينة';

  @override
  String get hintCity => 'المدينة';

  @override
  String get msgCityRequired => 'المدينة مطلوبة';

  @override
  String get labelAreaDistrict => 'المنطقة / الحي';

  @override
  String get hintArea => 'المنطقة';

  @override
  String get msgAreaRequired => 'المنطقة مطلوبة';

  @override
  String get labelStreetDetailed => 'الشارع / العنوان بالتفصيل';

  @override
  String get hintSearchMapOrManual => 'ابحث على الخريطة أو أدخل يدوياً';

  @override
  String get msgAddressDetailsRequired => 'تفاصيل العنوان مطلوبة';

  @override
  String get labelBuilding => 'المبنى';

  @override
  String get hintBuilding => '12';

  @override
  String get labelFloorApt => 'الطابق / الشقة';

  @override
  String get hintFloor => '3';

  @override
  String get labelAdditionalNotes => 'ملاحظات إضافية';

  @override
  String get labelDeliveryNotesOptional => 'ملاحظات التوصيل (اختياري)';

  @override
  String get hintDeliveryNotesEx => 'بجوار المسجد، البوابة الزرقاء...';

  @override
  String get labelSettingsTitle => 'الإعدادات';

  @override
  String get labelSetAsDefaultAddress => 'تعيين كعنوان افتراضي';

  @override
  String get msgSuccess => 'نجاح';

  @override
  String get btnSaveAddress => 'حفظ العنوان';

  @override
  String get btnAddNewAddress => 'إضافة عنوان جديد';

  @override
  String get msgNoSavedAddresses => 'لا توجد عناوين محفوظة.';

  @override
  String get labelDefault => 'افتراضي';

  @override
  String get btnSetAsDefault => 'تعيين كافتراضي';

  @override
  String get titleDeleteAddress => 'حذف العنوان';

  @override
  String get msgConfirmDeleteAddress =>
      'هل أنت متأكد أنك تريد حذف هذا العنوان؟';

  @override
  String get btnCancel => 'إلغاء';

  @override
  String get btnDelete => 'حذف';

  @override
  String get msgManageAndTrack => 'إدارة وتتبع';

  @override
  String msgSavedItems(int count) {
    return '$count عناصر محفوظة';
  }

  @override
  String get labelAvailabilityRequests => 'طلبات التوفر الخاصة بي';

  @override
  String get msgTrackCancelRequests => 'تتبع وإلغاء طلبات الإشعار';

  @override
  String get labelMyAccount => 'حسابي';

  @override
  String get labelAddress => 'العناوين';

  @override
  String get msgManageAddresses => 'إدارة عناوينك';

  @override
  String get labelPaymentMethods => 'تفضيل الدفع';

  @override
  String get msgManagePaymentOptions =>
      'حدد ما إذا كان الدفع بالبطاقة يُختار تلقائياً';

  @override
  String get msgUseCardAsDefault =>
      'اجعل البطاقة الخيار الافتراضي عند إتمام الطلب';

  @override
  String get msgSelectLanguage => 'اختر لغتك المفضلة';

  @override
  String get labelSecurity => 'الأمان';

  @override
  String get msgChangePasswordAndMore => 'تغيير كلمة المرور والمزيد';

  @override
  String get labelSignOut => 'تسجيل الخروج';

  @override
  String get msgLogoutFromAccount => 'تسجيل الخروج من حسابك';

  @override
  String get labelChangePassword => 'تغيير كلمة المرور';

  @override
  String get labelEditProfile => 'تعديل الملف الشخصي';

  @override
  String get msgProfileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get labelFirstName => 'الاسم الأول';

  @override
  String get hintEnterFirstName => 'أدخل الاسم الأول';

  @override
  String get msgRequiredField => 'حقل مطلوب';

  @override
  String get labelLastName => 'اسم العائلة';

  @override
  String get hintEnterLastName => 'أدخل اسم العائلة';

  @override
  String get labelPhoneNumberOptional => 'رقم الهاتف (اختياري)';

  @override
  String get hintEnterPhoneNumber => 'أدخل رقم هاتفك';

  @override
  String get btnSaveChanges => 'حفظ التغييرات';

  @override
  String get msgNewPasswordsDoNotMatch => 'كلمات المرور الجديدة غير متطابقة';

  @override
  String get msgPasswordUpdated => 'تم تحديث كلمة المرور بنجاح';

  @override
  String get labelCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get hintEnterCurrentPassword => 'أدخل كلمة المرور الحالية';

  @override
  String get labelNewPassword => 'كلمة المرور الجديدة';

  @override
  String get hintEnterNewPassword => 'أدخل كلمة المرور الجديدة';

  @override
  String get labelConfirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get hintReenterNewPassword => 'أعد إدخال كلمة المرور الجديدة';

  @override
  String get btnUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get labelCashOnDelivery => 'الدفع عند الاستلام';

  @override
  String get msgDefaultPaymentMethod => 'طريقة الدفع الافتراضية';

  @override
  String get labelDebitCreditCard => 'بطاقة ائتمان / خصم';

  @override
  String get msgAddANewCard => 'إضافة بطاقة جديدة';

  @override
  String get msgPleaseLogInFirst => 'يرجى تسجيل الدخول أولاً';

  @override
  String get msgNeedAccountToTrack => 'تحتاج إلى حساب لتتبع طلبات التوفر.';

  @override
  String get msgCouldNotLoadRequests => 'تعذر تحميل الطلبات';

  @override
  String get msgPleaseTryAgain => 'يرجى المحاولة مرة أخرى بعد قليل.';

  @override
  String get msgNoAvailabilityRequests => 'لا توجد طلبات توفر بعد';

  @override
  String get msgUseNotifyMeButton =>
      'استخدم زر \"أبلغني\" عند نفاذ العنصر من المخزون.';

  @override
  String labelProductId(String id) {
    return 'رقم المنتج: $id';
  }

  @override
  String labelRequestedDate(String date) {
    return 'تم الطلب: $date';
  }

  @override
  String labelNotifiedDate(String date) {
    return 'تم الإشعار: $date';
  }

  @override
  String labelConvertedDate(String date) {
    return 'تم الشراء: $date';
  }

  @override
  String labelCancelledDate(String date) {
    return 'تم الإلغاء: $date';
  }

  @override
  String get btnCancelRequest => 'إلغاء الطلب';

  @override
  String get msgRequestCancelled => 'تم إلغاء الطلب بنجاح.';

  @override
  String get labelStatusPending => 'قيد الانتظار';

  @override
  String get labelStatusNotified => 'تم الإشعار';

  @override
  String get labelStatusPurchased => 'تم الشراء';

  @override
  String get labelStatusCancelled => 'ملغى';

  @override
  String get labelTabAddress => 'العناوين';

  @override
  String get labelTabPickup => 'الاستلام';

  @override
  String get msgPickupContentPlaceholder =>
      'محتوى الاستلام // سيتم إضافته لاحقاً';

  @override
  String labelQuantityFormat(int count) {
    return '×$count';
  }

  @override
  String labelFullAddressStrings(String street, String area, String city) {
    return '$street، $area، $city';
  }

  @override
  String labelFullAddressDetails(
    String city,
    String area,
    String street,
    String building,
    String floor,
  ) {
    return '$city، $area، $street، مبنى $building، الطابق $floor';
  }

  @override
  String get labelDeliverTo => 'التوصيل إلى';

  @override
  String get labelSelectAddress => 'اختر العنوان';

  @override
  String get msgGenericTryAgainLater => 'عذرًا، حاول مرة أخرى لاحقًا.';

  @override
  String get msgNoInternetConnection =>
      'لا يوجد اتصال بالإنترنت. حاول مرة أخرى.';

  @override
  String get msgInvalidEmailOrPassword =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get msgNoUserFoundForEmail =>
      'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get msgInvalidEmailAddress => 'يرجى إدخال بريد إلكتروني صالح.';

  @override
  String get msgTooManyAttempts =>
      'عدد المحاولات كبير جدًا. حاول مرة أخرى لاحقًا.';

  @override
  String get msgAccountAlreadyExists =>
      'يوجد حساب بالفعل بهذا البريد الإلكتروني.';

  @override
  String get msgWeakPassword => 'كلمة المرور ضعيفة جدًا.';

  @override
  String get msgIncorrectCurrentPassword => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get msgAddedToCartSuccessfully => 'تمت إضافة المنتج إلى السلة بنجاح.';

  @override
  String get msgAddToCartFailed => 'تعذر إضافة المنتج إلى السلة حاليًا.';

  @override
  String get msgNotEnoughStockAvailable =>
      'الكمية المطلوبة غير متوفرة بالمخزون.';

  @override
  String msgOnlyItemsAvailable(int count) {
    return 'المتوفر في المخزون $count فقط.';
  }

  @override
  String get msgCartUpdateFailed => 'تعذر تحديث السلة حاليًا.';

  @override
  String get msgWishlistLoadFailed => 'تعذر تحميل المفضلة حاليًا.';

  @override
  String get msgHomeLoadFailed => 'تعذر تحميل الصفحة الرئيسية حاليًا.';

  @override
  String get msgSearchLoadFailed => 'تعذر تحميل نتائج البحث حاليًا.';

  @override
  String get msgProductLoadFailed => 'تعذر تحميل تفاصيل المنتج حاليًا.';

  @override
  String get msgProductNotFound => 'المنتج غير موجود.';

  @override
  String get msgProductUnavailable => 'هذا المنتج لم يعد متاحًا الآن.';

  @override
  String get msgOrderLoadFailed => 'تعذر تحميل طلباتك حاليًا.';

  @override
  String get msgOrderPlaceFailed => 'تعذر إتمام الطلب حاليًا.';

  @override
  String get msgProfileLoadFailed => 'تعذر تحميل الملف الشخصي حاليًا.';

  @override
  String get msgProfileUpdateFailed => 'تعذر تحديث الملف الشخصي حاليًا.';

  @override
  String get msgPasswordUpdateFailed => 'تعذر تحديث كلمة المرور حاليًا.';

  @override
  String get msgAddressSavedSuccessfully => 'تم حفظ العنوان بنجاح.';

  @override
  String get msgAddressSaveFailedGeneric => 'تعذر حفظ العنوان حاليًا.';

  @override
  String get msgCancelRequestFailedGeneric => 'تعذر إلغاء الطلب حاليًا.';

  @override
  String get msgLocationServicesDisabled => 'يرجى تفعيل خدمات الموقع (GPS).';

  @override
  String get msgLocationPermissionDenied => 'تم رفض إذن الوصول إلى الموقع.';

  @override
  String get msgLocationPermissionPermanentlyDenied =>
      'تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من الإعدادات.';

  @override
  String get msgEnableGpsAndPermissions => 'يرجى تفعيل GPS ومنح أذونات الموقع.';

  @override
  String get msgAddressLookupFailed => 'تعذر جلب العنوان لهذا الموقع.';

  @override
  String get labelPickDeliveryLocation => 'اختر موقع التوصيل';

  @override
  String get btnConfirmLocation => 'تأكيد الموقع';

  @override
  String get msgNoProductsFound => 'لم يتم العثور على منتجات.';

  @override
  String get msgNoRecentlyViewedProducts => 'لا توجد منتجات شوهدت مؤخرًا بعد.';

  @override
  String msgNoProductsFoundForCategory(String category) {
    return 'لا توجد منتجات ضمن فئة $category.';
  }

  @override
  String get labelAIChatTitle => 'المساعد الذكي';

  @override
  String get tooltipNewChat => 'محادثة جديدة';

  @override
  String get msgAIChatFeedbackThankYou => 'شكرا على التقييم.';

  @override
  String get msgAIChatPrivacyDisclosure =>
      'يرجى عدم مشاركة أرقام الهاتف أو العناوين أو بيانات الدفع. قد يتم حفظ رسائل المحادثة والتقييمات لتحسين التوصيات ومراجعة الجودة.';

  @override
  String get hintAIChatThinking => 'جاري التفكير...';

  @override
  String hintAIChatCooldown(int seconds) {
    return 'انتظر $seconds ثوانٍ قبل الإرسال مرة أخرى...';
  }

  @override
  String get hintAIChatInput => 'أخبرني عن نوع العطر الذي تريده...';

  @override
  String get labelGenderMen => 'رجالي';

  @override
  String get labelGenderWomen => 'نسائي';

  @override
  String get labelGenderUnisex => 'للجنسين';

  @override
  String labelPrefBudgetUnder(int amount) {
    return 'حتى $amount';
  }

  @override
  String get labelPrefSeason => 'الموسم';

  @override
  String get labelPrefOccasion => 'المناسبة';

  @override
  String get labelPrefTime => 'الوقت';

  @override
  String get labelPrefIntensity => 'الحدة';

  @override
  String get labelPrefNote => 'نفحة';

  @override
  String get labelPrefTopNote => 'افتتاحية';

  @override
  String get labelPrefMiddleNote => 'قلبية';

  @override
  String get labelPrefBaseNote => 'قاعدة';

  @override
  String get labelPrefVibe => 'الطابع';

  @override
  String get labelPrefWithout => 'بدون';

  @override
  String get labelAIChatFeedbackQuestion => 'هل كانت التوصيات مفيدة؟';

  @override
  String get labelFeedbackHelpful => 'مفيد';

  @override
  String get labelFeedbackNotHelpful => 'غير مفيد';

  @override
  String get hintFeedbackNote => 'ملاحظة اختيارية (بدون بيانات شخصية)';

  @override
  String get msgFeedbackSaved => 'تم حفظ تقييمك.';

  @override
  String get labelChatWarning => 'رسالة تنبيهية';

  @override
  String get labelFilterBy => 'تصفية حسب';

  @override
  String get btnApplyFilters => 'تطبيق التصفية';

  @override
  String get labelClearFilters => 'مسح الكل';

  @override
  String get labelGender => 'الجنس';

  @override
  String get labelSeason => 'الموسم';

  @override
  String get labelFragranceFamily => 'عائلة العطر';

  @override
  String get labelComingSoon => 'قريباً';

  @override
  String get labelTestPage => 'صفحة تجريبية';

  @override
  String get labelSoldOut => 'نفدت';

  @override
  String get labelBestSeller => 'الأكثر مبيعاً';

  @override
  String get labelNew => 'جديد';

  @override
  String get msgNotifyMeRequestSaved =>
      'تم تسجيل طلبك، سنقوم بإشعارك فور توفره.';

  @override
  String get labelNotifySaved => 'تم التسجيل';

  @override
  String get btnNotifyMe => 'أعلمني';

  @override
  String get btnDetails => 'التفاصيل';

  @override
  String get labelBehavioralRecommendationsTitle => 'بناءً على ذوقك';

  @override
  String get labelFallbackRecommendationsTitle => 'المنتجات الرئيسية';

  @override
  String get msgAddressAdded => 'تم إضافة العنوان بنجاح';

  @override
  String get msgAddressUpdated => 'تم تحديث العنوان بنجاح';

  @override
  String get msgAddressDeleted => 'تم حذف العنوان بنجاح';

  @override
  String get msgDefaultAddressUpdated => 'تم تحديث العنوان الافتراضي';

  @override
  String get labelOptionSummer => 'صيفي';

  @override
  String get labelOptionWinter => 'شتوي';

  @override
  String get labelOptionSpring => 'ربيعي';

  @override
  String get labelOptionAutumn => 'خريفي';

  @override
  String get labelOptionAllSeason => 'كل الفصول';

  @override
  String get labelOptionFloral => 'زهري';

  @override
  String get labelOptionWoody => 'خشبي';

  @override
  String get labelOptionOriental => 'شرقي';

  @override
  String get labelOptionFresh => 'منعش';

  @override
  String get labelOptionCitrus => 'حمضيات';

  @override
  String get categoryPerfumes => 'عطور';

  @override
  String get categoryBokhoor => 'بخور';

  @override
  String get categoryMabkhara => 'مباخر';

  @override
  String get categoryFawa7a => 'فواحات';

  @override
  String get categoryWatches => 'ساعات';

  @override
  String get categorySunglasses => 'نظارات';

  @override
  String get labelNavHome => 'الرئيسية';

  @override
  String get labelNavCategories => 'الأقسام';

  @override
  String get labelNavAI => 'المساعد';

  @override
  String get labelNavCart => 'السلة';

  @override
  String get labelNavProfile => 'حسابي';

  @override
  String get labelOrderSuccessful => 'تم تأكيد الطلب بنجاح!';

  @override
  String get msgOrderProcessingAssurance =>
      'لقد استلمنا طلبك ونقوم بتجهيزه الآن.';

  @override
  String get btnTrackOrder => 'تتبع الطلب';

  @override
  String get btnContinueShopping => 'الاستمرار في التسوق';

  @override
  String get msgCartCleanupWarning =>
      'تم استلام طلبك بنجاح، لكن تعذر تحديث السلة حالياً.';

  @override
  String get labelFragranceFamiliesTitle => 'عائلات\nالعطور';

  @override
  String get labelUnsureWhereToBegin => 'محتار تبدأ منين؟';

  @override
  String get msgAiAssistantHelp =>
      'مساعدنا الذكي هيساعدك تلاقي العطر المناسب ليك!';

  @override
  String get btnStartChatting => 'ابدأ المحادثة';

  @override
  String get descFloral => 'بتلات وزهور';

  @override
  String get labelOptionFruity => 'فواكه';

  @override
  String get descFruity => 'مشرق ومنعش';

  @override
  String get descOriental => 'توابل وعنبر';

  @override
  String get descWoody => 'خشب الأرز\nوالصندل';

  @override
  String get descFresh => 'حمضيات ومنعش';

  @override
  String get labelOptionGourmand => 'حلويات';

  @override
  String get descGourmand => 'كراميل وقهوة';

  @override
  String get labelOptionLeather => 'جلود';

  @override
  String get descLeather => 'نوتات دخانية';

  @override
  String get labelOptionOud => 'عود';

  @override
  String get descOud => 'عود غني ودخان';

  @override
  String get btnEdit => 'تعديل';

  @override
  String get msgDeliveryZoneUnavailable =>
      'عذراً، لا نوصل لهذا العنوان حالياً.';

  @override
  String get addressGovernorate => 'المحافظة';

  @override
  String get addressSelectGovernorate => 'اختر المحافظة';

  @override
  String get addressErrGovernorateRequired => 'المحافظة مطلوبة';

  @override
  String get btnRequestAccountDeletion => 'طلب حذف الحساب';

  @override
  String get securityDeleteAccountSubtitle =>
      'إرسال طلب آمن للمراجعة من الإدارة';

  @override
  String get securityDeleteAccountDialogTitle => 'هل تريد طلب حذف الحساب؟';

  @override
  String get securityDeleteAccountDialogBody =>
      'سيتم إرسال الطلب إلى فريق الإدارة للمراجعة.';

  @override
  String get btnSubmitRequest => 'إرسال الطلب';

  @override
  String get msgAccountDeletionSubmitted => 'تم إرسال طلب حذف الحساب.';

  @override
  String get orderNumber => 'رقم الطلب';

  @override
  String get btnCopyID => 'نسخ الرقم';

  @override
  String get msgOrderNumberCopied => 'تم نسخ رقم الطلب';

  @override
  String get loginWelcomeBack => 'مرحباً بعودتك!';

  @override
  String get loginSubtitle => 'تسجيل الدخول إلى حسابك';

  @override
  String get btnCreateAccount => 'إنشاء حساب';

  @override
  String get welcomeExploreProducts => 'استكشف المنتجات';

  @override
  String get btnRemoveFromCart => 'إزالة من السلة';

  @override
  String get btnReset => 'إعادة تعيين';

  @override
  String get filterMen => 'رجال';

  @override
  String get filterWomen => 'نساء';

  @override
  String get filterUnisex => 'للجنسين';

  @override
  String get seasonSummer => 'صيفي';

  @override
  String get seasonWinter => 'شتوي';

  @override
  String get seasonSpring => 'ربيعي';

  @override
  String get seasonAutumn => 'خريفي';

  @override
  String get seasonAllSeason => 'كل الفصول';

  @override
  String get scentFloral => 'زهري';

  @override
  String get scentWoody => 'خشبي';

  @override
  String get scentOriental => 'شرقي';

  @override
  String get scentFresh => 'منعش';

  @override
  String get scentCitrus => 'حمضيات';

  @override
  String get scentFruity => 'فاكهي';

  @override
  String get scentGourmand => 'سكري';

  @override
  String get scentLeather => 'جلدي';

  @override
  String get msgDontHaveAccount => 'ليس لديك حساب؟ ';

  @override
  String get msgAlreadyHaveAccount => 'لديك حساب بالفعل؟ ';
}
