CREATE TABLE IF NOT EXISTS ai_chat_debug_sessions (
  chat_debug_id TEXT PRIMARY KEY,
  session_id_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_turn_at TEXT,
  turn_count INTEGER NOT NULL DEFAULT 0,
  has_negative_feedback INTEGER NOT NULL DEFAULT 0,
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_debug_sessions_created
ON ai_chat_debug_sessions(created_at);

CREATE TABLE IF NOT EXISTS ai_chat_debug_turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_debug_id TEXT NOT NULL,
  turn_id TEXT NOT NULL,
  request_id TEXT,
  session_id_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  language TEXT,
  message_length INTEGER,
  user_message_redacted TEXT,
  assistant_reply_redacted TEXT,
  reply_type TEXT,
  route TEXT,
  action TEXT,
  source TEXT,
  tool_name TEXT,
  tool_status TEXT,
  render_intent TEXT,
  worker_used INTEGER NOT NULL DEFAULT 0,
  fallback_used INTEGER NOT NULL DEFAULT 0,
  worker_latency_ms INTEGER,
  turn_duration_ms INTEGER,
  product_count INTEGER NOT NULL DEFAULT 0,
  final_product_ids_json TEXT NOT NULL DEFAULT '[]',
  no_match_reason TEXT,
  failure_reason TEXT,
  feedback_id TEXT,
  feedback_rating TEXT,
  feedback_reason TEXT,
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(chat_debug_id, turn_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_debug_turns_session
ON ai_chat_debug_turns(chat_debug_id, created_at);

CREATE INDEX IF NOT EXISTS idx_ai_chat_debug_turns_feedback
ON ai_chat_debug_turns(feedback_rating, feedback_reason);

CREATE TABLE IF NOT EXISTS ai_chat_feedback_debug (
  feedback_id TEXT PRIMARY KEY,
  chat_debug_id TEXT,
  session_id_hash TEXT NOT NULL,
  turn_id TEXT NOT NULL,
  request_id TEXT,
  created_at TEXT NOT NULL,
  rating TEXT NOT NULL,
  reason TEXT NOT NULL,
  route TEXT,
  source TEXT,
  tool_name TEXT,
  latency_ms INTEGER,
  product_ids_json TEXT NOT NULL DEFAULT '[]',
  snapshot_json TEXT NOT NULL DEFAULT '{}',
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_feedback_debug_session
ON ai_chat_feedback_debug(chat_debug_id);

CREATE INDEX IF NOT EXISTS idx_ai_chat_feedback_debug_reason
ON ai_chat_feedback_debug(reason);
