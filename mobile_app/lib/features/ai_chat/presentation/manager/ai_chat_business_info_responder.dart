import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';

typedef AIChatBusinessInfoTranslator =
    String Function(
      AIChatLanguage language, {
      required String ar,
      required String en,
    });

class AIChatBusinessInfoResponder {
  const AIChatBusinessInfoResponder({
    required AIChatBusinessInfoTranslator translate,
  }) : _translate = translate;

  final AIChatBusinessInfoTranslator _translate;

  bool looksLikeBlockedFollowUp(String normalized) {
    if (normalized.isEmpty) return false;
    if (looksLikeAvailabilityFollowUp(normalized) ||
        looksLikeContextualAvailabilityFollowUp(normalized)) {
      return true;
    }
    return normalized.contains('if not') ||
        normalized.contains('recommend') ||
        normalized.contains('suggest') ||
        normalized.contains('closest') ||
        normalized.contains('similar') ||
        normalized.contains('alternative') ||
        normalized.contains('بديل') ||
        normalized.contains('شبه') ||
        normalized.contains('رشح') ||
        normalized.contains('اقترح');
  }

  String? requestType(String normalized) {
    if (normalized.isEmpty) return null;
    final asksAddress =
        normalized.contains('address') ||
        normalized.contains('location') ||
        normalized.contains('where are you') ||
        normalized.contains('where is your store') ||
        normalized.contains('where is the store') ||
        normalized.contains('العنوان') ||
        normalized.contains('عنوانكم') ||
        normalized.contains('مكانكم') ||
        normalized.contains('فين المحل') ||
        normalized.contains('المحل فين');
    if (asksAddress) return 'address';

    final asksContact =
        _containsEnglishWord(normalized, 'contact') ||
        _containsEnglishWord(normalized, 'phone') ||
        _containsEnglishWord(normalized, 'whatsapp') ||
        normalized.contains('call you') ||
        normalized.contains('call us') ||
        _containsEnglishWord(normalized, 'number') ||
        normalized.contains('اتواصل') ||
        normalized.contains('رقمكم') ||
        normalized.contains('رقم') ||
        normalized.contains('واتساب') ||
        normalized.contains('تليفون') ||
        normalized.contains('موبايل');
    if (asksContact) return 'contact';

    final asksDiscount =
        normalized.contains('discount') ||
        normalized.contains('coupon') ||
        normalized.contains('promo') ||
        normalized.contains('promotion') ||
        normalized.contains('voucher') ||
        normalized.contains('offer code') ||
        normalized.contains('sale code') ||
        normalized.contains('خصم') ||
        normalized.contains('كود خصم') ||
        normalized.contains('كوبون') ||
        normalized.contains('برومو') ||
        normalized.contains('عروض');
    if (asksDiscount) return 'discount';

    final asksHours =
        normalized.contains('opening hours') ||
        normalized.contains('working hours') ||
        normalized.contains('what time') ||
        normalized.contains('what time do you open') ||
        normalized.contains('when do you open') ||
        normalized.contains('when are you open') ||
        normalized.contains('are you open') ||
        normalized.contains('store open') ||
        normalized.contains('shop open') ||
        normalized.contains('open now') ||
        normalized.contains('close time') ||
        normalized.contains('closing time') ||
        normalized.contains('مواعيد') ||
        normalized.contains('بتفتحوا') ||
        normalized.contains('بتقفلوا') ||
        normalized.contains('فاتحين') ||
        normalized.contains('المحل مفتوح') ||
        normalized.contains('انتم مفتوحين') ||
        normalized.contains('انتو مفتوحين') ||
        normalized.contains('مفتوحين دلوقتي');
    if (asksHours) return 'hours';

    if (_looksLikeBlindBuyingAdvice(normalized)) return null;

    final asksPayment =
        normalized.contains('payment') ||
        normalized.contains('pay') ||
        normalized.contains('payment method') ||
        normalized.contains('payment methods') ||
        normalized.contains('cash on delivery') ||
        normalized.contains('card') ||
        normalized.contains('visa') ||
        normalized.contains('mastercard') ||
        normalized.contains('\u0627\u0644\u062f\u0641\u0639') ||
        normalized.contains(
          '\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639',
        ) ||
        normalized.contains(
          '\u0637\u0631\u0642 \u0627\u0644\u062f\u0641\u0639',
        ) ||
        normalized.contains('\u0623\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains('\u0627\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains(
          '\u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645',
        ) ||
        normalized.contains('طريقة الدفع') ||
        normalized.contains('طرق الدفع') ||
        normalized.contains('وسائل الدفع') ||
        normalized.contains('وسيلة الدفع') ||
        normalized.contains('الدفع المتاح') ||
        normalized.contains('الدفع عند الاستلام') ||
        normalized.contains('دفع عند الاستلام') ||
        normalized.contains('دفع الاستلام') ||
        normalized.contains('الدفع وقت الاستلام') ||
        normalized.contains('دفع وقت الاستلام') ||
        normalized.contains('كاش عند الاستلام') ||
        normalized.contains('ادفع') ||
        normalized.contains('كاش') ||
        normalized.contains('فيزا');
    if (asksPayment) return 'payment';

    final asksDelivery =
        normalized.contains('delivery') ||
        normalized.contains('shipping') ||
        normalized.contains('deliver') ||
        normalized.contains('\u0627\u0644\u062a\u0648\u0635\u064a\u0644') ||
        normalized.contains('\u062a\u0648\u0635\u064a\u0644') ||
        normalized.contains('\u0627\u0644\u0634\u062d\u0646') ||
        normalized.contains('\u0634\u062d\u0646') ||
        normalized.contains('توصيل') ||
        normalized.contains('شحن') ||
        normalized.contains('دليفري');
    if (asksDelivery) return 'delivery';

    final asksAuthenticity =
        normalized.contains('authentic') ||
        normalized.contains('original') ||
        normalized.contains('genuine') ||
        normalized.contains('\u0623\u0635\u0644\u064a') ||
        normalized.contains('\u0627\u0635\u0644\u064a') ||
        normalized.contains('\u0623\u0635\u0644\u064a\u0629') ||
        normalized.contains('\u0627\u0635\u0644\u064a\u0629') ||
        normalized.contains('\u0623\u0635\u0644\u064a\u064a\u0646') ||
        normalized.contains('\u0627\u0635\u0644\u064a\u064a\u0646');
    if (asksAuthenticity) return 'authenticity';

    return null;
  }

  String buildAnswer(
    AIChatBusinessInfo? info, {
    required String request,
    required AIChatLanguage language,
  }) {
    if (request == 'discount') {
      return _buildDiscountPolicyAnswer(language);
    }
    if (info == null || !info.hasAnyPublicInfo) {
      if (request == 'payment') {
        return _buildPaymentMethodsAnswer(language);
      }
      if (request == 'contact') {
        return _buildUnavailableContactAnswer(language);
      }
      if (request == 'authenticity') {
        return _buildAuthenticityAnswer(language);
      }
      return _translate(
        language,
        ar: 'معلومات المتجر غير متاحة حاليًا داخل التطبيق. جرّب مرة أخرى لاحقًا أو تواصل معنا من صفحة المتجر.',
        en: 'Store information is not available in the app right now. Please try again later or use the store contact page.',
      );
    }

    final isArabic = language.isArabic;
    final lines = <String>[];
    final storeName = info.storeName.isNotEmpty ? info.storeName : 'Qissa';

    String localized(String ar, String en) {
      if (isArabic) return ar.trim().isNotEmpty ? ar.trim() : en.trim();
      return en.trim().isNotEmpty ? en.trim() : ar.trim();
    }

    void add(String labelAr, String labelEn, String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      lines.add('${isArabic ? labelAr : labelEn}: $normalized');
    }

    if (request == 'address') {
      add('العنوان', 'Address', localized(info.addressAr, info.addressEn));
    } else if (request == 'contact') {
      add('رقم الهاتف', 'Phone', info.phone);
      add('واتساب', 'WhatsApp', info.whatsapp);
      add('إنستجرام', 'Instagram', info.instagramUrl);
      add('فيسبوك', 'Facebook', info.facebookUrl);
      add('الموقع', 'Website', info.websiteUrl);
    } else if (request == 'hours') {
      add(
        'المواعيد',
        'Opening hours',
        localized(info.openingHoursAr, info.openingHoursEn),
      );
    } else if (request == 'delivery') {
      add(
        'التوصيل',
        'Delivery',
        localized(info.deliveryInfoAr, info.deliveryInfoEn),
      );
    } else if (request == 'payment') {
      return _buildPaymentMethodsAnswer(language);
    } else if (request == 'authenticity') {
      return _buildAuthenticityAnswer(language);
    }

    if (lines.isEmpty && info.hasContact) {
      add('رقم الهاتف', 'Phone', info.phone);
      add('واتساب', 'WhatsApp', info.whatsapp);
      add('إنستجرام', 'Instagram', info.instagramUrl);
      add('فيسبوك', 'Facebook', info.facebookUrl);
      add('الموقع', 'Website', info.websiteUrl);
    }
    if (lines.isEmpty) {
      if (request == 'contact') {
        return _buildUnavailableContactAnswer(language);
      }
      return _translate(
        language,
        ar: 'المعلومة المطلوبة غير منشورة حاليًا لـ $storeName داخل التطبيق.',
        en: 'That store detail is not published for $storeName in the app yet.',
      );
    }
    return lines.join('\n');
  }

  bool _containsEnglishWord(String normalized, String word) {
    return RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  bool _looksLikeBlindBuyingAdvice(String normalized) {
    final online =
        normalized.contains('online') ||
        normalized.contains('\u0623\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains('\u0627\u0648\u0646\u0644\u0627\u064a\u0646');
    final blind =
        normalized.contains('blind buy') ||
        normalized.contains('without smelling') ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u0645\u0627 \u0623\u0634\u0645',
        ) ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u0645\u0627 \u0627\u0634\u0645',
        );
    final choosing =
        normalized.contains('choose') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0625\u0632\u0627\u064a') ||
        normalized.contains('\u0627\u0632\u0627\u064a');
    return online && (blind || choosing);
  }

  String _buildPaymentMethodsAnswer(AIChatLanguage language) {
    return _translate(
      language,
      ar: 'وسيلة الدفع المتاحة حاليًا هي الدفع عند الاستلام. لو أضفت منتجات للسلة، تقدر تكمل الطلب من صفحة السلة وتختار الدفع عند الاستلام.',
      en: 'The currently available payment method is cash on delivery. After adding products to the cart, you can complete checkout from the cart page and use cash on delivery.',
    );
  }

  String _buildAuthenticityAnswer(AIChatLanguage language) {
    return _translate(
      language,
      ar: '\u0627\u0644\u0639\u0637\u0648\u0631 \u0627\u0644\u0645\u0639\u0631\u0648\u0636\u0629 \u062f\u0627\u062e\u0644 \u0627\u0644\u062a\u0637\u0628\u064a\u0642 \u0645\u0646 \u0643\u062a\u0627\u0644\u0648\u062c Qissa. \u0644\u0623\u064a \u062a\u0623\u0643\u064a\u062f \u062e\u0627\u0635 \u0628\u0627\u0644\u0623\u0635\u0627\u0644\u0629 \u0623\u0648 \u0627\u0644\u062a\u0648\u0631\u064a\u062f\u060c \u0631\u0627\u062c\u0639 \u062a\u0641\u0627\u0635\u064a\u0644 \u0627\u0644\u0645\u0646\u062a\u062c \u0623\u0648 \u062e\u062f\u0645\u0629 \u0627\u0644\u0639\u0645\u0644\u0627\u0621.',
      en: 'The perfumes shown in the app come from the Qissa catalog. For any specific authenticity or sourcing confirmation, check the product details or contact customer support.',
    );
  }

  String _buildUnavailableContactAnswer(AIChatLanguage language) {
    return _translate(
      language,
      ar: 'مش متاح عندي رقم تواصل مؤكد داخل الشات. تقدر تستخدم صفحة التواصل في التطبيق.',
      en: 'I do not have a confirmed contact number inside chat. Please use the store contact page in the app.',
    );
  }

  String _buildDiscountPolicyAnswer(AIChatLanguage language) {
    return _translate(
      language,
      ar: 'مش متاح عندي خصم أو كود خصم مؤكد داخل الشات. أي عروض مؤكدة هتظهر على المنتج أو في صفحة السلة.',
      en: 'I do not have a confirmed discount code inside chat. Any confirmed offers will appear on the product page or in the cart.',
    );
  }
}
