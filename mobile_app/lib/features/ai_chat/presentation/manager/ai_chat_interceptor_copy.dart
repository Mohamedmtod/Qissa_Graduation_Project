import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_input_interceptor.dart';

String buildInterceptedClarificationMessage(
  AIChatInterceptResult intercepted,
  AIChatLanguage language,
) {
  switch (intercepted.kind) {
    case AIChatInterceptKind.fantasyNoteLike:
      return language.isArabic
          ? 'هذا الطابع غير موجود ضمن العطور المتاحة لدينا. إذا أحببت، أقدر أرشح لك أقرب عائلة عطرية واقعية بدل ذلك.'
          : 'That scent style is not realistically available in our catalog. If you want, I can suggest the closest real fragrance family instead.';
    case AIChatInterceptKind.contradictionLike:
      return language.isArabic
          ? 'في الطلب تعارض بسيط: هل تفضّل أن يكون العطر هادئًا وقريبًا، أم قويًا ولافتًا أكثر؟'
          : 'There is a small contradiction in the request. Which matters more to you: a softer close-to-skin scent or a stronger room-filling one?';
    case AIChatInterceptKind.gibberishLike:
      return language.isArabic
          ? 'لم أفهم طلبك بشكل كافٍ. اكتب لي مثلًا النوع أو النوتات أو الميزانية وسأساعدك فورًا.'
          : 'I could not understand your request clearly. Tell me the type, notes, or budget you want and I will help right away.';
    case AIChatInterceptKind.luxuryBudgetMismatch:
      return language.isArabic
          ? 'الطابع الفاخر جدًا بهذه الميزانية غير واقعي حاليًا. إذا أحببت، أقدر أرشح لك أقرب خيار أنيق ضمن ميزانية أعلى قليلًا أو أفضل خيار اقتصادي متاح.'
          : 'That luxury level is not realistic at this budget right now. If you want, I can suggest the closest elegant option at a slightly higher budget or the best affordable alternative.';
  }
}
