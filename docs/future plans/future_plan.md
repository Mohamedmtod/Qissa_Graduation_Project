# AI Chat Future Plan - خريطة طريق تطوير الذكاء الاصطناعي

هذه الوثيقة تحتوي على ترتيب وتنظيم الأفكار المستقبلية لتطوير نظام AI Chat في مشروع قصة (Qissa)، مقسمة إلى مراحل (Phases) قابلة للتنفيذ تدريجياً لضمان استقرار النظام.

## المرحلة الأولى: الأساس المعماري وتصحيح المسار (Foundation & Architecture)
**الهدف:** تحويل النظام إلى نظام مرن وموثوق، يعتمد على الـ LLM بشكل أساسي للفهم العميق، وعلى الـ Local للتنفيذ الحتمي السريع فقط.

- **Deterministic Local Gate**: إلغاء فكرة الـ Local Classifier اللغوي، واستبداله ببوابة حتمية (Deterministic Gate). الـ Local لا يخمن، بل ينفذ فقط الأوامر الواضحة بنسبة 100% (مثل الرد على Clarification، الاستعلام المباشر من الكتالوج، وأسئلة البزنس الواضحة).
- **LLM Semantic Router by Default**: أي رسالة تحتوي على لغة طبيعية أو غير واضحة تماماً تذهب مباشرة إلى الـ LLM لتصنيف النية (Intent) واختيار الـ Tool المناسبة.
- **Code Cleanliness & Ownership**:
  - كتابة ملف `ownership.md` لتحديد مسؤولية كل ملف بدقة (Cubit, Executor, Guards, Resolvers) لمنع تداخل الصلاحيات.
  - كتابة قرارات البنية التحتية في ملفات ADR (Architecture Decision Records).
  - توحيد سجل الأدوات (Tool Registry) بين بيئات العمل المختلفة.

## المرحلة الثانية: المراقبة والتحليلات الآمنة (Observability & Safe Analytics)
**الهدف:** معرفة ما يحدث داخل النظام بدقة (Debugging & Monitoring) دون انتهاك خصوصية المستخدم أو تخزين نصوص غير ضرورية.

- **Structured Event Logging**: بناء نظام تسجيل أحداث منظم (مثل `AIChatAnalyticsEvent`) يسجل كل خطوة في المحادثة (الـ route, tool used, latency, success/fail, confidence).
- **Safe Logging**: إيقاف تسجيل الرسائل النصية الخام (Raw Messages) للمستخدمين. يتم تخزين الـ Metadata، أو الـ Semantic Labels، أو نصوص منقحة (Redacted Text) فقط.
- **Question Type Taxonomy**: تقسيم رسائل المستخدمين إلى فئات واضحة (مثل: recommendation, availability, cheaper_followup, external_perfume_reference) لفهم نوعية الأسئلة التي تهم العملاء.

## المرحلة الثالثة: التقييم واكتشاف الأنماط (Feedback & Pattern Mining)
**الهدف:** تحسين جودة الترشيحات بناءً على تفضيلات العملاء الحقيقية وتقليل التكلفة بذكاء.

- **Feedback Loop**: إضافة نظام تقييم بسيط للمستخدم بعد كل ترشيح (👍/👎) مع خيارات توضح سبب الرفض (مثل: ثقيل، غالي، ليس نفس الطابع).
- **Pattern Mining System**: بناء سكربت أو وظيفة دورية (مبدئياً كل أسبوع) تستخرج أكثر الأنماط المتكررة (Patterns) والأسئلة غير المعروفة.
- **Local Shortcut System**: بناء نظام يقترح تحويل الأسئلة المتكررة جداً والمضمونة إلى Local Rules (Shortcuts) لتوفير استدعاءات الـ Worker، وذلك بعد مراجعة يدوية للبيانات.

## المرحلة الرابعة: التشغيل، الصيانة، والتحكم (Operations & Maintenance)
**الهدف:** ضمان استقرار النظام في بيئة الإنتاج (Production) وتسهيل متابعته من قبل فريق الإدارة.

- **AI Chat Health Dashboard**: إنشاء لوحة تحكم مصغرة (داخل الـ Admin Dashboard) لعرض إحصائيات النظام (نسبة استخدام الـ Tools، حالات الفشل Timeout/Fallback، والمنتجات الأكثر ترشيحاً ورفضاً).
- **Testing Matrix**: تعزيز استراتيجية الاختبارات (Unit, Flow, E2E) لتشمل مسارات التوصية، وأدوات الـ Worker، وحالات الفشل (Fallback).
- **Incident Playbook & Release Checklist**: 
  - إعداد قائمة تحقق (Checklist) واضحة قبل كل عملية رفع (Deploy) للـ Production.
  - إعداد دليل أزمات (Playbook) يوضح خطوات التعامل الفوري في حال حدوث مشاكل (مثل: Worker timeout عالي، أو ترشيحات عشوائية خاطئة).
- **Cost Metrics**: مراقبة تكلفة الـ Worker والاستهلاك التقريبي للـ (Tokens) ومعدل التوفير الناتج عن الـ Local Shortcuts.

---

## كيف نبدأ؟ (التنفيذ التدريجي - Migration Plan)
لا يجب تنفيذ كل شيء دفعة واحدة، و**يمنع تماماً تغيير هيكل الـ Routing قبل إرساء المراقبة (Observability)**. البداية المثالية يجب أن تكون على شكل انتقال تدريجي (Migration) كالتالي:

1. **PR13A - Observability Foundation**: تأسيس نظام الـ Structured Logging وتتبع الأحداث. **(ممنوع تماماً تغيير الـ Routing أو الـ UI أو سلوك النظام - No Behavior Change)**. الهدف الوحيد هو بناء خط أساس (Baseline) لتتبع الأداء وجمع البيانات.
2. **PR13B - Deterministic Local Gate Shadow Mode**: بناء البوابة الحتمية الجديدة، ولكنها تعمل في "وضع الظل". تسجل قراراتها في الـ Analytics لغرض المقارنة، ولكن القرار الفعلي الذي ينفذ يظل تابعاً للـ Routing القديم. 
3. **PR13C - Gate Activation Behind Flag**: تفعيل البوابة الحتمية الجديدة فعلياً، ولكن خلف Feature Flag (مثل `AI_CHAT_DETERMINISTIC_GATE_V1=true`)، للتأكد من استقرارها.
4. **PR13D - Documentation**: كتابة ملفات التوثيق الهامة مثل `ownership.md` و `routing_policy.md` للحفاظ على نظافة الكود.

هذا الترتيب المنهجي (راقب أولاً -> قارن في الظل -> فعّل تدريجياً -> اجمع الأنماط لاحقاً) يضمن عدم كسر تجربة المستخدم ويجعل عملية تتبع الأخطاء (Debugging) أسهل وأكثر دقة.

---

## تقنيات وأساليب التنفيذ (Implementation Techniques)
لضمان تنفيذ الخطة بشكل احترافي وبدون مخاطر، يجب الالتزام بالتكنيكات التالية في الكود:

### 1. استخدام الـ Feature Flags
يجب وضع كل تغيير جديد خلف راية (Flag) يمكن التحكم بها، لتسهيل عملية التراجع السريع (Rollback) عند الطوارئ:
- `AI_CHAT_ANALYTICS_EVENTS_ENABLED`
- `AI_CHAT_ANALYTICS_REMOTE_SINK_ENABLED`
- `AI_CHAT_DETERMINISTIC_GATE_V1`
- `AI_CHAT_GATE_SHADOW_MODE`
- `AI_CHAT_PATTERN_LOGGING_ENABLED`

### 2. التتبع المركزي للأحداث (Centralized Event Tracking)
تجنب تشتيت أكواد التتبع في ملفات كثيرة. بدلاً من ذلك، قم ببناء Service مركزية (مثال: `AIChatAnalyticsTracker`)، بحيث يقوم الـ Cubit أو الـ Router بمناداتها في نقاط محددة. وتعمل هذه الخدمة من خلال واجهة `AIChatAnalyticsSink` (تبدأ بـ `DebugConsoleAnalyticsSink` محلياً قبل التفكير في قواعد بيانات خارجية).

### 3. الحجب الافتراضي للبيانات الحساسة (Redaction by default)
يُمنع منعاً باتاً تسجيل نصوص المستخدمين الخام (Raw Messages) أو الـ Prompts الكاملة، حتى في بيئة الـ Debugging. يجب أن يحتوي الـ Event على الـ Metadata فقط (مثل: طول الرسالة، الـ Route، الـ Tool، وحالة النجاح أو الفشل). وإن لزم الأمر لفهم النمط يُستخدم نص منقح (Redacted).

### 4. مراجعة الاقتراحات يدوياً (Shortcut Approval Workflow)
لا تدع النظام يضيف قواعد (Local Shortcuts) بشكل تلقائي مهما تكرر النمط. دورة العمل الصحيحة هي: 
**اكتشاف النمط (Pattern) -> توليد اقتراح -> مراجعة بشرية -> إضافة الاختصار يدوياً -> كتابة Test -> تفعيل**.

### 5. أمان الـ Worker (Fallback Safety)
رغم أن الـ LLM سيكون هو المسار الافتراضي لفهم الجمل، يجب بناء نظام حماية في حال توقف الـ Worker عن العمل (Timeout) لضمان عدم انهيار تجربة المستخدم، عبر الاعتماد على Local Fallback يوضح المشكلة بأدب أو يسأل أسئلة توضيحية.

### 6. اختبارات الصلاحية والمراقبة (Contract & Observability Tests)
قبل رفع أي تعديل (PR)، يجب كتابة واجتياز الاختبارات التالية:
- **Observability Tests:** التأكد من أن الحدث (Event) لا يحمل نصوصاً خام، وأنه يسجل اسم الـ Tool والمسار بدقة.
- **Deterministic Gate Tests:** التأكد من أن الأوامر القطعية (مثل: طرق الدفع، رقم 1) يمسكها الـ Local، وأن الأسئلة المبنية على المشاعر أو السياق الغامض تُرسل دائماً للـ LLM.
- **Shadow Gate Tests:** ضمان أن قرار الـ Gate الجديد أثناء عمله في "وضع الظل" لا يؤثر نهائياً على الرد الذي يراه المستخدم.

---

## تفاصيل التنفيذ التقني لكل مرحلة (Implementation Details)

### أولاً: PR13A — Observability Foundation
- **نطاق العمل (Scope):** بناء الأساس بدون تغيير سلوك النظام. **(No Behavior Change)**.
- **مكونات الـ Event Schema (`AIChatAnalyticsEvent`):**
  يجب أن يحتوي على: `eventType`, `requestId`, `sessionIdHash`, `timestamp`, `language`, `messageLength`, `route`, `action`, `source`, `questionType`, `toolName`, `renderIntent`, `workerUsed`, `fallbackUsed`, `workerLatencyMs`, `productCount`, `finalProductIds`, `clarificationType`, `noMatchReason`, `failureReason`.
  **ممنوع تماماً تسجيل:** `rawUserMessage`, `fullPrompt`, أو أي بيانات شخصية للعميل أو `secrets`.
- **أنواع الأحداث المطلوبة للبدء (Event Types):**
  التركيز على 5 أحداث فقط في البداية: `turn_completed`, `tool_executed`, `fallback_used`, `clarification_asked`, `no_match`.
- **أين يتم التخزين (Analytics Sinks):**
  العمل مؤقتاً محلياً عبر `DebugConsoleAnalyticsSink` و `NoopAnalyticsSink` وعدم تفعيل أي إرسال خارجي للـ Remote Sink في البداية.

### ثانياً: PR13B — Deterministic Local Gate Shadow Mode
- **الهدف:** اختبار الـ Gate الجديد في "وضع الظل" (Shadow Mode) للمقارنة.
- **عناصر المقارنة الواجب تسجيلها في الحدث (`local_gate_shadow_decision`):**
  `oldRoute`, `oldAction`, `shadowGateResult`, `shadowGateRoute`, `shadowGateProofReasons`, `wouldSendToLlm`.
- **النتيجة المطلوبة:** التأكد من أن قرار وضع الظل لن يغير الرد الفعلي للمستخدم.

### ثالثاً: PR13C — Gate Activation Behind Flag
- **الهدف:** تفعيل الـ Gate الجديد خلف الراية `AI_CHAT_DETERMINISTIC_GATE_V1`.
- **الأساس:** إذا أعطت الـ Gate النتيجة `handled` يتم تنفيذ الـ Local، وإذا كانت `notHandled` يرسل السؤال إلى الـ `semantic_router` (الـ LLM).
- **الحماية:** التأكد من وجود `Fallback` آمن للـ Worker في حال الفشل لتجنب الترشيحات العشوائية.
