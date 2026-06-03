# Shared Schema Contracts (SSOT)

**Last Updated:** 2026-04-24
**Scope:** Main App, Admin Dashboard, Cloudflare Workers, Firebase Triggers.

This document serves as the absolute Single Source of Truth for shared data formats, state machines, and data architectures between all frontend clients and backend services.

---

## 1. Global Conventions

1. **Dates and Times**: Must be stored as Firestore `Timestamp` objects strictly in UTC. Local timezone formatting is strictly a UI responsibility.
2. **Currency/Money**: Must be stored as `int` representing **minor units** (e.g., Cents/Piasters). Example: `$215.50` is stored as `21550` to avoid decimal floating-point rounding errors.
3. **Strings**: IDs are auto-generated Firebase strings unless otherwise specified by collection contract. Enum values are strictly lowercase strings.
4. **Versioning**: Every core collection document must implicitly implement a `_schemaVersion` integer. Starting version is `1`.

---

## 2. Order Operations (`orders`)

### 2.1 The Order Status State Machine
Orders must strictly follow this linear finite state machine.

| Current Status | Allowed Next Status | Trigger / Notes |
| :--- | :--- | :--- |
| `pending` | `order_processing` | Warehouse accepted the order and started preparation. |
| `pending` | `cancelled` | Rejected by admin, or user requested cancellation before shipping. |
| `order_processing` | `out_for_delivery` | Parcel left warehouse and is with courier. |
| `order_processing` | `cancelled` | Cancelled during processing according to policy. |
| `out_for_delivery` | `delivered` | Courier confirmed physical delivery. |
| `delivered` | *NONE* | Terminal state. |
| `cancelled` | *NONE* | Terminal state. |

*(Note: Refunds or returns are not modelled in this version. If introduced, they will branch from `delivered`.)*

### 2.2 Schema Definitions

```typescript
type OrderStatus =
  | 'pending'
  | 'order_processing'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled';
type EntrySource = 'storefront' | 'admin_dashboard' | 'worker_system';

interface OrderTimelineEntry {
  actorId: string;           // UID of user/admin or 'system'
  actorRole: string;         // 'customer', 'admin', 'system'
  source: EntrySource;
  occurredAt: Timestamp;     // Firestore Timestamp
  note: string;
  fromStatus?: OrderStatus;  // Omitted on creation
  toStatus: OrderStatus;
}

interface OrderAddress {
  recipient: string;
  line1: string;
  city: string;
  region: string;
  country: string;
  postalCode: string;
}

interface OrderProduct {
  sku: string;
  name: string;
  imageUrl: string;
  quantity: number;
  unitPrice: number;         // Int: Minor units (cents)
}

interface Order {
  _schemaVersion: number;    // set to 1
  id: string;
  userId: string;
  customer: {
    name: string;
    email: string;
    phone: string;
    avatarUrl?: string;
    verified: boolean;
  };
  address: OrderAddress;
  totalAmount: number;       // Int: Minor units (cents)
  paymentMethod: string;
  status: OrderStatus;
  products: OrderProduct[];
  timeline: OrderTimelineEntry[];
  orderSource: 'app' | 'ai_chat' | 'restock_alert'; // attribution source for analytics
  attributionMetadata?: {
    // Required when orderSource = 'restock_alert'
    restockRequestId?: string;
  };
  createdAt: Timestamp;
}
```

---

## 3. Product Catalog (`products`)

Products maintain both e-commerce fields and AI-vector mappings for correct matching by the LLM recommendations system.

```typescript
interface Product {
  _schemaVersion: number;    // set to 1
  id: string;
  name: string;
  nameLower: string;
  brand: string;
  
  // E-commerce Core
  price: number;             // Int: Minor units (cents)
  stock: number;
  gender: string;            // 'male', 'female', 'unisex'
  season: string;            // 'summer', 'winter', 'all_season', etc.
  fragranceFamily: string;
  categoryName: string;
  
  // Arrays & UX
  searchPrefixes: string[];
  imageUrls: string[];
  description: string;
  notes: string[];           // Flat mapping for UI
  
  // AI Recommendation Engine Core
  occasion: string;
  time: string;
  intensity: string;
  topNotes: string[];
  middleNotes: string[];
  baseNotes: string[];
  tags: string[];
  pyramidDescription?: string;
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

---

## 4. Inventory Operations (`restock_requests`)

When a product's stock is zero, customers can request notifications. 

```typescript
type RestockStatus = 'pending' | 'notified' | 'converted' | 'cancelled';
type RestockContactMethod = 'email' | 'phone';

interface RestockRequest {
  id: string;                // Document ID
  productId: string;
  userId: string | null;     // Nullable only if guest requests are introduced
  contactMethod: RestockContactMethod;
  contactValue: string;
  status: RestockStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  notifiedAt?: Timestamp | null;
  convertedAt?: Timestamp | null;
  orderId?: string | null;   // set when request is converted into a purchase
  cancelledAt?: Timestamp | null;
  cohortLabel?: 'lost_opportunity' | null;
  lostOpportunityAt?: Timestamp | null;
}
```

Client-side create payload (locked by Firestore Rules) should remain minimal and trusted fields only:

```typescript
interface RestockRequestCreatePayload {
  id: string;
  productId: string;
  userId: string | null;
  contactMethod: RestockContactMethod;
  contactValue: string;
  status: 'pending';
  createdAt: Timestamp;
  updatedAt: Timestamp;
  notifiedAt: null;
}
```

---

## 5. AI Chat Data Contracts (`ai_chat_sessions`, `ai_chat_messages`, `ai_feedback`, `ai_feedback_analysis`)

```typescript
type AiFeedbackScope = 'message' | 'session';
type AiFeedbackAnalysisStatus = 'pending' | 'completed' | 'failed' | 'pending_retry';

interface AIChatSession {
  _schemaVersion: 1;
  id: string;
  userId: string;
  language: string;
  status: 'active' | 'ended';
  startedAt: Timestamp;
  endedAt?: Timestamp | null;
  messageCount: number;
  finalRecommendationMessageId?: string | null;
}

interface AIChatStoredMessage {
  _schemaVersion: 1;
  id: string;
  sessionId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  messageType: 'text' | 'recommendation' | 'availability' | 'loading' | 'error';
  productIds: string[];
  createdAt: Timestamp;
}

interface AIUnifiedFeedback {
  _schemaVersion: 1;
  id: string;               // Suggested: <userId>_<sessionId>_<targetMessageId|session>
  sessionId: string;
  userId: string;
  feedbackScope: AiFeedbackScope;
  targetMessageId?: string | null;
  rating?: number | null;   // Required for session feedback only
  isHelpful: boolean;
  comment?: string | null;
  submittedAt: Timestamp;
  analysisStatus?: AiFeedbackAnalysisStatus | null;
}

interface AIFeedbackAnalysis {
  _schemaVersion: 1;
  id: string;
  sessionId: string;
  feedbackId: string;
  intentUnderstood: boolean;
  needSatisfied: boolean;
  satisfactionScore: number;
  sentiment: 'positive' | 'neutral' | 'negative';
  analysisSummary?: string | null;
  failureReason?: string | null;
  improvementSuggestion?: string | null;
  missingNeeds: string[];
  rawInput: Record<string, unknown>;
  rawModelOutput: Record<string, unknown>;
  analyzedAt: Timestamp;
  status: AiFeedbackAnalysisStatus;
  metadata?: {
    provider: string;
    modelId: string;
    promptVersion: string;
    requestId?: string | null;
  };
}
```

Rules for `ai_feedback`:

- `feedbackScope = 'message'` requires `targetMessageId` and leaves `rating` null.
- `feedbackScope = 'session'` requires `rating` and leaves `targetMessageId` null.
- `analysisStatus` is primarily used for session feedback and may be omitted for message feedback.

`ai_chat_sessions` and `ai_chat_messages` are the official conversation persistence collections.
`ai_feedback_analysis` stores structured background analysis output and audit payloads.

---

## 6. AI Chat Events (`ai_chat_events`)

Telemetry only: this collection remains privacy-safe analytics and must not store transcript persistence or raw model payloads.

```typescript
type AiChatEventType =
  | 'message_sent'
  | 'request_intent_parsing_started'
  | 'request_started'
  | 'request_catalog_cache_hit'
  | 'request_catalog_cache_miss'
  | 'request_model_error'
  | 'ai_worker_hard_timeout'
  | 'request_fallback_local'
  | 'recommendation_shown'
  | 'recommendation_answer_shown'
  | 'availability_answer_shown'
  | 'recommendation_no_match_shown'
  | 'recommendation_clarifying_question_shown'
  | 'recommendation_hard_filter_blocked'
  | 'recommendation_score_fallback_used'
  | 'recommendation_model_fallback_reason'
  | 'answer_grounding_blocked'
  | 'ai_worker_first_path_used'
  | 'ai_mode_switch_changed'
  | 'modifier_patch_applied'
  | 'conversion_upsell_section_shown'
  | 'conversion_upsell_product_rendered'
  | 'conversion_upsell_reason_used'
  | 'conversion_product_clicked'
  | 'conversion_upsell_product_clicked'
  | 'conversion_notify_requested'
  | 'availability_check'
  | 'availability_found'
  | 'availability_not_found_unknown'
  | 'availability_not_found_known_profile'
  | 'availability_ambiguous_name'
  | 'availability_out_of_stock'
  | 'availability_catalog_found'
  | 'availability_profile_catalog_found'
  | 'availability_substitute_shown'
  | 'availability_catalog_out_of_stock_substitute'
  | 'availability_followup_substitute'
  | 'availability_external_unknown_asked'
  | 'availability_found_cheaper_pivot'
  | 'perfume_knowledge_hit'
  | 'perfume_knowledge_miss'
  | 'perfume_knowledge_external_lookup_success'
  | 'perfume_knowledge_external_lookup_failed'
  | 'perfume_knowledge_external_lookup_ambiguous'
  | 'perfume_knowledge_external_candidate_resolved'
  | 'perfume_knowledge_saved_needs_review'
  | 'product_knowledge_catalog_answer'
  | 'feedback_submitted'
  | 'product_click';

interface AiChatEvent {
  eventType: AiChatEventType;
  userId: string;
  sessionId: string;      // Required for session-level privacy-safe analytics
  createdAt: Timestamp;
  metadata: {
    // Privacy-safe scalar fields only. No raw message content is allowed.
    requestId?: string;
    cacheAgeSeconds?: number;
    reason?: string;
    missing_count?: number;
    source?: string;
    messageLength?: number;
    activeCriteriaCount?: number;
    productId?: string;
    fallbackScore?: number;
    answerLength?: number;
    productIds?: string[];
    count?: number;
    sessionId?: string;
    messageId?: string;
    messageType?: string;
    targetMessageId?: string;
    feedbackValue?: string;
    feedbackScope?: string;
    isHelpful?: boolean;
    hasComment?: boolean;
    hasNote?: boolean;
    hasUserId?: boolean;
    issueCode?: string;
    reasonCode?: string;
    detectedIntent?: string;
    hasSufficientCriteria?: boolean;
    isFollowUpOrCompare?: boolean;
    isVague?: boolean;
    language?: string;
    query?: string;
    queryLength?: number;
    matchType?: string;
    stockState?: string;
    matchedProductId?: string;
    referenceProfileKey?: string;
    substituteProductIds?: string[];
    confidenceBucket?: string;
    substituteName?: string;
    outOfStock?: boolean;
    price?: number;
    exactBudget?: boolean;
    productPrice?: number;
    deltaAmount?: number;
    deltaPercent?: number;
    promptVersion?: string;
    provider?: string;
    modelId?: string;
  };
}
```

### System Events (`events`)

```typescript
type SystemEventType =
  | 'restock_notified'
  | 'restock_purchased'
  | 'restock_conversion_success'
  | 'restock_lost_opportunity_marked';

interface SystemEvent {
  id: string;
  userId: string; // admin/user uid or 'system_cron'
  eventType: SystemEventType;
  timestamp: Timestamp;
  data: {
    productId?: string;
    usersNotifiedCount?: number;
    restockRequestId?: string;
    orderId?: string;
    revenue?: number;
    markedCount?: number;
    inspectedCount?: number;
    cutoffHours?: number;
    traceId?: string;
  };
}
```

---

## 7. UI Assets (`banner`, `categories`)

### Banner
```typescript
interface Banner {
  _schemaVersion: number;    // set to 1
  id: string;
  imageUrl: string;
  title: string;
  subtitle?: string;
  targetPath?: string;       // Deep link route (e.g. /product/123)
  queuePosition: number;     // Order of rendering (0 is first)
  isActive: boolean;
  createdAt: Timestamp;
}
```

### Categories
```typescript
interface Category {
  _schemaVersion: number;    // set to 1
  id: string;
  name: string;
  imageUrl?: string;
  queuePosition: number;
  isActive: boolean;
  createdAt: Timestamp;
}
```

---

## 8. Schema Mutation & Security

1. **Clients (Mobile/Web)** cannot explicitly mutate `status` on `Order`. This requires Admin Roles and must pass through Backend API validation (Cloud Functions or Serverless workers) utilizing `AdminSecurityService`.
2. Breaking schema changes: Increment `_schemaVersion` and schedule background workers to backfill existing documents. Old clients must be handled via forced updates or fallback parsers.
